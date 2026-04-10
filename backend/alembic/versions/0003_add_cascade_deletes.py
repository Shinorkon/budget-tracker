"""add cascade delete rules to foreign keys

Revision ID: 0003_cascade_deletes
Revises: 0002_add_currency_txn
Create Date: 2026-04-10 00:00:00
"""

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "0003_cascade_deletes"
down_revision: Union[str, None] = "0002_add_currency_txn"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # categories.user_id -> CASCADE
    op.drop_constraint("categories_user_id_fkey", "categories", type_="foreignkey")
    op.create_foreign_key(
        "categories_user_id_fkey", "categories", "users",
        ["user_id"], ["id"], ondelete="CASCADE",
    )

    # transactions.user_id -> CASCADE
    op.drop_constraint("transactions_user_id_fkey", "transactions", type_="foreignkey")
    op.create_foreign_key(
        "transactions_user_id_fkey", "transactions", "users",
        ["user_id"], ["id"], ondelete="CASCADE",
    )

    # transactions.category_id -> SET NULL
    op.drop_constraint("transactions_category_id_fkey", "transactions", type_="foreignkey")
    op.create_foreign_key(
        "transactions_category_id_fkey", "transactions", "categories",
        ["category_id"], ["id"], ondelete="SET NULL",
    )

    # receipts.user_id -> CASCADE
    op.drop_constraint("receipts_user_id_fkey", "receipts", type_="foreignkey")
    op.create_foreign_key(
        "receipts_user_id_fkey", "receipts", "users",
        ["user_id"], ["id"], ondelete="CASCADE",
    )

    # refresh_tokens.user_id -> CASCADE
    op.drop_constraint("refresh_tokens_user_id_fkey", "refresh_tokens", type_="foreignkey")
    op.create_foreign_key(
        "refresh_tokens_user_id_fkey", "refresh_tokens", "users",
        ["user_id"], ["id"], ondelete="CASCADE",
    )


def downgrade() -> None:
    # Revert all foreign keys back to no action
    for table, col, ref_table in [
        ("categories", "user_id", "users"),
        ("transactions", "user_id", "users"),
        ("transactions", "category_id", "categories"),
        ("receipts", "user_id", "users"),
        ("refresh_tokens", "user_id", "users"),
    ]:
        fk_name = f"{table}_{col}_fkey"
        op.drop_constraint(fk_name, table, type_="foreignkey")
        op.create_foreign_key(fk_name, table, ref_table, [col], ["id"])
