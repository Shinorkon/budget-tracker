import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, Integer, DateTime, ForeignKey, Enum as SQLEnum
import enum
from app.core.db import Base


class TransactionType(str, enum.Enum):
    expense = "expense"
    income = "income"


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(String, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True)
    amount = Column(Float, nullable=False)
    date = Column(DateTime(timezone=True), nullable=False)
    note = Column(String(1000), default="")
    type = Column(SQLEnum(TransactionType), nullable=False)
    store_name = Column(String(255), default="")
    image_path = Column(String, default="")
    currency = Column(String(10), default="MVR")  # Original currency (for SMS imports)
    exchange_rate = Column(Float, nullable=True)  # Conversion rate used (for audit trail)
    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
    deleted_at = Column(DateTime(timezone=True), nullable=True)
    version = Column(Integer, default=1)
