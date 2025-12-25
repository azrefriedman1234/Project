import os

API_ID = int(os.environ.get("TG_API_ID", "0"))
API_HASH = os.environ.get("TG_API_HASH", "")
SESSION_PATH = os.environ.get("TG_SESSION_PATH", "./session.session")
MEDIA_DIR = os.environ.get("MEDIA_DIR", "./media")

# לתרגום: אפשר לשים כתובת LibreTranslate משלך (דוקר/שרת)
LIBRETRANSLATE_URL = os.environ.get("LIBRETRANSLATE_URL", "")  # e.g. http://localhost:5000/translate

# ערוץ יעד לשליחה (אפשר לשנות דרך endpoint settings)
DEFAULT_TARGET_CHANNEL = os.environ.get("DEFAULT_TARGET_CHANNEL", "")  # e.g. @mychannel
