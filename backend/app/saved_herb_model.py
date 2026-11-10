from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Integer, UniqueConstraint

from .database import Base


class SavedHerb(Base):
    """One row = one herb that one user has saved to their library."""

    __tablename__ = "saved_herbs"
    __table_args__ = (
        UniqueConstraint("user_id", "leaf_item_id", name="uq_saved_user_herb"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    leaf_item_id = Column(Integer, ForeignKey("leaf_items.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)  