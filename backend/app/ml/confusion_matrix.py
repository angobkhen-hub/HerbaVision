r"""
Confusion matrix for the trained leaf model.

Usage (from backend\app\ml):
    python confusion_matrix.py
    python confusion_matrix.py "C:\path\to\dataset\test"

The test folder must hold one subfolder per class (same names as training).
Saves confusion_matrix.png next to this file.
"""

import os
import sys

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import leaf_predict as lp

EXT = (".jpg", ".jpeg", ".png", ".webp", ".bmp")
test_dir = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\user\Downloads\dataset\test"

lp._load()
classes = list(lp._classes)
names = [lp.COMMON_NAMES.get(c, c) for c in classes]
index = {n: i for i, n in enumerate(names)}
n = len(classes)
cm = np.zeros((n, n), dtype=int)   # rows = true class, columns = predicted class

for ti, cls in enumerate(classes):
    folder = os.path.join(test_dir, cls)
    if not os.path.isdir(folder):
        print(f"Missing folder, skipped: {folder}")
        continue
    for f in sorted(os.listdir(folder)):
        if not f.lower().endswith(EXT):
            continue
        try:
            top = lp.predict(os.path.join(folder, f), top_k=1)[0][0]
        except Exception as e:
            print(f"Skipped {f}: {e}")
            continue
        cm[ti, index[top]] += 1

total = cm.sum()
if total == 0:
    sys.exit("No test images found. Check the test folder path.")

print(f"\nTest images: {total}   (multi-view TTA: {lp.USE_TTA})\n")
print("Confusion matrix (rows = true, columns = predicted)")
header = " " * 16 + "".join(f"{nm[:10]:>11}" for nm in names)
print(header)
for i, nm in enumerate(names):
    print(f"{nm[:15]:<16}" + "".join(f"{v:>11}" for v in cm[i]))

print(f"\n{'class':<16}{'precision':>10}{'recall':>9}{'F1':>8}{'support':>9}")
f1s = []
for i, nm in enumerate(names):
    tp = cm[i, i]
    prec = tp / cm[:, i].sum() if cm[:, i].sum() else 0.0
    rec = tp / cm[i].sum() if cm[i].sum() else 0.0
    f1 = 2 * prec * rec / (prec + rec) if (prec + rec) else 0.0
    f1s.append(f1)
    print(f"{nm[:15]:<16}{prec:10.3f}{rec:9.3f}{f1:8.3f}{cm[i].sum():9d}")
print(f"\nOverall accuracy: {np.trace(cm) / total * 100:.2f}%   Macro F1: {np.mean(f1s):.3f}")

# ---- picture ----
row_sums = cm.sum(axis=1, keepdims=True)
norm = np.divide(cm, row_sums, out=np.zeros_like(cm, dtype=float), where=row_sums > 0)
fig, ax = plt.subplots(figsize=(8, 7))
im = ax.imshow(norm, cmap="Greens", vmin=0, vmax=1)
ax.set_xticks(range(n)); ax.set_yticks(range(n))
ax.set_xticklabels(names, rotation=40, ha="right")
ax.set_yticklabels(names)
ax.set_xlabel("Predicted class"); ax.set_ylabel("True class")
ax.set_title("Confusion matrix (test set)")
for i in range(n):
    for j in range(n):
        ax.text(j, i, f"{cm[i, j]}", ha="center", va="center",
                color="white" if norm[i, j] > 0.6 else "black", fontsize=10)
fig.colorbar(im, ax=ax, label="Share of true class")
fig.tight_layout()
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "confusion_matrix.png")
fig.savefig(out, dpi=200)
print(f"\nSaved picture: {out}")
