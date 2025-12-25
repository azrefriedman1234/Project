import os
import asyncio
from telethon import TelegramClient, events
from telethon.tl.types import MessageMediaPhoto, MessageMediaDocument

from .config import API_ID, API_HASH, SESSION_PATH, MEDIA_DIR

class TelegramManager:
    def __init__(self):
        os.makedirs(MEDIA_DIR, exist_ok=True)
        self.client = TelegramClient(SESSION_PATH, API_ID, API_HASH)
        self._listeners = set()  # websocket send callables
        self._started = False

    async def start(self):
        if self._started:
            return
        await self.client.connect()
        self._started = True

        @self.client.on(events.NewMessage)
        async def handler(event):
            msg = event.message
            data = {
                "id": msg.id,
                "chat_id": getattr(msg.peer_id, 'channel_id', None) or getattr(msg.peer_id, 'chat_id', None) or getattr(msg.peer_id, 'user_id', None),
                "date": msg.date.isoformat(),
                "text": msg.message or "",
                "from_id": getattr(msg.from_id, 'user_id', None) if msg.from_id else None,
                "has_media": bool(msg.media),
                "media_type": self._media_type(msg),
            }
            # הודעה לכל לקוחות WS מחוברים
            for send in list(self._listeners):
                try:
                    await send(data)
                except Exception:
                    self._listeners.discard(send)

    def _media_type(self, msg):
        if not msg.media:
            return None
        if isinstance(msg.media, MessageMediaPhoto):
            return "photo"
        if isinstance(msg.media, MessageMediaDocument):
            return "document"
        return "media"

    async def is_authorized(self) -> bool:
        return await self.client.is_user_authorized()

    async def send_code(self, phone: str):
        return await self.client.send_code_request(phone)

    async def sign_in(self, phone: str, code: str):
        return await self.client.sign_in(phone=phone, code=code)

    async def sign_in_password(self, password: str):
        return await self.client.sign_in(password=password)

    def add_listener(self, send_callable):
        self._listeners.add(send_callable)

    def remove_listener(self, send_callable):
        self._listeners.discard(send_callable)

    async def list_dialogs(self, limit=200):
        dialogs = []
        async for d in self.client.iter_dialogs(limit=limit):
            dialogs.append({
                "id": d.id,
                "title": d.title,
                "is_channel": getattr(d.entity, "broadcast", False),
            })
        return dialogs

    async def get_messages(self, chat_id: int, limit=50):
        msgs = []
        async for m in self.client.iter_messages(chat_id, limit=limit):
            msgs.append({
                "id": m.id,
                "date": m.date.isoformat(),
                "text": m.message or "",
                "has_media": bool(m.media),
                "media_type": self._media_type(m),
            })
        msgs.reverse()
        return msgs

    async def download_media(self, chat_id: int, msg_id: int) -> str:
        msg = await self.client.get_messages(chat_id, ids=msg_id)
        if not msg or not msg.media:
            raise ValueError("No media")
        path = await self.client.download_media(msg, file=MEDIA_DIR)
        return path
