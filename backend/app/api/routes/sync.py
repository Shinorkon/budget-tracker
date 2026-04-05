"""
Bulk sync endpoint: the Flutter app sends all local changes since last sync,
and receives all server-side changes since that timestamp.
"""

from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.core.db import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.category import Category
from app.models.transaction import Transaction, TransactionType
from app.models.receipt import Receipt

router = APIRouter(prefix="/api/sync", tags=["sync"])


# ─── Schemas ──────────────────────────────────────────────────

class CategorySync(BaseModel):
    id: str
    name: str
    icon_code: int
    color_value: int
    budget_limit: float = 0
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class TransactionSync(BaseModel):
    id: str
    category_id: Optional[str] = None
    amount: float
    date: datetime
    note: str = ""
    type: str  # "expense" | "income"
    store_name: str = ""
    image_path: str = ""
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class ReceiptSync(BaseModel):
    id: str
    store_name: str
    date: datetime
    total: float
    category_id: str = ""
    transaction_id: str = ""
    image_path: str = ""
    items_json: str = "[]"
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class SyncRequest(BaseModel):
    last_synced_at: Optional[datetime] = None
    categories: list[CategorySync] = []
    transactions: list[TransactionSync] = []
    receipts: list[ReceiptSync] = []


class SyncResponse(BaseModel):
    server_time: datetime
    categories: list[CategorySync]
    transactions: list[TransactionSync]
    receipts: list[ReceiptSync]


# ─── Endpoint ─────────────────────────────────────────────────

@router.post("", response_model=SyncResponse)
def sync(
    req: SyncRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    since = req.last_synced_at or datetime.min.replace(tzinfo=timezone.utc)

    # ── Push: upsert client changes ──────────────────────────
    for c in req.categories:
        existing = db.query(Category).filter(
            Category.id == c.id, Category.user_id == user.id
        ).first()
        if existing:
            if c.updated_at > (existing.updated_at or datetime.min.replace(tzinfo=timezone.utc)):
                existing.name = c.name
                existing.icon_code = c.icon_code
                existing.color_value = c.color_value
                existing.budget_limit = c.budget_limit
                existing.updated_at = c.updated_at
                existing.deleted_at = c.deleted_at
        else:
            db.add(Category(
                id=c.id,
                user_id=user.id,
                name=c.name,
                icon_code=c.icon_code,
                color_value=c.color_value,
                budget_limit=c.budget_limit,
                created_at=c.updated_at,
                updated_at=c.updated_at,
                deleted_at=c.deleted_at,
            ))

    for t in req.transactions:
        existing = db.query(Transaction).filter(
            Transaction.id == t.id, Transaction.user_id == user.id
        ).first()
        if existing:
            if t.updated_at > (existing.updated_at or datetime.min.replace(tzinfo=timezone.utc)):
                existing.category_id = t.category_id
                existing.amount = t.amount
                existing.date = t.date
                existing.note = t.note
                existing.type = TransactionType(t.type)
                existing.store_name = t.store_name
                existing.image_path = t.image_path
                existing.updated_at = t.updated_at
                existing.deleted_at = t.deleted_at
        else:
            db.add(Transaction(
                id=t.id,
                user_id=user.id,
                category_id=t.category_id,
                amount=t.amount,
                date=t.date,
                note=t.note,
                type=TransactionType(t.type),
                store_name=t.store_name,
                image_path=t.image_path,
                created_at=t.updated_at,
                updated_at=t.updated_at,
                deleted_at=t.deleted_at,
            ))

    for r in req.receipts:
        existing = db.query(Receipt).filter(
            Receipt.id == r.id, Receipt.user_id == user.id
        ).first()
        if existing:
            if r.updated_at > (existing.updated_at or datetime.min.replace(tzinfo=timezone.utc)):
                existing.store_name = r.store_name
                existing.date = r.date
                existing.total = r.total
                existing.category_id = r.category_id
                existing.transaction_id = r.transaction_id
                existing.image_path = r.image_path
                existing.items_json = r.items_json
                existing.updated_at = r.updated_at
                existing.deleted_at = r.deleted_at
        else:
            db.add(Receipt(
                id=r.id,
                user_id=user.id,
                store_name=r.store_name,
                date=r.date,
                total=r.total,
                category_id=r.category_id,
                transaction_id=r.transaction_id,
                image_path=r.image_path,
                items_json=r.items_json,
                created_at=r.updated_at,
                updated_at=r.updated_at,
                deleted_at=r.deleted_at,
            ))

    db.commit()

    # ── Pull: return server changes since last_synced_at ─────
    server_cats = db.query(Category).filter(
        Category.user_id == user.id,
        Category.updated_at > since,
    ).all()

    server_txns = db.query(Transaction).filter(
        Transaction.user_id == user.id,
        Transaction.updated_at > since,
    ).all()

    server_rcpts = db.query(Receipt).filter(
        Receipt.user_id == user.id,
        Receipt.updated_at > since,
    ).all()

    return SyncResponse(
        server_time=now,
        categories=[
            CategorySync(
                id=c.id, name=c.name, icon_code=c.icon_code,
                color_value=c.color_value, budget_limit=c.budget_limit,
                updated_at=c.updated_at, deleted_at=c.deleted_at,
            ) for c in server_cats
        ],
        transactions=[
            TransactionSync(
                id=t.id, category_id=t.category_id, amount=t.amount,
                date=t.date, note=t.note, type=t.type.value,
                store_name=t.store_name, image_path=t.image_path,
                updated_at=t.updated_at, deleted_at=t.deleted_at,
            ) for t in server_txns
        ],
        receipts=[
            ReceiptSync(
                id=r.id, store_name=r.store_name, date=r.date,
                total=r.total, category_id=r.category_id,
                transaction_id=r.transaction_id, image_path=r.image_path,
                items_json=r.items_json, updated_at=r.updated_at,
                deleted_at=r.deleted_at,
            ) for r in server_rcpts
        ],
    )
