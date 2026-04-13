"""add vendor_rules table for user-defined vendor->category mapping

Revision ID: 0007_vendor_rules
Revises: 0006_bigint_cats
Create Date: 2026-04-12 00:00:00
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0007_vendor_rules"
down_revision: Union[str, None] = "0006_bigint_cats"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "vendor_rules",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("pattern", sa.String(length=512), nullable=False),
        sa.Column("use_regex", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("category_id", sa.String(), nullable=False),
        sa.Column("is_income", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("priority", sa.Integer(), nullable=False, server_default="100"),
        sa.Column("version", sa.Integer(), nullable=True, server_default="1"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=True,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=True,
            server_default=sa.text("now()"),
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_vendor_rules_user_id", "vendor_rules", ["user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_vendor_rules_user_id", table_name="vendor_rules")
    op.drop_table("vendor_rules")
