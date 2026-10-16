from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from .database import Base, engine
from .routers import auth, scans, recognition, herbs
from . import leaf_item_model  # noqa: F401  (registers the leaf_items table)

Base.metadata.create_all(bind=engine)


def seed_leaf_items():
    """Load leaf_items_seed.sql once, when the leaf_items table is empty."""
    seed_file = Path(__file__).parent / "leaf_items_seed.sql"
    if not seed_file.exists():
        print("[seed] leaf_items_seed.sql not found next to main.py, skipping")
        return
    with engine.begin() as conn:
        count = conn.execute(text("SELECT COUNT(*) FROM leaf_items")).scalar()
        if count:
            return
        conn.exec_driver_sql(seed_file.read_text(encoding="utf-8"))
        conn.execute(text(
            "SELECT setval(pg_get_serial_sequence('leaf_items','id'), "
            "(SELECT MAX(id) FROM leaf_items))"
        ))
        print("[seed] leaf_items loaded")


seed_leaf_items()

app = FastAPI(title="HerbaVision API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(scans.router)
app.include_router(recognition.router)
app.include_router(herbs.router)


@app.get("/")
def root():
    return {"status": "HerbaVision API is running"}