from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from ..database import get_db
from ..models import Scan, User
from ..schemas import ScanCreate, ScanOut, ScanStats
from ..deps import get_current_user

router = APIRouter(prefix="/scans", tags=["scans"])


@router.post("/", response_model=ScanOut, status_code=201)
def create_scan(
    payload: ScanCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    new_scan = Scan(
        user_id=current_user.id,
        plant_name=payload.plant_name,
        latin_name=payload.latin_name,
        confidence=payload.confidence,
        saved_to_library=1 if payload.saved_to_library else 0,
    )
    db.add(new_scan)
    db.commit()
    db.refresh(new_scan)
    return new_scan


@router.get("/", response_model=List[ScanOut])
def list_scans(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    scans = (
        db.query(Scan)
        .filter(Scan.user_id == current_user.id)
        .order_by(Scan.created_at.desc())
        .all()
    )
    return scans


@router.get("/stats", response_model=ScanStats)
def get_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_scans = db.query(Scan).filter(Scan.user_id == current_user.id)

    total_scans = user_scans.count()
    species_identified = (
        db.query(func.count(func.distinct(Scan.plant_name)))
        .filter(Scan.user_id == current_user.id)
        .scalar()
        or 0
    )
    avg_confidence = (
        db.query(func.avg(Scan.confidence))
        .filter(Scan.user_id == current_user.id)
        .scalar()
        or 0.0
    )
    saved_to_library = (
        user_scans.filter(Scan.saved_to_library == 1).count()
    )

    return ScanStats(
        total_scans=total_scans,
        species_identified=species_identified,
        avg_confidence=round(float(avg_confidence), 1),
        saved_to_library=saved_to_library,
    )
