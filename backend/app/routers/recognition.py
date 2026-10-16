"""
POST /recognize : upload a leaf photo, get the predicted herb back.

Put this file in backend/app/routers/ and register it in app/main.py.
"""

import io

from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import UnidentifiedImageError

from ..ml.leaf_predict import NOT_IN_DATASET_MESSAGE, is_confident, predict

router = APIRouter(tags=["recognition"])

MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB

# The model returns common names; the app also shows the Latin name.
LATIN_NAMES = {
    "Sambong": "Blumea balsamifera",
    "Guyabano": "Annona muricata",
    "Sawansawan": "Hyptis capitata",
    "Song of India": "Dracaena reflexa",
    "Dumb cane": "Dieffenbachia seguine",
    "Caladium": "Caladium bicolor",
}


# A plain `def` (not `async def`) so FastAPI runs the CPU-heavy prediction in a
# worker thread instead of blocking the whole server.
@router.post("/recognize")
def recognize(image: UploadFile = File(...)):
    data = image.file.read(MAX_UPLOAD_BYTES + 1)
    if not data:
        raise HTTPException(status_code=400, detail="The uploaded file is empty.")
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Image is too large (max 10 MB).")

    try:
        guesses = predict(io.BytesIO(data), top_k=3)
    except FileNotFoundError:
        raise  # a missing leaf_model.pt is a server problem, not a bad upload
    except (UnidentifiedImageError, OSError):
        raise HTTPException(
            status_code=400,
            detail="Could not read this image. Please upload a JPG or PNG photo.",
        )

    name, prob = guesses[0]
    confident = is_confident(guesses)
    return {
        "name": name,
        "latin_name": LATIN_NAMES.get(name, ""),
        "confidence": round(prob * 100, 1),
        "confident": confident,
        # Shown by the app when confident is false (leaf not in the dataset).
        "message": None if confident else NOT_IN_DATASET_MESSAGE,
        "alternatives": [
            {"name": n, "confidence": round(p * 100, 1)} for n, p in guesses[1:]
        ],
    }