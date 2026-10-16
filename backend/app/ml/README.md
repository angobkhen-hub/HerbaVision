# ML training — herbal vs non-herbal classifier

Trains the self-trained CNN referenced in the architecture diagram
(`.pt` model, loaded by FastAPI at startup for `/classify`).

## 1. Install dependencies

From `backend/`:

```
pip install -r requirements-ml.txt
```

CPU-only is fine to start. If training feels slow, an NVIDIA GPU + CUDA
build of PyTorch will speed it up a lot — see the comment in
`requirements-ml.txt`.

Check what you've got:

```
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
```

## 2. Add your dataset

Drop images into these two folders (already created, currently empty):

```
ml/dataset/herbal/       <- herbal leaf photos
ml/dataset/non_herbal/   <- everything else: non-herbal leaves, random objects, etc.
```

Folder names must match exactly — that's how labels get assigned.

**Don't have images yet?** A few starting points:
- Take your own photos — even 100-200 per class is enough for a first pass.
- Public datasets like PlantVillage or PlantNet (search + check license terms
  before using for anything beyond learning/prototyping).
- Mix in "hard negatives" for non_herbal — non-leaf objects, other plant types —
  so the model learns more than just "green blob = herbal."

Aim for roughly balanced classes (similar image count on each side) to start.

## 3. Train

From `backend/app/` (so the `ml` package resolves correctly):

```
python -m ml.train
```

This will:
- Split your images 85/15 into train/validation
- Train for `NUM_EPOCHS` (see `ml/config.py`)
- Print train/val loss and val accuracy each epoch
- Save the best-so-far model to `ml/checkpoints/herb_classifier.pt`

## 4. Wire it into FastAPI

In your FastAPI startup (e.g. `main.py`):

```python
from .ml.predict import HerbPredictor

predictor = HerbPredictor()  # loads the .pt file once

@app.post("/classify")
async def classify(file: UploadFile = File(...)):
    image_bytes = await file.read()
    label, confidence = predictor.predict(image_bytes)
    return {"label": label, "confidence": confidence}
```

## Tuning knobs

Everything adjustable lives in `ml/config.py` — image size, batch size,
learning rate, epoch count, validation split. Change values there rather
than editing `train.py` directly.

## Next steps once this works

- More data usually beats a fancier model — if val accuracy plateaus low,
  collect more images before changing the architecture.
- If accuracy is still weak with a decent dataset, swap `HerbCNN` in
  `model.py` for a pretrained backbone (e.g. `torchvision.models.mobilenet_v3_small`)
  fine-tuned on your data — usually a big accuracy jump with less data.
- Multi-class species ID (from your diagram) can reuse this same pipeline —
  just add more subfolders under `ml/dataset/` (one per species) and update
  `CLASS_NAMES` in `config.py`.
