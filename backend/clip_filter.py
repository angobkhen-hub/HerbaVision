import sys, shutil, csv
from pathlib import Path
import torch
from PIL import Image
from transformers import CLIPModel, CLIPProcessor

src = Path(sys.argv[1])                      # e.g. Other_plants_new
review = src.parent / (src.name + "_review")
# The threshold argument is no longer used. It stays so old commands still work.
dry_run = "--dry" in sys.argv

labels = [
    "a close-up photo of a plant leaf",
    "a photo of a flower",
    "a photo of fruit or seeds",
    "a photo of a whole tree or bark",
    "a wide photo of a garden or landscape",
    "a photo of a person, animal or object",
]
LEAF = 0
# Lenient rule: reject only when flower, fruit or person/animal/object wins.
REJECT = {labels[1], labels[2], labels[5]}

device = "cuda" if torch.cuda.is_available() else "cpu"
model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32").to(device).eval()
proc = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")


def as_tensor(out):
    # Newer transformers versions return a wrapper object instead of a tensor
    if torch.is_tensor(out):
        return out
    if getattr(out, "pooler_output", None) is not None:
        return out.pooler_output
    return out[0]


with torch.no_grad():
    t = proc(text=labels, return_tensors="pt", padding=True).to(device)
    text_feats = as_tensor(model.get_text_features(**t))
    text_feats = text_feats / text_feats.norm(dim=-1, keepdim=True)

rows, moved = [], 0
files = list(src.rglob("*.jpg"))
for i, f in enumerate(files, 1):
    try:
        img = Image.open(f).convert("RGB")
        with torch.no_grad():
            x = proc(images=img, return_tensors="pt").to(device)
            feat = as_tensor(model.get_image_features(**x))
            feat = feat / feat.norm(dim=-1, keepdim=True)
            probs = (100 * feat @ text_feats.T).softmax(dim=-1)[0]
        leaf_p = probs[LEAF].item()
        top = labels[probs.argmax().item()]
        keep = top not in REJECT
    except Exception as e:
        leaf_p, top, keep = 0.0, f"error: {e}", False
    if not keep:
        moved += 1
        if not dry_run:
            dest = review / f.parent.name
            dest.mkdir(parents=True, exist_ok=True)
            shutil.move(str(f), str(dest / f.name))
    rows.append([f.parent.name, f.name, round(leaf_p, 3), top, "kept" if keep else "moved"])
    if i % 100 == 0:
        print(f"{i}/{len(files)}")

with open(src.parent / "clip_filter_log.csv", "w", newline="", encoding="utf-8") as fh:
    csv.writer(fh).writerows([["species", "file", "leaf_prob", "top_label", "action"]] + rows)
print(f"Done. {moved} of {len(files)} {'would be ' if dry_run else ''}moved to {review}")