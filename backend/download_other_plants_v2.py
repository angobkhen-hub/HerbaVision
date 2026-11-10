r"""
Download look-alike leaf photos into your Other_plants folder.

Photos come from GBIF (research-grade iNaturalist observations, live plants only,
so no herbarium sheets). One photo per observation, only CC0 / CC BY / CC BY-NC.

Usage (PowerShell, from the backend folder so the venv is used):
    ..\venv\Scripts\pip.exe install requests pillow
    ..\venv\Scripts\python.exe download_other_plants.py "C:\path\to\Other_plants"

Optional: how many photos per species (default 40):
    ..\venv\Scripts\python.exe download_other_plants.py "C:\path\to\Other_plants" 60

It is safe to run again: species that already have enough photos are skipped,
and photos already downloaded are not downloaded twice.

Afterwards:
  1. Run your CLIP filter over the new folders to drop flowers, fruit and trees.
  2. Look through them by eye (iNaturalist photos are field photos, not all close-ups).
  3. credits.csv lists the author and license of every photo (useful for your report).
"""

import csv
import io
import os
import sys
import time

import requests
from PIL import Image

API = "https://api.gbif.org/v1"
INAT_DATASET = "50c9509d-22c7-4a22-a47d-8c48425ef4a7"   # iNaturalist Research-grade Observations
MAX_SIDE = 1024                                          # shrink big photos to save space
OK_LICENSES = ("publicdomain/zero", "/by/", "/by-nc/")   # CC0, CC BY, CC BY-NC

# Edit this list freely. Names with a typo or no GBIF match are reported and skipped.
SPECIES = [
    # look-alikes of Dumb cane / Caladium
    "Colocasia esculenta", "Homalomena rubescens","Philodendron hederaceum",  "Philodendron scandens", "Alocasia macrorrhizos",
    "Alocasia odora", "Dieffenbachia maculata", "Scindapsus pictus",
    "Fittonia albivenis", "Hypoestes phyllostachya", "Alternanthera brasiliana",
    "Iresine diffusa", "Tradescantia spathacea",
    # look-alikes of Song of India / Dracaena
    "Cordyline fruticosa", "Pandanus amaryllifolius", "Yucca gloriosa", "Aspidistra elatior",
    # look-alikes of Guyabano
    "Annona montana", "Cananga odorata", "Psidium guajava", "Mangifera indica",
    "Artocarpus heterophyllus", "Persea americana", "Manilkara zapota",
    "Syzygium cumini", "Citrus aurantiifolia",
    # look-alikes of Sambong
    "Chromolaena odorata", "Ageratum conyzoides", "Elephantopus mollis",
    "Tithonia diversifolia", "Blumea lacera", "Sphagneticola trilobata",
    "Pluchea odorata", "Nicotiana tabacum",
    # look-alikes of Sawansawan
    "Ocimum basilicum", "Ocimum tenuiflorum", "Ocimum gratissimum", "Lantana camara",
    "Stachytarpheta jamaicensis", "Vitex negundo", "Orthosiphon aristatus",
    "Leonurus japonicus", "Mentha arvensis",
]

session = requests.Session()
session.headers["User-Agent"] = "HerbaVision-student-project (leaf dataset)"


def taxon_key(name):
    r = session.get(f"{API}/species/match", params={"name": name}, timeout=30)
    r.raise_for_status()
    data = r.json()
    if data.get("matchType") in (None, "NONE"):
        return None
    return data.get("usageKey")


def find_photos(key, want):
    """Return up to `want` (gbifID, url, license, author) tuples, one photo per observation."""
    found, offset = [], 0
    while len(found) < want and offset < 2000:
        r = session.get(f"{API}/occurrence/search", timeout=60, params={
            "taxonKey": key,
            "mediaType": "StillImage",
            "datasetKey": INAT_DATASET,
            "basisOfRecord": "HUMAN_OBSERVATION",
            "limit": 100,
            "offset": offset,
        })
        r.raise_for_status()
        data = r.json()
        for occ in data.get("results", []):
            for m in occ.get("media", []):
                url = m.get("identifier")
                lic = (m.get("license") or "").lower()
                if not url or not any(k in lic for k in OK_LICENSES):
                    continue
                author = m.get("rightsHolder") or m.get("creator") or ""
                found.append((occ["gbifID"], url, m.get("license", ""), author))
                break                      # only one photo per observation
        if data.get("endOfRecords"):
            break
        offset += 100
    return found


def save_photo(url, dest):
    url = url.replace("/original.", "/large.")     # iNaturalist "large" is 1024 px
    r = session.get(url, timeout=60)
    r.raise_for_status()
    im = Image.open(io.BytesIO(r.content)).convert("RGB")
    im.thumbnail((MAX_SIDE, MAX_SIDE))
    im.save(dest, "JPEG", quality=90)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    out_dir = sys.argv[1]
    per_species = int(sys.argv[2]) if len(sys.argv) > 2 else 40
    os.makedirs(out_dir, exist_ok=True)

    credits_path = os.path.join(out_dir, "credits.csv")
    new_file = not os.path.exists(credits_path)
    credits = open(credits_path, "a", newline="", encoding="utf-8")
    writer = csv.writer(credits)
    if new_file:
        writer.writerow(["file", "species", "gbif_id", "license", "author", "url"])

    for name in SPECIES:
        folder = os.path.join(out_dir, name.replace(" ", "_"))
        os.makedirs(folder, exist_ok=True)
        have = len([f for f in os.listdir(folder) if f.lower().endswith(".jpg")])
        if have >= per_species:
            print(f"{name}: already has {have}, skipped")
            continue
        try:
            key = taxon_key(name)
            if key is None:
                print(f"{name}: no match in GBIF, check the spelling")
                continue
            photos = find_photos(key, (per_species - have) * 2)   # extra in case some fail
        except Exception as e:
            print(f"{name}: lookup failed ({e})")
            continue

        saved = have
        for gbif_id, url, lic, author in photos:
            if saved >= per_species:
                break
            fname = f"{name.replace(' ', '_')}_{gbif_id}.jpg"
            dest = os.path.join(folder, fname)
            if os.path.exists(dest):
                continue
            try:
                save_photo(url, dest)
            except Exception:
                continue                   # broken link or unreadable image
            writer.writerow([fname, name, gbif_id, lic, author, url])
            saved += 1
            time.sleep(0.2)                # be polite to the server
        credits.flush()
        print(f"{name}: {saved} photos ({saved - have} new)")

    credits.close()
    print("\nDone. Next: run your CLIP filter and review the new folders.")


if __name__ == "__main__":
    main()
