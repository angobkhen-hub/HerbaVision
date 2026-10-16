"""
SQLAlchemy model for the leaf_items table (herb information).

Put this file in backend/app/. Importing it (the herbs router does) registers
the table, so Base.metadata.create_all() in main.py creates it if it's missing.
"""

from sqlalchemy import Column, Integer, String, Text

from .database import Base


class LeafItem(Base):
    __tablename__ = "leaf_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    benefits = Column(Text)
    traditional_uses = Column(Text)
    risks = Column(Text)
    precautions = Column(Text)