"""Download photos of "other" plants for the 'Other_plants' class.

Low-data version:
- iNaturalist photos are requested at the 1024 px "large" size first
  (a few hundred KB) and fall back to the original only if that fails.
- Photos already saved are skipped, so you can Ctrl+C and rerun any time.
"""
import os
import re
import sys
import time

import requests

# ---- settings you can change -------------------------------------------
MAX_PER_SPECIES = 4          # change to 4 to halve the download
OUT_DIR = os.path.join("gbif_images", "Other_plants")

# Put the scientific names of your six target plants here so they are
# never downloaded into the "Other" class. Matching is on the genus+species
# text, case-insensitive. Example: {"Mentha spicata", "Ocimum basilicum"}
EXCLUDE = set()
# ------------------------------------------------------------------------

SPECIES = [
    "Ficus benjamina", "Ficus elastica", "Monstera deliciosa", "Epipremnum aureum",
    "Spathiphyllum wallisii", "Chlorophytum comosum", "Sansevieria trifasciata",
    "Zamioculcas zamiifolia", "Dracaena fragrans", "Dracaena marginata",
    "Philodendron hederaceum", "Aglaonema commutatum", "Dieffenbachia seguine",
    "Calathea ornata", "Maranta leuconeura", "Pilea peperomioides",
    "Peperomia obtusifolia", "Hedera helix", "Nephrolepis exaltata",
    "Aloe vera", "Crassula ovata", "Echeveria elegans", "Haworthia fasciata",
    "Opuntia ficus-indica", "Rosa chinensis", "Hibiscus rosa-sinensis",
    "Bougainvillea spectabilis", "Plumeria rubra", "Ixora coccinea",
    "Codiaeum variegatum", "Cordyline fruticosa", "Coleus scutellarioides",
    "Impatiens walleriana", "Begonia rex", "Pelargonium zonale",
    "Tagetes erecta", "Zinnia elegans", "Helianthus annuus", "Lavandula angustifolia",
    "Rosmarinus officinalis", "Salvia officinalis", "Thymus vulgaris",
    "Origanum vulgare", "Petroselinum crispum", "Coriandrum sativum",
    "Capsicum annuum", "Solanum lycopersicum", "Cucumis sativus",
    "Carica papaya", "Mangifera indica", "Musa acuminata", "Cocos nucifera",
    "Citrus limon", "Psidium guajava", "Moringa oleifera", "Ipomoea batatas",
    "Manihot esculenta", "Colocasia esculenta", "Alocasia macrorrhizos",
    "Taraxacum officinale", "Plantago major", "Trifolium repens",
    "Ricinus communis", "Ocimum tenuiflorum", "Lantana camara",
    "Mimosa pudica", "Acalypha wilkesiana", "Ageratum conyzoides",
    "Cymbopogon citratus", "Bambusa vulgaris", "Areca catechu",
    "Ravenala madagascariensis", "Strelitzia reginae", "Heliconia rostrata",
    "Canna indica", "Hosta plantaginea", "Quercus robur", "Acer palmatum",
    "Ginkgo biloba", "Ulmus americana",
]

HEADERS = {"User-Agent": "leaf-project-download/1.0 (student project)"}
GBIF = "https://api.gbif.org/v1"


def safe(name):
    return re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_")


def smaller_url(url):
    """iNaturalist: original.jpg -> large.jpg (1024 px). Others unchanged."""
    if "inaturalist" in url and re.search(r"/original\.(jpe?g|png)$", url, re.I):
        return re.sub(r"/original\.", "/large.", url, flags=re.I)
    return url


def get_json(url, params):
    for _ in range(3):
        try:
            r = requests.get(url, params=params, headers=HEADERS, timeout=30)
            if r.status_code == 200:
                return r.json()
        except requests.RequestException:
            pass
        time.sleep(1.5)
    return None


def download(url, path):
    try:
        r = requests.get(url, headers=HEADERS, timeout=40)
        if r.status_code == 200 and len(r.content) > 5000:
            with open(path, "wb") as f:
                f.write(r.content)
            return True
    except requests.RequestException:
        pass
    return False


def fetch_photo(url, path):
    small = smaller_url(url)
    if download(small, path):
        return True
    if small != url:  # fall back to the original
        return download(url, path)
    return False


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    exclude = {e.lower() for e in EXCLUDE}
    species = [s for s in SPECIES if s.lower() not in exclude]
    total = len(species)
    saved_total = 0

    for i, name in enumerate(species, 1):
        prefix = safe(name)
        have = [f for f in os.listdir(OUT_DIR) if f.startswith(prefix + "_")]
        if len(have) >= MAX_PER_SPECIES:
            print(f"[{i}/{total}] {name} ... already have {len(have)}")
            continue

        match = get_json(f"{GBIF}/species/match", {"name": name})
        key = match.get("usageKey") if match else None
        if not key:
            print(f"[{i}/{total}] {name} ... no GBIF match")
            continue

        data = get_json(f"{GBIF}/occurrence/search", {
            "taxonKey": key, "mediaType": "StillImage", "limit": 40,
        })
        count = len(have)
        n = 0
        for occ in (data or {}).get("results", []):
            if count >= MAX_PER_SPECIES:
                break
            for m in occ.get("media", []):
                url = m.get("identifier")
                if not url or m.get("type") != "StillImage":
                    continue
                path = os.path.join(OUT_DIR, f"{prefix}_{count + 1:02d}.jpg")
                if os.path.exists(path):
                    count += 1
                    continue
                if fetch_photo(url, path):
                    count += 1
                    n += 1
                    saved_total += 1
                break  # one photo per occurrence
        print(f"[{i}/{total}] {name} ... {n} photos")

    print(f"Done. {saved_total} new photos in {OUT_DIR}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nStopped. Rerun to continue; saved photos are skipped.")
        sys.exit(0)
