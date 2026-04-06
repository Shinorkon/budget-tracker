"""add currency and exchange_rate to transactions

Revision ID: 0002_add_currency_to_transactions
Revises: 0001_initial_schema
Create Date: 2026-04-06 00:00:00
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0002_add_currency_to_transactions"
down_revision: Union[str, None] = "0001_initial_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add currency column to transactions
    op.add_column(
        "transactions",
        sa.Column("currency", sa.String(length=10), nullable=True, server_default="MVR")
    )
    # Add exchange_rate column to transactions
    op.add_column(
        "transactions",
        sa.Column("exchange_rate", sa.Float(), nullable=True)
    )


def downgrade() -> None:
    # Remove exchange_rate column
    op.drop_column("transactions", "exchange_rate")
    # Remove currency column
    op.drop_column("transactions", "currency")
