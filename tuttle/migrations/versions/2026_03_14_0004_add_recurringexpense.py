"""add recurringexpense

Revision ID: 0004
Revises: 0003
Create Date: 2026-03-14 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "recurringexpense",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(), nullable=False, server_default="EUR"),
        sa.Column(
            "period",
            sa.Enum(
                "hourly",
                "daily",
                "weekly",
                "monthly",
                "quarterly",
                "yearly",
                name="cycle",
            ),
            nullable=False,
        ),
        sa.Column("category", sa.String(), nullable=False, server_default="operating"),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("recurringexpense")
