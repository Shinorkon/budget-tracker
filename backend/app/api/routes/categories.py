"""Individual CRUD endpoints for categories (v1 API)."""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.db import get_db
from app.core.limiter import limiter
from app.core.security import get_current_user
from app.models.user import User
from app.models.category import Category

router = APIRouter(prefix="/api/v1/categories", tags=["categories"])


class CategoryIn(BaseModel):
    id: str
    name: str
    icon_code: int
    color_value: int
    budget_limit: float = 0


class CategoryOut(BaseModel):
    id: str
    name: str
    icon_code: int
    color_value: int
    budget_limit: float
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class PaginatedCategories(BaseModel):
    items: list[CategoryOut]
    page: int
    per_page: int
    total: int
    has_more: bool


def _to_out(c: Category) -> CategoryOut:
    return CategoryOut(
        id=c.id, name=c.name, icon_code=c.icon_code,
        color_value=c.color_value, budget_limit=c.budget_limit,
        updated_at=c.updated_at, deleted_at=c.deleted_at,
    )


@router.get("", response_model=PaginatedCategories)
@limiter.limit("60/minute")
def list_categories(
    request: Request,
    page: int = Query(1, ge=1),
    per_page: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = db.query(Category).filter(
        Category.user_id == user.id, Category.deleted_at.is_(None)
    )
    total = q.count()
    items = q.order_by(Category.name).offset((page - 1) * per_page).limit(per_page).all()
    return PaginatedCategories(
        items=[_to_out(c) for c in items],
        page=page, per_page=per_page, total=total,
        has_more=(page * per_page) < total,
    )


@router.get("/{category_id}", response_model=CategoryOut)
def get_category(
    category_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    cat = db.query(Category).filter(
        Category.id == category_id, Category.user_id == user.id
    ).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    return _to_out(cat)


@router.post("", response_model=CategoryOut, status_code=201)
@limiter.limit("30/minute")
def create_category(
    request: Request,
    req: CategoryIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    cat = Category(
        id=req.id, user_id=user.id, name=req.name,
        icon_code=req.icon_code, color_value=req.color_value,
        budget_limit=req.budget_limit,
        created_at=now, updated_at=now,
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return _to_out(cat)


@router.put("/{category_id}", response_model=CategoryOut)
@limiter.limit("30/minute")
def update_category(
    request: Request,
    category_id: str,
    req: CategoryIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    cat = db.query(Category).filter(
        Category.id == category_id, Category.user_id == user.id
    ).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    cat.name = req.name
    cat.icon_code = req.icon_code
    cat.color_value = req.color_value
    cat.budget_limit = req.budget_limit
    cat.updated_at = datetime.now(timezone.utc)
    db.commit()
    return _to_out(cat)


@router.delete("/{category_id}", status_code=204)
def delete_category(
    category_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    cat = db.query(Category).filter(
        Category.id == category_id, Category.user_id == user.id
    ).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    cat.deleted_at = datetime.now(timezone.utc)
    db.commit()
