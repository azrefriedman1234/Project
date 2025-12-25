import re
import httpx
from .config import LIBRETRANSLATE_URL

_HEBREW_RE = re.compile(r"[\u0590-\u05FF]")

def contains_hebrew(s: str) -> bool:
    return bool(_HEBREW_RE.search(s or ""))

async def translate_to_hebrew(text: str) -> str:
    if not text or contains_hebrew(text):
        return text

    if not LIBRETRANSLATE_URL:
        # בלי שירות תרגום מוגדר – נשאיר כפי שהוא
        return text

    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.post(LIBRETRANSLATE_URL, data={
            "q": text,
            "source": "auto",
            "target": "he",
            "format": "text"
        })
        r.raise_for_status()
        j = r.json()
        return j.get("translatedText", text)
