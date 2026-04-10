from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr, field_validator
from app.core.db import get_db
from app.core.limiter import limiter
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    verify_refresh_token,
    get_current_user,
)
from app.models.user import User
from app.models.refresh_token import RefreshToken
import uuid

router = APIRouter(prefix="/api/auth", tags=["auth"])
router_v1 = APIRouter(prefix="/api/v1/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    email: EmailStr
    username: str
    password: str

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class LoginRequest(BaseModel):
    email: str
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    id: str
    email: str
    username: str
    currency: str


@router.post("/register", response_model=TokenResponse, status_code=201)
@limiter.limit("5/minute")
def register(request: Request, req: RegisterRequest, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == req.email).first():
        raise HTTPException(status_code=409, detail="Email already registered")
    if db.query(User).filter(User.username == req.username).first():
        raise HTTPException(status_code=409, detail="Username already taken")

    user = User(
        id=str(uuid.uuid4()),
        email=req.email,
        username=req.username,
        hashed_password=get_password_hash(req.password),
    )
    db.add(user)
    db.flush()

    access_token = create_access_token({"sub": user.id})
    refresh_token = create_refresh_token(user.id, db)
    db.commit()

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login(request: Request, req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user or not verify_password(req.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account disabled")

    access_token = create_access_token({"sub": user.id})
    refresh_token = create_refresh_token(user.id, db)
    db.commit()

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("10/minute")
def refresh(request: Request, req: RefreshRequest, db: Session = Depends(get_db)):
    user, old_token = verify_refresh_token(req.refresh_token, db)

    # Revoke old token
    old_token.revoked = True
    db.flush()

    access_token = create_access_token({"sub": user.id})
    new_refresh = create_refresh_token(user.id, db)
    db.commit()

    return TokenResponse(access_token=access_token, refresh_token=new_refresh)


@router.get("/me", response_model=UserResponse)
def me(user: User = Depends(get_current_user)):
    return UserResponse(
        id=user.id,
        email=user.email,
        username=user.username,
        currency=user.currency,
    )


class UpdateCurrencyRequest(BaseModel):
    currency: str


@router.patch("/me/currency", response_model=UserResponse)
def update_currency(
    req: UpdateCurrencyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Update the user's primary currency preference."""
    if not req.currency or len(req.currency) > 10:
        raise HTTPException(
            status_code=400,
            detail="Invalid currency code. Must be 1-10 characters.",
        )

    user.currency = req.currency.upper()
    db.commit()

    return UserResponse(
        id=user.id,
        email=user.email,
        username=user.username,
        currency=user.currency,
    )


@router.post("/logout", status_code=204)
def logout(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Revoke all refresh tokens for the current user."""
    db.query(RefreshToken).filter(
        RefreshToken.user_id == user.id,
        RefreshToken.revoked == False,  # noqa: E712
    ).update({"revoked": True})
    db.commit()


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def new_password_min_length(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("New password must be at least 8 characters")
        return v


@router.post("/change-password", status_code=204)
@limiter.limit("5/minute")
def change_password(
    request: Request,
    req: ChangePasswordRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Change the current user's password. Revokes all existing refresh tokens."""
    if not verify_password(req.old_password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    user.hashed_password = get_password_hash(req.new_password)

    # Revoke all refresh tokens so other sessions must re-authenticate
    db.query(RefreshToken).filter(
        RefreshToken.user_id == user.id,
        RefreshToken.revoked == False,  # noqa: E712
    ).update({"revoked": True})

    db.commit()


@router_v1.delete("/account", status_code=204)
def delete_account(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Permanently delete the user account and all associated data.
    CASCADE DELETE rules handle categories, transactions, receipts, and tokens.
    """
    db.delete(user)
    db.commit()
