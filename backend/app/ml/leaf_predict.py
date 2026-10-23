r"""
Classify one photo with the trained model (leaf_model.pt).

Command line:
    python leaf_predict.py path\to\photo.jpg
    python leaf_predict.py --folder path\to\folder   (test many photos, to tune the limits)

From your own code (for example a web backend):
    from leaf_predict import predict, is_confident
    results = predict("photo.jpg")      # [("Sambong", 0.93), ("Sawansawan", 0.04), ...]
    if not is_confident(results):
        ...  # show NOT_IN_DATASET_MESSAGE

Needs: torch, torchvision, pillow, and leaf_model.pt in the same folder as this file.
For the "unknown leaf" distance check, also run build_leaf_stats.py once to create
leaf_stats.pt (without that file the distance check is simply skipped).
"""

import os
import sys

import torch
import torch.nn as nn
from PIL import Image, ImageOps
from torchvision import models, transforms

_HERE = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(_HERE, "leaf_model.pt")
STATS_PATH = os.path.join(_HERE, "leaf_stats.pt")

# A result counts as "in the dataset" only if ALL checks pass.
# Tune with:  python leaf_predict.py --folder <photos of leaves NOT in the dataset>
MIN_CONFIDENCE = 0.65   # top guess must be at least this sure (was 0.80 - too strict for real-world photos)
MIN_MARGIN = 0.20       # top guess must beat the 2nd guess by at least this much (was 0.30)
DISTANCE_SCALE = 1.0    # multiplies the distance limit saved in leaf_stats.pt (lower = stricter)

NOT_IN_DATASET_MESSAGE = (
    "This leaf is not in the dataset, or the photo is unclear. "
    "Try again with a clear photo of a single leaf."
)

# Friendly names shown to users. Keys must match the folder names used in training.
COMMON_NAMES = {
    "Blumea_balsamifera": "Sambong",
    "Annona_muricata": "Guyabano",
    "Hyptis_capitata": "Sawansawan",
    "Dracaena_reflexa": "Song of India",
    "Dieffenbachia_seguine": "Dumb cane",
    "Caladium_bicolor": "Caladium",
    "Other_plants": "Other plants",   # only exists in a model trained with the 7th class
}
OTHER_NAME = "Other plants"           # if this is the top guess, the leaf is "not in the dataset"

# Multi-view prediction (test-time augmentation). Real-world photos often have the leaf
# off-centre, which a single centre crop can cut off. With USE_TTA the model looks at the
# centre plus the four corners, each also mirrored (10 views), and the probabilities are
# averaged. Set USE_TTA = False to go back to the single centre crop.
USE_TTA = os.environ.get("LEAF_TTA", "1") != "0"   # set the environment variable LEAF_TTA=0 to compare
CROP = 224

_resize = transforms.Resize(256)
_finish = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
])


def _views(im):
    """Return the PIL views to classify. The centre crop (what the model was tested on) is first."""
    im = _resize(im)
    w, h = im.size
    cx, cy = int(round((w - CROP) / 2.0)), int(round((h - CROP) / 2.0))
    corners = [(cx, cy), (0, 0), (w - CROP, 0), (0, h - CROP), (w - CROP, h - CROP)]
    crops = [im.crop((x, y, x + CROP, y + CROP)) for x, y in corners]
    if not USE_TTA:
        return crops[:1]
    return crops + [ImageOps.mirror(c) for c in crops]

_model = None
_classes = None
_stats = None


class Guesses(list):
    """A list of (name, probability) plus the distance to the nearest known plant."""
    distance = None


def _load():
    global _model, _classes, _stats
    if _model is not None:
        return
    ckpt = torch.load(MODEL_PATH, map_location="cpu")
    _classes = ckpt["classes"]
    model = models.mobilenet_v3_large(weights=None)
    model.classifier[3] = nn.Linear(model.classifier[3].in_features, len(_classes))
    model.load_state_dict(ckpt["state_dict"])
    model.eval()
    if os.path.exists(STATS_PATH):
        stats = torch.load(STATS_PATH, map_location="cpu")
        if list(stats["classes"]) == list(_classes):
            _stats = stats
        else:
            print("leaf_stats.pt does not match leaf_model.pt - run build_leaf_stats.py again.")
    else:
        print("leaf_stats.pt not found - skipping the unknown-leaf distance check.")
    _model = model


def _distance(feat):
    """Smallest Mahalanobis distance (divided by D) from one feature vector to any class mean."""
    if _stats is None:
        return None
    diff = feat.unsqueeze(0) - _stats["means"]
    d2 = ((diff @ _stats["precision"]) * diff).sum(dim=1)
    return float(d2.min()) / feat.shape[0]


def predict(image_path, top_k=3):
    """Return the top_k guesses as a list of (name, probability), best first."""
    _load()
    with Image.open(image_path) as im:
        # Phone cameras often save the pixels sideways and add an EXIF "rotate" note.
        # Browsers and galleries obey it; Pillow does not, so apply it here so the
        # model sees the leaf the way you see it.
        im = ImageOps.exif_transpose(im).convert("RGB")
        x = torch.stack([_finish(v) for v in _views(im)])
    with torch.no_grad():
        feats = torch.flatten(_model.avgpool(_model.features(x)), 1)
        probs = _model.classifier(feats).softmax(dim=1).mean(dim=0)
        dist = _distance(feats[0])      # feats[0] is the centre crop
    values, indices = probs.topk(min(top_k, len(_classes)))
    results = Guesses((COMMON_NAMES.get(_classes[i], _classes[i]), float(v))
                      for v, i in zip(values, indices))
    results.distance = dist
    return results


def margin(results):
    """Gap between the best and second-best guess (needs top_k >= 2)."""
    second = results[1][1] if len(results) > 1 else 0.0
    return results[0][1] - second


def too_far(results):
    """True if the leaf looks unlike all six known plants (needs leaf_stats.pt)."""
    d = getattr(results, "distance", None)
    return d is not None and _stats is not None and d > _stats["threshold"] * DISTANCE_SCALE


def is_confident(results):
    """True if the leaf looks like one of the dataset plants, False if it should be 'not found'."""
    if results[0][0] == OTHER_NAME:      # the model says "some other plant"
        return False
    if results[0][1] < MIN_CONFIDENCE or margin(results) < MIN_MARGIN:
        return False
    return not too_far(results)


_IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp", ".bmp")


def _run_folder(folder):
    files = sorted(f for f in os.listdir(folder) if f.lower().endswith(_IMAGE_EXTS))
    if not files:
        print("No images found in that folder.")
        return
    print(f"{'file':<32}{'best guess':<16}{'conf':>7}{'margin':>8}{'dist':>8}  verdict")
    accepted = 0
    for f in files:
        try:
            results = predict(os.path.join(folder, f))
        except Exception as e:  # unreadable image
            print(f"{f:<32}error: {e}")
            continue
        ok = is_confident(results)
        accepted += ok
        d = results.distance
        dist = f"{d:8.2f}" if d is not None else f"{'-':>8}"
        print(f"{f[:31]:<32}{results[0][0]:<16}{results[0][1] * 100:6.1f}%{margin(results) * 100:7.1f}%{dist}  "
              f"{'ACCEPTED' if ok else 'not found'}")
    limit = (f"{_stats['threshold'] * DISTANCE_SCALE:.2f}" if _stats is not None else "off")
    print(f"\n{accepted} of {len(files)} accepted "
          f"(MIN_CONFIDENCE={MIN_CONFIDENCE}, MIN_MARGIN={MIN_MARGIN}, distance limit={limit})")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--folder":
        _run_folder(sys.argv[2])
        sys.exit(0)
    if len(sys.argv) != 2:
        print("Usage: python leaf_predict.py path\\to\\photo.jpg")
        print("   or: python leaf_predict.py --folder path\\to\\folder")
        sys.exit(1)
    results = predict(sys.argv[1])
    for name, p in results:
        print(f"  {name:<16}{p * 100:5.1f}%")
    print(f"  margin over 2nd guess: {margin(results) * 100:.1f}%   "
          f"(needs conf >= {MIN_CONFIDENCE * 100:.0f}% and margin >= {MIN_MARGIN * 100:.0f}%)")
    if results.distance is not None:
        print(f"  distance to nearest known plant: {results.distance:.2f}")
    if not is_confident(results):
        print("\n" + NOT_IN_DATASET_MESSAGE)