"""
POST /recognize : upload a leaf photo, get the predicted herb back.

Put this file in backend/app/routers/ and register it in app/main.py.
"""

import io
import time

from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import UnidentifiedImageError

from ..ml import leaf_predict as lp
from ..ml.leaf_predict import NOT_IN_DATASET_MESSAGE, is_confident, predict

router = APIRouter(tags=["recognition"])

# Load the model when the server starts, so the first scan isn't slow.
try:
    lp._load()
except FileNotFoundError:
    pass  # the error will show up on the first scan instead

MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB

NON_HERBAL_MESSAGE = "This leaf is non-herbal."

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

    t0 = time.perf_counter()
    try:
        guesses = predict(io.BytesIO(data), top_k=3)
    except FileNotFoundError:
        raise  # a missing leaf_model.pt is a server problem, not a bad upload
    except (UnidentifiedImageError, OSError):
        raise HTTPException(
            status_code=400,
            detail="Could not read this image. Please upload a JPG or PNG photo.",
        )
    predict_seconds = time.perf_counter() - t0

    name, prob = guesses[0]
    confident = is_confident(guesses)
    # The model's "Other plants" class means: not one of the supported herbs.
    is_non_herbal = (name == lp.OTHER_NAME)

    # --- debug log: shows why a photo was accepted or rejected ---
    thr = lp._stats["threshold"] * lp.DISTANCE_SCALE if lp._stats is not None else None
    print(
        f"[recognize] upload={len(data) / 1024:.0f} KB "
        f"predict={predict_seconds:.2f}s "
        f"TTA={lp.USE_TTA} "
        f"guesses={[(n, round(p * 100, 1)) for n, p in guesses]} "
        f"margin={lp.margin(guesses) * 100:.1f}% "
        f"dist={guesses.distance} limit={thr} "
        f"too_far={lp.too_far(guesses)} confident={confident} non_herbal={is_non_herbal}",
        flush=True,
    )
    try:
        with open("last_upload.jpg", "wb") as f:  # the exact bytes the app sent
            f.write(data)
    except OSError:
        pass
    # --------------------------------------------------------------

    if is_non_herbal:
        # Non-herbal: only say so. No confidence level, no alternative guesses.
        return {
            "name": "Non-herbal",
            "latin_name": "",
            "confidence": None,
            "confident": False,        # reuses the app's existing "not recognised" path
            "non_herbal": True,
            "message": NON_HERBAL_MESSAGE,
            "alternatives": [],
        }

    return {
        "name": name,
        "latin_name": LATIN_NAMES.get(name, ""),
        "confidence": round(prob * 100, 1),
        "confident": confident,
        "non_herbal": False,
        # Shown by the app when confident is false (leaf not in the dataset).
        "message": None if confident else NOT_IN_DATASET_MESSAGE,
        "alternatives": [
            {"name": n, "confidence": round(p * 100, 1)} for n, p in guesses[1:]
        ],
    }