import os
import json
import uuid
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, UploadFile, File
from pydantic import BaseModel
from .telegram_manager import TelegramManager
from .translate import translate_to_hebrew
from .media_blur import blur_image, blur_video_ffmpeg
from .config import MEDIA_DIR, DEFAULT_TARGET_CHANNEL

app = FastAPI()
tg = TelegramManager()

class LoginStart(BaseModel):
    phone: str

class LoginVerify(BaseModel):
    phone: str
    code: str

class PasswordVerify(BaseModel):
    password: str

class Settings(BaseModel):
    target_channel: str

class BlurRequest(BaseModel):
    input_path: str
    rects: list[dict]  # [{x,y,w,h}] בפיקסלים לפי המדיה המקורית
    kind: str          # "image" / "video"

_current_target_channel = DEFAULT_TARGET_CHANNEL

@app.on_event("startup")
async def _startup():
    await tg.start()

@app.get("/auth/status")
async def auth_status():
    return {"authorized": await tg.is_authorized()}

@app.post("/auth/start")
async def auth_start(body: LoginStart):
    if not body.phone:
        raise HTTPException(400, "phone required")
    await tg.send_code(body.phone)
    return {"ok": True}

@app.post("/auth/verify")
async def auth_verify(body: LoginVerify):
    try:
        await tg.sign_in(body.phone, body.code)
        return {"ok": True, "authorized": await tg.is_authorized()}
    except Exception as e:
        # אם יש 2FA תראה הודעת שגיאה -> תשתמש ב /auth/password
        return {"ok": False, "error": str(e)}

@app.post("/auth/password")
async def auth_password(body: PasswordVerify):
    await tg.sign_in_password(body.password)
    return {"ok": True, "authorized": await tg.is_authorized()}

@app.get("/dialogs")
async def dialogs():
    if not await tg.is_authorized():
        raise HTTPException(401, "not authorized")
    return await tg.list_dialogs()

@app.get("/messages/{chat_id}")
async def messages(chat_id: int, limit: int = 50):
    if not await tg.is_authorized():
        raise HTTPException(401, "not authorized")
    msgs = await tg.get_messages(chat_id, limit=limit)
    # תרגום אוטומטי לכל הודעה שאינה עברית (MVP)
    for m in msgs:
        m["text_he"] = await translate_to_hebrew(m.get("text", ""))
    return msgs

@app.get("/media/download/{chat_id}/{msg_id}")
async def media_download(chat_id: int, msg_id: int):
    if not await tg.is_authorized():
        raise HTTPException(401, "not authorized")
    path = await tg.download_media(chat_id, msg_id)
    return {"path": path}

@app.post("/settings")
async def set_settings(s: Settings):
    global _current_target_channel
    _current_target_channel = s.target_channel.strip()
    return {"ok": True, "target_channel": _current_target_channel}

@app.get("/settings")
async def get_settings():
    return {"target_channel": _current_target_channel}

@app.post("/media/blur")
async def media_blur(req: BlurRequest):
    inp = req.input_path
    if not os.path.exists(inp):
        raise HTTPException(404, "input not found")

    out = os.path.join(MEDIA_DIR, f"blurred_{uuid.uuid4().hex}")
    if req.kind == "image":
        out += ".jpg"
        blur_image(inp, out, req.rects)
    elif req.kind == "video":
        out += ".mp4"
        blur_video_ffmpeg(inp, out, req.rects)
    else:
        raise HTTPException(400, "kind must be image/video")

    return {"output_path": out}

@app.websocket("/ws/live")
async def ws_live(websocket: WebSocket):
    await websocket.accept()
    if not await tg.is_authorized():
        await websocket.send_text(json.dumps({"type": "error", "message": "not authorized"}))
        await websocket.close()
        return

    async def sender(payload: dict):
        # תרגום בזמן אמת (MVP)
        if payload.get("text"):
            payload["text_he"] = await translate_to_hebrew(payload["text"])
        await websocket.send_text(json.dumps({"type": "message", "data": payload}))

    tg.add_listener(sender)
    try:
        while True:
            # אפשר לקבל פקודות מהאפליקציה בהמשך (סינון וכו')
            await websocket.receive_text()
    except WebSocketDisconnect:
        tg.remove_listener(sender)
