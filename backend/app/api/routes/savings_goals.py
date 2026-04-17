"""Individual CRUD endpoints for savings goals (v1 API)."""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.db import get_db
from app.core.limiter import limiter
from app.core.security import get_current_user
from app.models.user import User
from app.models.savings_goal import SavingsGoal

router = APIRouter(prefix="/api/v1/savings-goals", tags=["savings-goals"])


class SavingsGoalIn(BaseModel):
    id: str
    account_id: Optional[str] = None
    name: str
    target_amount: float = 0
    monthly_target: float = 0
    start_month: datetime
    target_date: Optional[datetime] = None


class SavingsGoalOut(BaseModel):
    id: str
    account_id: Optional[str] = None
    name: str
    target_amount: float
    monthly_target: float
    start_month: datetime
    target_date: Optional[datetime] = None
    version: int
    updated_at: datetime
    deleted_at: Optional[datetime] = None


def _to_out(g: SavingsGoal) -> SavingsGoalOut:
    return SavingsGoalOut(
        id=g.id, account_id=g.account_id, name=g.name,
        target_amount=g.target_amount, monthly_target=g.monthly_target,
        start_month=g.start_month, target_date=g.target_date,
        version=g.version or 1, updated_at=g.updated_at,
        deleted_at=g.deleted_at,
    )


@router.get("", response_model=list[SavingsGoalOut])
@limiter.limit("60/minute")
def list_goals(
    request: Request,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    q = db.query(SavingsGoal).filter(
        SavingsGoal.user_id == user.id, SavingsGoal.deleted_at.is_(None)
    ).order_by(SavingsGoal.name)
    return [_to_out(g) for g in q.all()]


@router.post("", response_model=SavingsGoalOut, status_code=201)
@limiter.limit("30/minute")
def create_goal(
    request: Request,
    req: SavingsGoalIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc)
    goal = SavingsGoal(
        id=req.id, user_id=user.id, account_id=req.account_id,
        name=req.name, target_amount=req.target_amount,
        monthly_target=req.monthly_target, start_month=req.start_month,
        target_date=req.target_date,
        version=1, created_at=now, updated_at=now,
    )
    db.add(goal)
    db.commit()
    db.refresh(goal)
    return _to_out(goal)


@router.put("/{goal_id}", response_model=SavingsGoalOut)
@limiter.limit("30/minute")
def update_goal(
    request: Request,
    goal_id: str,
    req: SavingsGoalIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    goal = db.query(SavingsGoal).filter(
        SavingsGoal.id == goal_id, SavingsGoal.user_id == user.id
    ).first()
    if not goal:
        raise HTTPException(status_code=404, detail="Savings goal not found")
    goal.account_id = req.account_id
    goal.name = req.name
    goal.target_amount = req.target_amount
    goal.monthly_target = req.monthly_target
    goal.start_month = req.start_month
    goal.target_date = req.target_date
    goal.version = (goal.version or 1) + 1
    goal.updated_at = datetime.now(timezone.utc)
    db.commit()
    return _to_out(goal)


@router.delete("/{goal_id}", status_code=204)
def delete_goal(
    goal_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    goal = db.query(SavingsGoal).filter(
        SavingsGoal.id == goal_id, SavingsGoal.user_id == user.id
    ).first()
    if not goal:
        raise HTTPException(status_code=404, detail="Savings goal not found")
    goal.deleted_at = datetime.now(timezone.utc)
    db.commit()
