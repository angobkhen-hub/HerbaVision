r"""
Rejection test: how often does each rule wrongly ACCEPT leaves that are not in the dataset?

Put this file in backend\app\ml (next to leaf_predict.py) and run it from there:

    python rejection_eval.py --known C:\Users\user\Downloads\dataset\test --unknown C:\path\to\unknown_photos

  --known    folder with one subfolder per class (same layout as confusion_matrix.py).
             Its Other_plants subfolder, if present, is used as an "unknown" set
             (same sources as the training data, so the numbers are optimistic).
  --unknown  (optional) folder of photos of plants that are NOT your species.
             Use fresh photos that were never in gbif_images or dataset. This is the
             honest test. Subfolders are searched too.
  --model / --stats  (optional) evaluate another checkpoint, for example the 6-class backup:
             --model leaf_model_backup_6class.pt --stats leaf_stats_6class.pt

Rules compared:
  A  threshold only: top probability >= 0.50 (like Sugiarto et al.)
  B  A + the app's confidence/margin limits (+ the "Other plants" class if the model has it)
  C  the full app pipeline (B + the feature-distance check from leaf_stats.pt)

Results are printed and saved to rejection_eval_results.txt.
Set LEAF_TTA=0 first if you want a faster run (single centre crop instead of 10 views).
"""

import argparse
import os
import sys

import leaf_predict as lp

EXT = (".jpg", ".jpeg", ".png", ".webp", ".bmp")


def resolve(path):
    return path if os.path.isabs(path) else os.path.join(lp._HERE, path)


def list_images(folder, recursive=False):
    found = []
    if recursive:
        for root, _dirs, files in os.walk(folder):
            found += [os.path.join(root, f) for f in sorted(files) if f.lower().endswith(EXT)]
    else:
        found = [os.path.join(folder, f) for f in sorted(os.listdir(folder)) if f.lower().endswith(EXT)]
    return found


def run(items, label):
    out = []
    print(f"Predicting {len(items)} photos: {label}", flush=True)
    for i, (path, expected) in enumerate(items, 1):
        try:
            results = lp.predict(path, top_k=3)
        except Exception as e:  # unreadable image
            print(f"  skipped {os.path.basename(path)}: {e}")
            continue
        out.append((path, expected, results))
        if i % 25 == 0:
            print(f"  {i}/{len(items)}", flush=True)
    return out


def pct(n, d):
    return f"{100.0 * n / d:5.1f}%" if d else "  n/a "


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--known", required=True)
    ap.add_argument("--unknown")
    ap.add_argument("--model")
    ap.add_argument("--stats")
    args = ap.parse_args()

    if args.model:
        lp.MODEL_PATH = resolve(args.model)
    if args.stats:
        lp.STATS_PATH = resolve(args.stats)
    lp._load()
    classes = list(lp._classes)

    known_items, other_items = [], []
    for cls in sorted(os.listdir(args.known)):
        d = os.path.join(args.known, cls)
        if not os.path.isdir(d):
            continue
        if cls == "Other_plants":
            other_items += [(p, None) for p in list_images(d)]
        elif cls in classes:
            known_items += [(p, lp.COMMON_NAMES.get(cls, cls)) for p in list_images(d)]
        else:
            print(f"Skipping folder that is not a class of this model: {cls}")

    fresh_items = []
    if args.unknown:
        fresh_items = [(p, None) for p in list_images(args.unknown, recursive=True)]

    if not known_items:
        sys.exit("No photos of the model's species found in the --known folder.")

    known = run(known_items, "known species (test set)")
    other = run(other_items, "Other_plants test photos (same sources as training)") if other_items else []
    fresh = run(fresh_items, "fresh unknown photos") if fresh_items else []

    max_p = 0.50
    strategies = [
        ("A  threshold only (prob >= 0.50)",
         lambda r: r[0][0] != lp.OTHER_NAME and r[0][1] >= max_p),
        (f"B  + conf >= {lp.MIN_CONFIDENCE:.2f}, margin >= {lp.MIN_MARGIN:.2f}, Other class",
         lambda r: r[0][0] != lp.OTHER_NAME and r[0][1] >= lp.MIN_CONFIDENCE and lp.margin(r) >= lp.MIN_MARGIN),
        ("C  full app pipeline (+ distance check)", lp.is_confident),
    ]

    lines = []
    lines.append(f"Model: {os.path.basename(lp.MODEL_PATH)}   classes: {len(classes)}   "
                 f"distance check: {'on' if lp._stats is not None else 'off'}   TTA: {lp.USE_TTA}")
    lines.append(f"Known-species photos: {len(known)}   Other_plants photos: {len(other)}   "
                 f"fresh unknown photos: {len(fresh)}")
    lines.append("")
    header = (f"{'rule':<62}{'known accepted':>15}{'correct if accepted':>21}"
              f"{'Other_plants wrongly accepted':>31}{'fresh unknown wrongly accepted':>33}")
    lines.append(header)
    lines.append("-" * len(header))
    for name, rule in strategies:
        accepted = [(e, r) for _p, e, r in known if rule(r)]
        correct = sum(1 for e, r in accepted if r[0][0] == e)
        o_acc = sum(1 for _p, _e, r in other if rule(r))
        f_acc = sum(1 for _p, _e, r in fresh if rule(r))
        lines.append(
            f"{name:<62}{pct(len(accepted), len(known)):>15}{pct(correct, len(accepted)):>21}"
            f"{(pct(o_acc, len(other)) + f' ({o_acc}/{len(other)})') if other else 'n/a':>31}"
            f"{(pct(f_acc, len(fresh)) + f' ({f_acc}/{len(fresh)})') if fresh else 'n/a':>33}"
        )
    lines.append("")
    lines.append("How to read it: 'known accepted' is how many real photos of your species the rule lets through")
    lines.append("(higher is better). 'wrongly accepted' is how many photos of other plants it lets through (lower is better).")

    if fresh:
        wrong = [(p, r) for p, _e, r in fresh if lp.is_confident(r)]
        if wrong:
            lines.append("")
            lines.append("Fresh unknown photos that the full pipeline wrongly accepted:")
            for p, r in wrong:
                lines.append(f"  {os.path.basename(p)[:44]:<46}{r[0][0]:<16}{r[0][1] * 100:5.1f}%")

    text = "\n".join(lines)
    print("\n" + text)
    out = os.path.join(lp._HERE, "rejection_eval_results.txt")
    with open(out, "w", encoding="utf-8") as f:
        f.write(text + "\n")
    print(f"\nSaved: {out}")


if __name__ == "__main__":
    main()