"""
Herb information endpoints, backed by the leaf_items table.

  GET    /herbs/                      -> every herb (for the Herb library)
  GET    /herbs/lookup?name=...       -> one herb, by scientific or common name
  GET    /herbs/saved                 -> the signed-in user's saved herbs
  POST   /herbs/saved                 -> save a herb  {"latin_name": "..."}
  DELETE /herbs/saved?latin_name=...  -> un-save a herb
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user
from ..leaf_item_model import LeafItem
from ..saved_herb_model import SavedHerb

router = APIRouter(prefix="/herbs", tags=["herbs"])

# Scientific names of the herbal plants. Everything else is non-herbal.
HERBAL_SPECIES = [
    "blumea balsamifera",   # Sambong
    "annona muricata",      # Guyabano
    "hyptis capitata",      # Sawansawan
]


def _category(name: str) -> str:
    lowered = (name or "").lower()
    return "Herbal" if any(s in lowered for s in HERBAL_SPECIES) else "Non-herbal"


def _latin_name(item: LeafItem) -> str:
    # Stored name looks like "Sambong (Alib-on, Gabon) - Blumea balsamifera"
    name = item.name or ""
    return name.split(" - ")[-1].strip() if " - " in name else name.strip()


def _to_dict(item: LeafItem) -> dict:
    return {
        "id": item.id,
        "name": item.name,
        "category": _category(item.name),
        "description": item.description,
        "benefits": item.benefits,
        "traditional_uses": item.traditional_uses,
        "risks": item.risks,
        "precautions": item.precautions,
    }


def _find_item(db: Session, latin_name: str):
    """Match a herb by scientific name, tolerating author suffixes like 'Jacq.'."""
    text = (latin_name or "").strip()
    if not text:
        return None
    item = db.query(LeafItem).filter(LeafItem.name.ilike(f"%{text}%")).first()
    if item is None:
        words = text.split()
        if len(words) > 2:  # retry with just "Genus species"
            item = (
                db.query(LeafItem)
                .filter(LeafItem.name.ilike(f"%{' '.join(words[:2])}%"))
                .first()
            )
    return item


class SaveHerbBody(BaseModel):
    latin_name: str


@router.get("/")
def list_herbs(db: Session = Depends(get_db)):
    items = db.query(LeafItem).order_by(LeafItem.id).all()
    return [_to_dict(i) for i in items]


@router.get("/lookup")
def lookup_herb(name: str, db: Session = Depends(get_db)):
    item = db.query(LeafItem).filter(LeafItem.name.ilike(f"%{name}%")).first()
    if item is None:
        raise HTTPException(status_code=404, detail="Herb not found")
    return _to_dict(item)


# ---- Saved herbs (per signed-in user) ----
# These are declared after "/lookup" and use the fixed path "/saved",
# so they never clash with the other routes.

@router.get("/saved")
def list_saved(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    rows = (
        db.query(LeafItem)
        .join(SavedHerb, SavedHerb.leaf_item_id == LeafItem.id)
        .filter(SavedHerb.user_id == current_user.id)
        .order_by(SavedHerb.created_at.desc())
        .all()
    )
    return [
        {"id": r.id, "name": r.name, "latin_name": _latin_name(r)}
        for r in rows
    ]


@router.post("/saved", status_code=201)
def save_herb(
    body: SaveHerbBody,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    item = _find_item(db, body.latin_name)
    if item is None:
        raise HTTPException(status_code=404, detail="Herb not found")

    exists = (
        db.query(SavedHerb)
        .filter(
            SavedHerb.user_id == current_user.id,
            SavedHerb.leaf_item_id == item.id,
        )
        .first()
    )
    if exists is None:  # saving twice is harmless
        db.add(SavedHerb(user_id=current_user.id, leaf_item_id=item.id))
        db.commit()
    return {"saved": True, "latin_name": _latin_name(item)}


@router.delete("/saved")
def unsave_herb(
    latin_name: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    item = _find_item(db, latin_name)
    if item is None:
        raise HTTPException(status_code=404, detail="Herb not found")

    db.query(SavedHerb).filter(
        SavedHerb.user_id == current_user.id,
        SavedHerb.leaf_item_id == item.id,
    ).delete()
    db.commit()
    return {"saved": False, "latin_name": _latin_name(item)}