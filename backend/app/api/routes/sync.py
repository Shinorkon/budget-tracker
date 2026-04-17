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
from app.models.vendor_rule import VendorRule
from app.models.account import Account
from app.models.savings_goal import SavingsGoal

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/sync", tags=["sync"])


# ─── Schemas ──────────────────────────────────────────────────

class CategorySync(BaseModel):
    id: str
    name: str
    icon_code: int
    color_value: int
    budget_limit: float = 0
    version: int = 1
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class TransactionSync(BaseModel):
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
    version: int = 1
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class AccountSync(BaseModel):
    id: str
    name: str
    bank: str = "other"
    type: str = "current"
    opening_balance: float = 0
    include_in_budget: bool = True
    archived: bool = False
    version: int = 1
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class SavingsGoalSync(BaseModel):
    id: str
    account_id: Optional[str] = None
    name: str
    target_amount: float = 0
    monthly_target: float = 0
    start_month: datetime
    target_date: Optional[datetime] = None
    version: int = 1
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
    version: int = 1
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class VendorRuleSync(BaseModel):
    id: str
    pattern: str
    use_regex: bool = False
    category_id: str
    is_income: bool = False
    priority: int = 100
    version: int = 1
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class SyncRequest(BaseModel):
    last_synced_at: Optional[datetime] = None
    categories: list[CategorySync] = []
    transactions: list[TransactionSync] = []
    receipts: list[ReceiptSync] = []
    vendor_rules: list[VendorRuleSync] = []
    accounts: list[AccountSync] = []
    savings_goals: list[SavingsGoalSync] = []
    page: int = 1
    per_page: int = 500


class SyncResponse(BaseModel):
    server_time: datetime
    categories: list[CategorySync]
    transactions: list[TransactionSync]
    receipts: list[ReceiptSync]
    vendor_rules: list[VendorRuleSync] = []
    accounts: list[AccountSync] = []
    savings_goals: list[SavingsGoalSync] = []
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

        # ── Push: accounts first so transactions can FK-reference them ────
        for a in req.accounts:
            savepoint = db.begin_nested()
            try:
                existing = db.query(Account).filter(
                    Account.id == a.id, Account.user_id == user.id
                ).first()
                if existing:
                    client_version = a.version or 1
                    server_version = existing.version or 1
                    if client_version > server_version or (
                        client_version == server_version
                        and a.updated_at > (existing.updated_at or datetime.min.replace(tzinfo=timezone.utc))
                    ):
                        existing.name = a.name
                        existing.bank = a.bank
                        existing.type = a.type
                        existing.opening_balance = a.opening_balance
                        existing.include_in_budget = a.include_in_budget
                        existing.archived = a.archived
                        existing.version = client_version
                        existing.updated_at = a.updated_at
                        existing.deleted_at = a.deleted_at
                else:
                    db.add(Account(
                        id=a.id, user_id=user.id, name=a.name, bank=a.bank,
                        type=a.type, opening_balance=a.opening_balance,
                        include_in_budget=a.include_in_budget, archived=a.archived,
                        version=a.version, created_at=a.updated_at,
                        updated_at=a.updated_at, deleted_at=a.deleted_at,
                    ))
                savepoint.commit()
            except IntegrityError:
                savepoint.rollback()
                logger.warning(f"Account sync skip for user {user.id}, id={a.id}: duplicate")
                continue
            except SQLAlchemyError as e:
                savepoint.rollback()
                logger.error(f"Account sync error for user {user.id}: {str(e)}")
                raise HTTPException(
                    status_code=400,
                    detail="Failed to sync an account. Please try again."
                )

        try:
            db.flush()
        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"Account flush error for user {user.id}: {str(e)}")
            raise HTTPException(status_code=400, detail="Failed to save accounts. Please try again.")

        # ── Push: upsert client changes ──────────────────────────
        for c in req.categories:
            savepoint = db.begin_nested()
            try:
                existing = db.query(Category).filter(
                    Category.id == c.id, Category.user_id == user.id
                ).first()
                if existing:
                    # Version-based conflict resolution: higher version wins,
                    # fall back to updated_at if versions are equal
                    client_version = c.version or 1
                    server_version = existing.version or 1
                    if client_version > server_version or (
                        client_version == server_version
                        and c.updated_at > (existing.updated_at or datetime.min.replace(tzinfo=timezone.utc))
                    ):
                        existing.name = c.name
                        existing.icon_code = c.icon_code
                        existing.color_value = c.color_value
                        existing.budget_limit = c.budget_limit
                        existing.version = client_version
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
                        version=c.version,
                        created_at=c.updated_at,
                        updated_at=c.updated_at,
                        deleted_at=c.deleted_at,
                    ))
                savepoint.commit()
            except IntegrityError as e:
                savepoint.rollback()
                logger.warning(f"Category sync skip for user {user.id}, id={c.id}: duplicate")
                continue
            except SQLAlchemyError as e:
                savepoint.rollback()
                logger.error(f"Category sync error for user {user.id}: {str(e)}")
                raise HTTPException(
                    status_code=400,
                    detail="Failed to sync a category. Please try again."
                )

        # Flush so that FK validation for transactions can find newly-added categories
        try:
            db.flush()
        except IntegrityError as e:
            db.rollback()
            logger.error(f"Category flush error for user {user.id}: {str(e)}")
            raise HTTPException(status_code=400, detail="Category data conflict. Please try again.")
        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"Category flush error for user {user.id}: {str(e)}")
            raise HTTPException(status_code=400, detail="Failed to save categories. Please try again.")

        for t in req.transactions:
            savepoint = db.begin_nested()
            try:
                # Validate enum
                try:
                    tx_type = TransactionType(t.type)
                except (ValueError, KeyError):
                    savepoint.rollback()
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
                        # Category missing — clear the reference instead of failing
                        t.category_id = None

                # Validate amount
                if t.amount < 0:
                    savepoint.rollback()
                    raise HTTPException(
                        status_code=400,
                        detail="Transaction amount cannot be negative"
                    )

                # Older clients don't send account_id. Fall back to the
                # user's legacy default so the FK stays satisfied.
                resolved_account_id = t.account_id
                if resolved_account_id:
                    account_exists = db.query(Account).filter(
                        Account.id == resolved_account_id, Account.user_id == user.id
                    ).first()
                    if not account_exists:
                        resolved_account_id = None
                if not resolved_account_id:
                    resolved_account_id = f"legacy-default-{user.id}"

                existing = db.query(Transaction).filter(
                    Transaction.id == t.id, Transaction.user_id == user.id
                ).first()
                if existing:
                    client_version = t.version or 1
                    server_version = existing.version or 1
                    if client_version > server_version or (
                        client_version == server_version
                        and t.updated_at > (existing.updated_at or datetime.min.replace(tzinfo=timezone.utc))
                    ):
                        existing.category_id = t.category_id
                        existing.account_id = resolved_account_id
                        existing.transfer_group_id = t.transfer_group_id
                        existing.amount = t.amount
                        existing.date = t.date
                        existing.note = t.note
                        existing.type = tx_type
                        existing.store_name = t.store_name
                        existing.image_path = t.image_path
                        existing.currency = t.currency
                        existing.exchange_rate = t.exchange_rate
                        existing.version = client_version
                        existing.updated_at = t.updated_at
                        existing.deleted_at = t.deleted_at
                else:
                    db.add(Transaction(
                        id=t.id,
                        user_id=user.id,
                        category_id=t.category_id,
                        account_id=resolved_account_id,
                        transfer_group_id=t.transfer_group_id,
                        amount=t.amount,
                        date=t.date,
                        note=t.note,
                        type=tx_type,
                        store_name=t.store_name,
                        image_path=t.image_path,
                        currency=t.currency,
                        exchange_rate=t.exchange_rate,
                        version=t.version,
                        created_at=t.updated_at,
                        updated_at=t.updated_at,
                        deleted_at=t.deleted_at,
                    ))
                savepoint.commit()
            except HTTPException:
                raise
            except IntegrityError as e:
                savepoint.rollback()
                logger.warning(f"Transaction sync skip for user {user.id}, id={t.id}: duplicate")
                continue
            except SQLAlchemyError as e:
                savepoint.rollback()
                logger.error(f"Transaction sync error for user {user.id}: {str(e)}")
                raise HTTPException(
                    status_code=400,
                    detail="Failed to sync a transaction. Please try again."
                )

        # Flush so that FK validation for receipts can find newly-added transactions
        try:
            db.flush()
        except IntegrityError as e:
            db.rollback()
            logger.error(f"Transaction flush error for user {user.id}: {str(e)}")
            raise HTTPException(status_code=400, detail="Transaction data conflict. Please try again.")
        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"Transaction flush error for user {user.id}: {str(e)}")
            raise HTTPException(status_code=400, detail="Failed to save transactions. Please try again.")

        for r in req.receipts:
            savepoint = db.begin_nested()
            try:
                # Clear invalid foreign key references instead of failing
                if r.category_id:
                    category_exists = db.query(Category).filter(
                        Category.id == r.category_id, Category.user_id == user.id
                    ).first()
                    if not category_exists:
                        r.category_id = ""

                if r.transaction_id:
                    transaction_exists = db.query(Transaction).filter(
                        Transaction.id == r.transaction_id, Transaction.user_id == user.id
                    ).first()
                    if not transaction_exists:
                        r.transaction_id = ""

                existing = db.query(Receipt).filter(
                    Receipt.id == r.id, Receipt.user_id == user.id
                ).first()
                if existing:
                    client_version = r.version or 1
                    server_version = existing.version or 1
                    if client_version > server_version or (
                        client_version == server_version
                        and r.updated_at > (existing.updated_at or datetime.min.replace(tzinfo=timezone.utc))
                    ):
                        existing.store_name = r.store_name
                        existing.date = r.date
                        existing.total = r.total
                        existing.category_id = r.category_id
                        existing.transaction_id = r.transaction_id
                        existing.image_path = r.image_path
                        existing.items_json = r.items_json
                        existing.version = client_version
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
                        version=r.version,
                        created_at=r.updated_at,
                        updated_at=r.updated_at,
                        deleted_at=r.deleted_at,
                    ))
                savepoint.commit()
            except HTTPException:
                raise
            except IntegrityError as e:
                savepoint.rollback()
                logger.warning(f"Receipt sync skip for user {user.id}, id={r.id}: duplicate")
                continue
            except SQLAlchemyError as e:
                savepoint.rollback()
                logger.error(f"Receipt sync error for user {user.id}: {str(e)}")
                raise HTTPException(
                    status_code=400,
                    detail="Failed to sync a receipt. Please try again."
                )

        # ── Push: vendor rules ───────────────────────────────────
        for v in req.vendor_rules:
            savepoint = db.begin_nested()
            try:
                existing = db.query(VendorRule).filter(
                    VendorRule.id == v.id, VendorRule.user_id == user.id
                ).first()
                if existing:
                    client_version = v.version or 1
                    server_version = existing.version or 1
                    if client_version > server_version or (
                        client_version == server_version
                        and v.updated_at > (existing.updated_at or datetime.min.replace(tzinfo=timezone.utc))
                    ):
                        existing.pattern = v.pattern
                        existing.use_regex = v.use_regex
                        existing.category_id = v.category_id
                        existing.is_income = v.is_income
                        existing.priority = v.priority
                        existing.version = client_version
                        existing.updated_at = v.updated_at
                        existing.deleted_at = v.deleted_at
                else:
                    db.add(VendorRule(
                        id=v.id,
                        user_id=user.id,
                        pattern=v.pattern,
                        use_regex=v.use_regex,
                        category_id=v.category_id,
                        is_income=v.is_income,
                        priority=v.priority,
                        version=v.version,
                        created_at=v.updated_at,
                        updated_at=v.updated_at,
                        deleted_at=v.deleted_at,
                    ))
                savepoint.commit()
            except IntegrityError:
                savepoint.rollback()
                logger.warning(f"VendorRule sync skip for user {user.id}, id={v.id}: duplicate")
                continue
            except SQLAlchemyError as e:
                savepoint.rollback()
                logger.error(f"VendorRule sync error for user {user.id}: {str(e)}")
                raise HTTPException(
                    status_code=400,
                    detail="Failed to sync a vendor rule. Please try again."
                )

        # ── Push: savings goals ──────────────────────────────────
        for g in req.savings_goals:
            savepoint = db.begin_nested()
            try:
                # Validate account_id if present, else null it.
                if g.account_id:
                    acc_exists = db.query(Account).filter(
                        Account.id == g.account_id, Account.user_id == user.id
                    ).first()
                    if not acc_exists:
                        g.account_id = None

                existing = db.query(SavingsGoal).filter(
                    SavingsGoal.id == g.id, SavingsGoal.user_id == user.id
                ).first()
                if existing:
                    client_version = g.version or 1
                    server_version = existing.version or 1
                    if client_version > server_version or (
                        client_version == server_version
                        and g.updated_at > (existing.updated_at or datetime.min.replace(tzinfo=timezone.utc))
                    ):
                        existing.account_id = g.account_id
                        existing.name = g.name
                        existing.target_amount = g.target_amount
                        existing.monthly_target = g.monthly_target
                        existing.start_month = g.start_month
                        existing.target_date = g.target_date
                        existing.version = client_version
                        existing.updated_at = g.updated_at
                        existing.deleted_at = g.deleted_at
                else:
                    db.add(SavingsGoal(
                        id=g.id, user_id=user.id, account_id=g.account_id,
                        name=g.name, target_amount=g.target_amount,
                        monthly_target=g.monthly_target,
                        start_month=g.start_month, target_date=g.target_date,
                        version=g.version, created_at=g.updated_at,
                        updated_at=g.updated_at, deleted_at=g.deleted_at,
                    ))
                savepoint.commit()
            except IntegrityError:
                savepoint.rollback()
                logger.warning(f"SavingsGoal sync skip for user {user.id}, id={g.id}: duplicate")
                continue
            except SQLAlchemyError as e:
                savepoint.rollback()
                logger.error(f"SavingsGoal sync error for user {user.id}: {str(e)}")
                raise HTTPException(
                    status_code=400,
                    detail="Failed to sync a savings goal. Please try again."
                )

        try:
            db.commit()
        except IntegrityError as e:
            db.rollback()
            logger.error(f"Database commit error for user {user.id}: {str(e)}")
            raise HTTPException(
                status_code=400,
                detail="Data conflict during sync. Please try again."
            )
        except SQLAlchemyError as e:
            db.rollback()
            logger.error(f"Database commit error for user {user.id}: {str(e)}")
            raise HTTPException(
                status_code=400,
                detail="Failed to save sync changes. Please try again."
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

        server_rules = db.query(VendorRule).filter(
            VendorRule.user_id == user.id,
            VendorRule.updated_at > since,
        ).order_by(VendorRule.updated_at).all()

        server_accounts = db.query(Account).filter(
            Account.user_id == user.id,
            Account.updated_at > since,
        ).order_by(Account.updated_at).all()

        server_goals = db.query(SavingsGoal).filter(
            SavingsGoal.user_id == user.id,
            SavingsGoal.updated_at > since,
        ).order_by(SavingsGoal.updated_at).all()

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
                    version=c.version or 1,
                    updated_at=c.updated_at, deleted_at=c.deleted_at,
                ) for c in server_cats
            ],
            transactions=[
                TransactionSync(
                    id=t.id, category_id=t.category_id,
                    account_id=t.account_id, transfer_group_id=t.transfer_group_id,
                    amount=t.amount, date=t.date, note=t.note,
                    type=t.type.value, store_name=t.store_name,
                    image_path=t.image_path, currency=t.currency,
                    exchange_rate=t.exchange_rate, version=t.version or 1,
                    updated_at=t.updated_at, deleted_at=t.deleted_at,
                ) for t in server_txns
            ],
            receipts=[
                ReceiptSync(
                    id=r.id, store_name=r.store_name, date=r.date,
                    total=r.total, category_id=r.category_id,
                    transaction_id=r.transaction_id, image_path=r.image_path,
                    items_json=r.items_json, version=r.version or 1,
                    updated_at=r.updated_at, deleted_at=r.deleted_at,
                ) for r in server_rcpts
            ],
            vendor_rules=[
                VendorRuleSync(
                    id=v.id, pattern=v.pattern, use_regex=v.use_regex,
                    category_id=v.category_id, is_income=v.is_income,
                    priority=v.priority, version=v.version or 1,
                    updated_at=v.updated_at, deleted_at=v.deleted_at,
                ) for v in server_rules
            ],
            accounts=[
                AccountSync(
                    id=a.id, name=a.name, bank=a.bank, type=a.type,
                    opening_balance=a.opening_balance,
                    include_in_budget=a.include_in_budget,
                    archived=a.archived, version=a.version or 1,
                    updated_at=a.updated_at, deleted_at=a.deleted_at,
                ) for a in server_accounts
            ],
            savings_goals=[
                SavingsGoalSync(
                    id=g.id, account_id=g.account_id, name=g.name,
                    target_amount=g.target_amount,
                    monthly_target=g.monthly_target,
                    start_month=g.start_month, target_date=g.target_date,
                    version=g.version or 1,
                    updated_at=g.updated_at, deleted_at=g.deleted_at,
                ) for g in server_goals
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
