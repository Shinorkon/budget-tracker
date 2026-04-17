"""Individual CRUD endpoints for transactions (v1 API)."""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.db import get_db
from app.core.limiter import limiter
from app.core.security import get_current_user
from app.models.user import User
from app.models.transaction import Transaction, TransactionType

router = APIRouter(prefix="/api/v1/transactions", tags=["transactions"])


class TransactionIn(BaseModel):
    id: str
    category_id: Optional[str] = None
    account_id: Optional[str] = None
    transfer_group_id: Optional[str] = None
    amount: float
    date: datetime
    note: str = ""
    type: str  # "expense" | "income"
    store_name: str = ""
    image_path: str = ""
    currency: str = "MVR"
    exchange_rate: Optional[float] = None


class TransactionOut(BaseModel):
    id: str
    category_id: Optional[str] = None
    account_id: Optional[str] = None
    transfer_group_id: Optional[str] = None
    amount: float
    date: datetime
    note: str
    type: str
    store_name: str
    image_path: str
    currency: str
    exchange_rate: Optional[float] = None
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class PaginatedTransactions(BaseModel):
    items: list[TransactionOut]
    page: int
    per_page: int
    total: int
    has_more: bool


def _to_out(t: Transaction) -> TransactionOut:
    return TransactionOut(
        id=t.id, category_id=t.category_id,
        account_id=t.account_id, transfer_group_id=t.transfer_group_id,
        amount=t.amount, date=t.date, note=t.note, type=t.type.value,
        store_name=t.store_name, image_path=t.image_path,
        currency=t.currency, exchange_rate=t.exchange_rate,
        updated_at=t.updated_at, deleted_at=t.deleted_at,
    )


@router.get("", response_model=PaginatedTransactions)
@limiter.limit("60/minute")
def list_transactions(
    request: Request,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    category_id: Optional[str] = None,
    type: Optional[str] = None,
    from_date: Optional[datetime] = None,
    to_date: Optional[datetime] = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = db.query(Transaction).filter(
        Transaction.user_id == user.id, Transaction.deleted_at.is_(None)
    )
    if category_id:
        q = q.filter(Transaction.category_id == category_id)
    if type:
        q = q.filter(Transaction.type == TransactionType(type))
    if from_date:
        q = q.filter(Transaction.date >= from_date)
    if to_date:
        q = q.filter(Transaction.date <= to_date)

    total = q.count()
    items = q.order_by(Transaction.date.desc()).offset((page - 1) * per_page).limit(per_page).all()
    return PaginatedTransactions(
        items=[_to_out(t) for t in items],
        page=page, per_page=per_page, total=total,
        has_more=(page * per_page) < total,
    )


@router.get("/{transaction_id}", response_model=TransactionOut)
def get_transaction(
    transaction_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    tx = db.query(Transaction).filter(
        Transaction.id == transaction_id, Transaction.user_id == user.id
    ).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return _to_out(tx)


@router.post("", response_model=TransactionOut, status_code=201)
@limiter.limit("60/minute")
def create_transaction(
    request: Request,
    req: TransactionIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    tx = Transaction(
        id=req.id, user_id=user.id, category_id=req.category_id,
        account_id=req.account_id or f"legacy-default-{user.id}",
        transfer_group_id=req.transfer_group_id,
        amount=req.amount, date=req.date, note=req.note,
        type=TransactionType(req.type), store_name=req.store_name,
        image_path=req.image_path, currency=req.currency,
        exchange_rate=req.exchange_rate,
        created_at=now, updated_at=now,
    )
    db.add(tx)
    db.commit()
    db.refresh(tx)
    return _to_out(tx)


@router.put("/{transaction_id}", response_model=TransactionOut)
@limiter.limit("60/minute")
def update_transaction(
    request: Request,
    transaction_id: str,
    req: TransactionIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    tx = db.query(Transaction).filter(
        Transaction.id == transaction_id, Transaction.user_id == user.id
    ).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    tx.category_id = req.category_id
    if req.account_id:
        tx.account_id = req.account_id
    tx.transfer_group_id = req.transfer_group_id
    tx.amount = req.amount
    tx.date = req.date
    tx.note = req.note
    tx.type = TransactionType(req.type)
    tx.store_name = req.store_name
    tx.image_path = req.image_path
    tx.currency = req.currency
    tx.exchange_rate = req.exchange_rate
    tx.updated_at = datetime.now(timezone.utc)
    db.commit()
    return _to_out(tx)


@router.delete("/{transaction_id}", status_code=204)
def delete_transaction(
    transaction_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    tx = db.query(Transaction).filter(
        Transaction.id == transaction_id, Transaction.user_id == user.id
    ).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    tx.deleted_at = datetime.now(timezone.utc)
    db.commit()
