"""add string length limits to columns

Revision ID: 0004_string_limits
Revises: 0003_cascade_deletes
Create Date: 2026-04-10 00:00:01
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0004_string_limits"
down_revision: Union[str, None] = "0003_cascade_deletes"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # categories
    op.alter_column("categories", "name",
                    existing_type=sa.String(),
                    type_=sa.String(255))

    # transactions
    op.alter_column("transactions", "note",
                    existing_type=sa.String(),
                    type_=sa.String(1000))
    op.alter_column("transactions", "store_name",
                    existing_type=sa.String(),
                    type_=sa.String(255))
    op.alter_column("transactions", "image_path",
                    existing_type=sa.String(),
                    type_=sa.String(500))

    # receipts
    op.alter_column("receipts", "store_name",
                    existing_type=sa.String(),
                    type_=sa.String(255))
    op.alter_column("receipts", "image_path",
                    existing_type=sa.String(),
                    type_=sa.String(500))


def downgrade() -> None:
    # Revert to unlimited strings
    for table, col in [
        ("categories", "name"),
        ("transactions", "note"),
        ("transactions", "store_name"),
        ("transactions", "image_path"),
        ("receipts", "store_name"),
        ("receipts", "image_path"),
    ]:
        op.alter_column(table, col,
                        existing_type=sa.String(255),
                        type_=sa.String())
