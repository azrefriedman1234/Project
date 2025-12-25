import os
import subprocess
from PIL import Image, ImageFilter

def blur_image(input_path: str, output_path: str, rects: list[dict]):
    im = Image.open(input_path).convert("RGB")
    for r in rects:
        x = int(r["x"]); y = int(r["y"]); w = int(r["w"]); h = int(r["h"])
        crop = im.crop((x, y, x+w, y+h))
        crop = crop.filter(ImageFilter.GaussianBlur(radius=18))
        im.paste(crop, (x, y))
    im.save(output_path, "JPEG", quality=92)

def blur_video_ffmpeg(input_path: str, output_path: str, rects: list[dict]):
    # משתמשים ב-crop+boxblur+overlay לכל מלבן (MVP)
    # הערה: על סרטונים גדולים זה ייקח זמן, אבל עובד.
    filters = []
    overlays = []
    last = "[0:v]"
    idx = 1

    for r in rects:
        x = int(r["x"]); y = int(r["y"]); w = int(r["w"]); h = int(r["h"])
        # חותכים אזור -> boxblur -> overlay חזרה
        filters.append(f"{last}crop={w}:{h}:{x}:{y},boxblur=10:1[blur{idx}]")
        overlays.append((idx, x, y))
        idx += 1

    # עכשיו מחזירים את כל ה-blur על הוידאו המקורי
    composed = "[0:v]"
    for i, x, y in overlays:
        filters.append(f"{composed}[blur{i}]overlay={x}:{y}[v{i}]")
        composed = f"[v{i}]"

    vf = ";".join(filters) if filters else "null"
    out_map = composed if overlays else "0:v"

    cmd = [
        "ffmpeg", "-y", "-i", input_path,
        "-filter_complex", vf,
        "-map", out_map,
        "-map", "0:a?",  # אודיו אם קיים
        "-c:v", "libx264", "-crf", "24", "-preset", "veryfast",
        "-c:a", "aac", "-b:a", "128k",
        output_path
    ]
    subprocess.check_call(cmd)
