import uuid
from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, String, Integer, DateTime, ForeignKey
from app.core.db import Base


class VendorRule(Base):
    """User-defined mapping from a merchant/store pattern to a Category.
    Synced client-first; applied before built-in keyword matching and AI
    category suggestions in the Flutter app.
    """

    __tablename__ = "vendor_rules"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(
        String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    pattern = Column(String(512), nullable=False)
    use_regex = Column(Boolean, default=False, nullable=False)
    category_id = Column(String, nullable=False)
    is_income = Column(Boolean, default=False, nullable=False)
    priority = Column(Integer, default=100, nullable=False)
    version = Column(Integer, default=1)
    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    deleted_at = Column(DateTime(timezone=True), nullable=True)
