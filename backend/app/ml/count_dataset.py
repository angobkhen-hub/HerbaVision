r"""
Counts the images in every folder under a path.

Usage:
    python count_dataset.py "C:\path\to\gbif_images"
    python count_dataset.py "C:\path\to\dataset"        (the train/val split)
    python count_dataset.py --model                     (classes saved in leaf_model.pt)
"""

import os
import sys

EXT = (".jpg", ".jpeg", ".png", ".webp", ".bmp")


def count_folders(root):
    total = 0
    print(f"{'folder':<60}{'images':>8}")
    print("-" * 68)
    for dirpath, _dirs, files in sorted(os.walk(root)):
        n = sum(f.lower().endswith(EXT) for f in files)
        if n:
            print(f"{os.path.relpath(dirpath, root):<60}{n:>8}")
            total += n
    print("-" * 68)
    print(f"{'TOTAL':<60}{total:>8}")


def show_model():
    import torch
    here = os.path.dirname(os.path.abspath(__file__))
    ckpt = torch.load(os.path.join(here, "leaf_model.pt"), map_location="cpu")
    print("Classes in leaf_model.pt:")
    for c in ckpt["classes"]:
        print("  ", c)
    for k, v in ckpt.items():
        if k not in ("state_dict", "classes") and isinstance(v, (int, float, str, list, dict)):
            print(f"{k}: {v}")


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--model":
        show_model()
    elif len(sys.argv) == 2:
        count_folders(sys.argv[1])
    else:
        print(__doc__)