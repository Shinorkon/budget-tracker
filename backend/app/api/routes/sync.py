"""
Bulk sync endpoint: the Flutter app sends all local changes since last sync,
and receives all server-side changes since that timestamp.
"""

from datetime import datetime, timezone
from typing import Optional
import logging
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from pydantic import BaseModel
from app.core.db import get_db
from app.core.limiter import limiter
from app.core.security import get_current_user
from app.models.user import User
from app.models.category import Category
from app.models.transaction import Transaction, TransactionType
from app.models.receipt import Receipt

logger = logging.getLogger(__name__)

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
    currency: str = "MVR"
    exchange_rate: Optional[float] = None
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
    page: int = 1
    per_page: int = 500


class SyncResponse(BaseModel):
    server_time: datetime
    categories: list[CategorySync]
    transactions: list[TransactionSync]
    receipts: list[ReceiptSync]
    has_more: bool = False


# ─── Endpoint ─────────────────────────────────────────────────

@router.post("", response_model=SyncResponse)
@limiter.limit("30/minute")
def sync(
    request: Request,
    req: SyncRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    try:
        now = datetime.now(timezone.utc)
        since = req.last_synced_at or datetime.min.replace(tzinfo=timezone.utc)

        # ── Push: upsert client changes ──────────────────────────
        for c in req.categories:
            try:
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
            except (IntegrityError, SQLAlchemyError) as e:
                db.rollback()
                logger.error(f"Category sync error for user {user.id}: {str(e)}")
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid category data: {str(e)}"
                )

        # Flush so that FK validation for transactions can find newly-added categories
        try:
            db.flush()
        except (IntegrityError, SQLAlchemyError) as e:
            db.rollback()
            logger.error(f"Category flush error for user {user.id}: {str(e)}")
            raise HTTPException(status_code=400, detail=f"Invalid category data: {str(e)}")

        for t in req.transactions:
            try:
                # Validate enum
                try:
                    tx_type = TransactionType(t.type)
                except (ValueError, KeyError):
                    raise HTTPException(
                        status_code=400,
                        detail=f"Invalid transaction type '{t.type}'. Must be 'expense' or 'income'."
                    )

                # Validate category exists if specified
                if t.category_id:
                    category_exists = db.query(Category).filter(
                        Category.id == t.category_id, Category.user_id == user.id
                    ).first()
                    if not category_exists:
                        raise HTTPException(
                            status_code=400,
                            detail=f"Category {t.category_id} not found for this user"
                        )

                # Validate amount
                if t.amount < 0:
                    raise HTTPException(
                        status_code=400,
                        detail="Transaction amount cannot be negative"
                    )

                existing = db.query(Transaction).filter(
                    Transaction.id == t.id, Transaction.user_id == user.id
                ).first()
                if existing:
                    if t.updated_at > (existing.updated_at or datetime.min.replace(tzinfo=timezone.utc)):
                        existing.category_id = t.category_id
                        existing.amount = t.amount
                        existing.date = t.date
                        existing.note = t.note
                        existing.type = tx_type
                        existing.store_name = t.store_name
                        existing.image_path = t.image_path
                        existing.currency = t.currency
                        existing.exchange_rate = t.exchange_rate
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
                        type=tx_type,
                        store_name=t.store_name,
                        image_path=t.image_path,
                        currency=t.currency,
                        exchange_rate=t.exchange_rate,
                        created_at=t.updated_at,
                        updated_at=t.updated_at,
                        deleted_at=t.deleted_at,
                    ))
            except HTTPException:
                raise
            except (IntegrityError, SQLAlchemyError) as e:
                db.rollback()
                logger.error(f"Transaction sync error for user {user.id}: {str(e)}")
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid transaction data: {str(e)}"
                )

        # Flush so that FK validation for receipts can find newly-added transactions
        try:
            db.flush()
        except (IntegrityError, SQLAlchemyError) as e:
            db.rollback()
            logger.error(f"Transaction flush error for user {user.id}: {str(e)}")
            raise HTTPException(status_code=400, detail=f"Invalid transaction data: {str(e)}")

        for r in req.receipts:
            try:
                # Validate foreign keys if specified
                if r.category_id:
                    category_exists = db.query(Category).filter(
                        Category.id == r.category_id, Category.user_id == user.id
                    ).first()
                    if not category_exists:
                        raise HTTPException(
                            status_code=400,
                            detail=f"Category {r.category_id} not found for this user"
                        )

                if r.transaction_id:
                    transaction_exists = db.query(Transaction).filter(
                        Transaction.id == r.transaction_id, Transaction.user_id == user.id
                    ).first()
                    if not transaction_exists:
                        raise HTTPException(
                            status_code=400,
                            detail=f"Transaction {r.transaction_id} not found for this user"
                        )

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
            except HTTPException:
                raise
            except (IntegrityError, SQLAlchemyError) as e:
                db.rollback()
                logger.error(f"Receipt sync error for user {user.id}: {str(e)}")
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid receipt data: {str(e)}"
                )

        try:
            db.commit()
        except (IntegrityError, SQLAlchemyError) as e:
            db.rollback()
            logger.error(f"Database commit error for user {user.id}: {str(e)}")
            raise HTTPException(
                status_code=400,
                detail=f"Failed to save changes: {str(e)}"
            )

        # ── Pull: return server changes since last_synced_at (paginated) ─
        offset = (req.page - 1) * req.per_page

        server_cats = db.query(Category).filter(
            Category.user_id == user.id,
            Category.updated_at > since,
        ).order_by(Category.updated_at).all()

        server_txns = db.query(Transaction).filter(
            Transaction.user_id == user.id,
            Transaction.updated_at > since,
        ).order_by(Transaction.updated_at).offset(offset).limit(req.per_page + 1).all()

        server_rcpts = db.query(Receipt).filter(
            Receipt.user_id == user.id,
            Receipt.updated_at > since,
        ).order_by(Receipt.updated_at).all()

        # Check if there are more transactions beyond this page
        has_more = len(server_txns) > req.per_page
        if has_more:
            server_txns = server_txns[:req.per_page]

        return SyncResponse(
            server_time=now,
            has_more=has_more,
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
                    currency=t.currency, exchange_rate=t.exchange_rate,
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
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in sync for user {user.id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred during sync"
        )
