"""
Herb information endpoints, backed by the leaf_items table.

Put this file in backend/app/routers/ (replace the old one).

  GET /herbs/                  -> every herb (for the Herb library)
  GET /herbs/lookup?name=...   -> one herb, matched by scientific or common name
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..leaf_item_model import LeafItem

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


@router.get("/")
def list_herbs(db: Session = Depends(get_db)):
    items = db.query(LeafItem).order_by(LeafItem.id).all()
    return [_to_dict(i) for i in items]


@router.get("/lookup")
def lookup_herb(name: str, db: Session = Depends(get_db)):
    # The stored name looks like "Sambong (Alib-on, Gabon) - Blumea balsamifera",
    # so a match on the scientific name (or any common name) finds the row.
    item = db.query(LeafItem).filter(LeafItem.name.ilike(f"%{name}%")).first()
    if item is None:
        raise HTTPException(status_code=404, detail="Herb not found")
    return _to_dict(item)