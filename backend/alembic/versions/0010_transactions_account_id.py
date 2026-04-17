"""add account_id + transfer_group_id to transactions, backfill legacy default

Revision ID: 0010_txn_account
Revises: 0009_savings_goals
Create Date: 2026-04-17 00:00:02
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0010_txn_account"
down_revision: Union[str, None] = "0009_savings_goals"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Ensure every user has a "legacy-default-<user_id>" account.
    op.execute(
        """
        INSERT INTO accounts (
            id, user_id, name, bank, type, opening_balance,
            include_in_budget, archived, version, created_at, updated_at
        )
        SELECT
            'legacy-default-' || u.id, u.id, 'Default', 'other', 'current',
            0, TRUE, FALSE, 1, now(), now()
        FROM users u
        WHERE NOT EXISTS (
            SELECT 1 FROM accounts a WHERE a.id = 'legacy-default-' || u.id
        )
        """
    )

    # 2. Add nullable columns + indexes.
    op.add_column("transactions", sa.Column("account_id", sa.String(), nullable=True))
    op.add_column(
        "transactions", sa.Column("transfer_group_id", sa.String(length=64), nullable=True)
    )
    op.create_index(
        "ix_transactions_account_id", "transactions", ["account_id"]
    )
    op.create_index(
        "ix_transactions_transfer_group_id",
        "transactions",
        ["transfer_group_id"],
    )

    # 3. Backfill every existing transaction with its user's legacy default.
    op.execute(
        """
        UPDATE transactions
        SET account_id = 'legacy-default-' || user_id
        WHERE account_id IS NULL
        """
    )

    # 4. FK on account_id, ON DELETE SET NULL (stays nullable so older clients
    # without the column can still write).
    op.create_foreign_key(
        "fk_transactions_account_id",
        "transactions",
        "accounts",
        ["account_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_transactions_account_id", "transactions", type_="foreignkey")
    op.drop_index("ix_transactions_transfer_group_id", table_name="transactions")
    op.drop_index("ix_transactions_account_id", table_name="transactions")
    op.drop_column("transactions", "transfer_group_id")
    op.drop_column("transactions", "account_id")
