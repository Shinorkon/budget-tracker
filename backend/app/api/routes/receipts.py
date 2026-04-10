"""Individual CRUD endpoints for receipts (v1 API)."""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.db import get_db
from app.core.limiter import limiter
from app.core.security import get_current_user
from app.models.user import User
from app.models.receipt import Receipt

router = APIRouter(prefix="/api/v1/receipts", tags=["receipts"])


class ReceiptIn(BaseModel):
    id: str
    store_name: str
    date: datetime
    total: float
    category_id: str = ""
    transaction_id: str = ""
    image_path: str = ""
    items_json: str = "[]"


class ReceiptOut(BaseModel):
    id: str
    store_name: str
    date: datetime
    total: float
    category_id: str
    transaction_id: str
    image_path: str
    items_json: str
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class PaginatedReceipts(BaseModel):
    items: list[ReceiptOut]
    page: int
    per_page: int
    total: int
    has_more: bool


def _to_out(r: Receipt) -> ReceiptOut:
    return ReceiptOut(
        id=r.id, store_name=r.store_name, date=r.date, total=r.total,
        category_id=r.category_id, transaction_id=r.transaction_id,
        image_path=r.image_path, items_json=r.items_json,
        updated_at=r.updated_at, deleted_at=r.deleted_at,
    )


@router.get("", response_model=PaginatedReceipts)
@limiter.limit("60/minute")
def list_receipts(
    request: Request,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    store_name: Optional[str] = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = db.query(Receipt).filter(
        Receipt.user_id == user.id, Receipt.deleted_at.is_(None)
    )
    if store_name:
        q = q.filter(Receipt.store_name.ilike(f"%{store_name}%"))
    total = q.count()
    items = q.order_by(Receipt.date.desc()).offset((page - 1) * per_page).limit(per_page).all()
    return PaginatedReceipts(
        items=[_to_out(r) for r in items],
        page=page, per_page=per_page, total=total,
        has_more=(page * per_page) < total,
    )


@router.get("/{receipt_id}", response_model=ReceiptOut)
def get_receipt(
    receipt_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    r = db.query(Receipt).filter(
        Receipt.id == receipt_id, Receipt.user_id == user.id
    ).first()
    if not r:
        raise HTTPException(status_code=404, detail="Receipt not found")
    return _to_out(r)


@router.post("", response_model=ReceiptOut, status_code=201)
@limiter.limit("30/minute")
def create_receipt(
    request: Request,
    req: ReceiptIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    r = Receipt(
        id=req.id, user_id=user.id, store_name=req.store_name,
        date=req.date, total=req.total, category_id=req.category_id,
        transaction_id=req.transaction_id, image_path=req.image_path,
        items_json=req.items_json, created_at=now, updated_at=now,
    )
    db.add(r)
    db.commit()
    db.refresh(r)
    return _to_out(r)


@router.delete("/{receipt_id}", status_code=204)
def delete_receipt(
    receipt_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    r = db.query(Receipt).filter(
        Receipt.id == receipt_id, Receipt.user_id == user.id
    ).first()
    if not r:
        raise HTTPException(status_code=404, detail="Receipt not found")
    r.deleted_at = datetime.now(timezone.utc)
    db.commit()
