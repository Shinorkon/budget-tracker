"""add version columns for conflict resolution

Revision ID: 0005_version_cols
Revises: 0004_string_limits
Create Date: 2026-04-10 00:00:02
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0005_version_cols"
down_revision: Union[str, None] = "0004_string_limits"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    for table in ("categories", "transactions", "receipts"):
        op.add_column(
            table,
            sa.Column("version", sa.Integer(), nullable=True, server_default="1"),
        )


def downgrade() -> None:
    for table in ("categories", "transactions", "receipts"):
        op.drop_column(table, "version")
