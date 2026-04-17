"""Individual CRUD endpoints for bank accounts (v1 API)."""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.db import get_db
from app.core.limiter import limiter
from app.core.security import get_current_user
from app.models.user import User
from app.models.account import Account

router = APIRouter(prefix="/api/v1/accounts", tags=["accounts"])


class AccountIn(BaseModel):
    id: str
    name: str
    bank: str = "other"
    type: str = "current"
    opening_balance: float = 0
    include_in_budget: bool = True
    archived: bool = False


class AccountOut(BaseModel):
    id: str
    name: str
    bank: str
    type: str
    opening_balance: float
    include_in_budget: bool
    archived: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class PaginatedAccounts(BaseModel):
    items: list[AccountOut]
    page: int
    per_page: int
    total: int
    has_more: bool


def _to_out(a: Account) -> AccountOut:
    return AccountOut(
        id=a.id, name=a.name, bank=a.bank, type=a.type,
        opening_balance=a.opening_balance,
        include_in_budget=a.include_in_budget,
        archived=a.archived, version=a.version or 1,
        created_at=a.created_at, updated_at=a.updated_at,
        deleted_at=a.deleted_at,
    )


@router.get("", response_model=PaginatedAccounts)
@limiter.limit("60/minute")
def list_accounts(
    request: Request,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = db.query(Account).filter(
        Account.user_id == user.id, Account.deleted_at.is_(None)
    )
    total = q.count()
    items = q.order_by(Account.name).offset((page - 1) * per_page).limit(per_page).all()
    return PaginatedAccounts(
        items=[_to_out(a) for a in items],
        page=page, per_page=per_page, total=total,
        has_more=(page * per_page) < total,
    )


@router.post("", response_model=AccountOut, status_code=201)
@limiter.limit("30/minute")
def create_account(
    request: Request,
    req: AccountIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    acc = Account(
        id=req.id, user_id=user.id, name=req.name,
        bank=req.bank, type=req.type,
        opening_balance=req.opening_balance,
        include_in_budget=req.include_in_budget,
        archived=req.archived,
        version=1, created_at=now, updated_at=now,
    )
    db.add(acc)
    db.commit()
    db.refresh(acc)
    return _to_out(acc)


@router.put("/{account_id}", response_model=AccountOut)
@limiter.limit("30/minute")
def update_account(
    request: Request,
    account_id: str,
    req: AccountIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    acc = db.query(Account).filter(
        Account.id == account_id, Account.user_id == user.id
    ).first()
    if not acc:
        raise HTTPException(status_code=404, detail="Account not found")
    acc.name = req.name
    acc.bank = req.bank
    acc.type = req.type
    acc.opening_balance = req.opening_balance
    acc.include_in_budget = req.include_in_budget
    acc.archived = req.archived
    acc.version = (acc.version or 1) + 1
    acc.updated_at = datetime.now(timezone.utc)
    db.commit()
    return _to_out(acc)


@router.delete("/{account_id}", status_code=204)
def delete_account(
    account_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    acc = db.query(Account).filter(
        Account.id == account_id, Account.user_id == user.id
    ).first()
    if not acc:
        raise HTTPException(status_code=404, detail="Account not found")
    acc.deleted_at = datetime.now(timezone.utc)
    db.commit()
