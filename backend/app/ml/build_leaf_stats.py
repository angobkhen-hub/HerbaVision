r"""
Build the "what do the six plants look like" statistics used to reject unknown leaves.
Run this ONCE (and again whenever you retrain leaf_model.pt).

    python build_leaf_stats.py
    python build_leaf_stats.py --data C:\Users\user\Downloads\dataset --unknown C:\leaf_tests\unknown

It reads the training photos (data\train\<class>\*.jpg), measures each plant's typical
features with the existing model, and saves leaf_stats.pt next to this file.
The threshold is set from the validation photos (data\val), so real plants should pass.
It does NOT change leaf_model.pt and needs no new photos and no internet.
"""

import argparse
import os
import sys

import torch
import torch.nn as nn
from PIL import Image
from torchvision import models, transforms

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(HERE, "leaf_model.pt")
STATS_PATH = os.path.join(HERE, "leaf_stats.pt")
DEFAULT_DATA = r"C:\Users\user\Downloads\dataset"
IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".webp", ".bmp")
SHRINKAGE = 0.1          # keeps the covariance stable with a limited number of photos
VAL_PERCENTILE = 0.99    # threshold = this percentile of the validation distances

_preprocess = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
])


def load_model():
    ckpt = torch.load(MODEL_PATH, map_location="cpu")
    classes = ckpt["classes"]
    model = models.mobilenet_v3_large(weights=None)
    model.classifier[3] = nn.Linear(model.classifier[3].in_features, len(classes))
    model.load_state_dict(ckpt["state_dict"])
    model.eval()
    return model, classes


def list_images(folder):
    if not os.path.isdir(folder):
        return []
    return sorted(os.path.join(folder, f) for f in os.listdir(folder)
                  if f.lower().endswith(IMAGE_EXTS))


@torch.no_grad()
def features_of(model, paths, batch=32):
    """Return an (N, D) tensor of pooled features, skipping unreadable images."""
    out = []
    for i in range(0, len(paths), batch):
        xs = []
        for p in paths[i:i + batch]:
            try:
                with Image.open(p) as im:
                    xs.append(_preprocess(im.convert("RGB")))
            except Exception as e:
                print(f"  skipped {os.path.basename(p)}: {e}")
        if xs:
            f = torch.flatten(model.avgpool(model.features(torch.stack(xs))), 1)
            out.append(f.double())
    return torch.cat(out) if out else torch.empty(0, 0, dtype=torch.double)


def distances(feats, means, precision):
    """Smallest Mahalanobis distance (divided by D) from each feature to any class mean."""
    d = feats.shape[1]
    scores = []
    for f in feats:
        diff = f.unsqueeze(0) - means                     # (C, D)
        d2 = ((diff @ precision) * diff).sum(dim=1)       # (C,)
        scores.append(float(d2.min()) / d)
    return torch.tensor(scores)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=DEFAULT_DATA, help="folder that contains train/ and val/")
    ap.add_argument("--unknown", default=None, help="optional folder of leaves NOT in the dataset")
    args = ap.parse_args()

    model, classes = load_model()
    print(f"Model has {len(classes)} classes: {', '.join(classes)}")

    train_dir = os.path.join(args.data, "train")
    val_dir = os.path.join(args.data, "val")

    class_feats = []
    for c in classes:
        paths = list_images(os.path.join(train_dir, c))
        if not paths:
            print(f"ERROR: no training photos found in {os.path.join(train_dir, c)}")
            sys.exit(1)
        print(f"Reading {len(paths):4d} training photos of {c} ...")
        class_feats.append(features_of(model, paths))

    means = torch.stack([f.mean(dim=0) for f in class_feats])            # (C, D)
    centered = torch.cat([f - m for f, m in zip(class_feats, means)])    # (N, D)
    n, d = centered.shape
    cov = centered.T @ centered / max(n - 1, 1)
    cov = (1 - SHRINKAGE) * cov + SHRINKAGE * (torch.trace(cov) / d) * torch.eye(d, dtype=torch.double)
    precision = torch.linalg.inv(cov)

    val_scores = []
    for c in classes:
        paths = list_images(os.path.join(val_dir, c))
        if paths:
            val_scores.append(distances(features_of(model, paths), means, precision))
    if not val_scores:
        print(f"ERROR: no validation photos found under {val_dir}")
        sys.exit(1)
    val_scores = torch.cat(val_scores)
    threshold = float(torch.quantile(val_scores, VAL_PERCENTILE))

    print(f"\nValidation photos: {len(val_scores)}")
    print(f"  distance  median {float(val_scores.median()):.3f}   "
          f"95% {float(torch.quantile(val_scores, 0.95)):.3f}   max {float(val_scores.max()):.3f}")
    print(f"  threshold (99% of validation photos pass): {threshold:.3f}")

    if args.unknown:
        paths = list_images(args.unknown)
        if paths:
            u = distances(features_of(model, paths), means, precision)
            rejected = int((u > threshold).sum())
            print(f"\nUnknown leaves in {args.unknown}: {len(u)} photos")
            print(f"  distance  median {float(u.median()):.3f}   min {float(u.min()):.3f}")
            print(f"  rejected at this threshold: {rejected} of {len(u)}")

    torch.save({
        "means": means.float(),
        "precision": precision.float(),
        "threshold": threshold,
        "classes": classes,
    }, STATS_PATH)
    print(f"\nSaved {STATS_PATH}")


if __name__ == "__main__":
    main()