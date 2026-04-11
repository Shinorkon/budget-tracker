"""widen icon_code and color_value to bigint for unsigned 32-bit values

Revision ID: 0006_bigint_cats
Revises: 0005_version_cols
Create Date: 2026-04-11 00:00:00
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0006_bigint_cats"
down_revision: Union[str, None] = "0005_version_cols"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "categories", "icon_code",
        existing_type=sa.Integer(),
        type_=sa.BigInteger(),
    )
    op.alter_column(
        "categories", "color_value",
        existing_type=sa.Integer(),
        type_=sa.BigInteger(),
    )


def downgrade() -> None:
    op.alter_column(
        "categories", "color_value",
        existing_type=sa.BigInteger(),
        type_=sa.Integer(),
    )
    op.alter_column(
        "categories", "icon_code",
        existing_type=sa.BigInteger(),
        type_=sa.Integer(),
    )
