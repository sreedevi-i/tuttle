"""Programmatic migration runner for Tuttle.

This module provides functions to run Alembic migrations from within
the application (e.g. at startup), without requiring the alembic CLI.

Usage:
    from tuttle.migrations.run import run_migrations
    run_migrations("sqlite:///path/to/tuttle.db")
"""

from pathlib import Path

from alembic import command
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory
from loguru import logger
from sqlalchemy import create_engine, inspect


# Directory containing this module (= the migrations package)
_MIGRATIONS_DIR = Path(__file__).parent


def _get_alembic_config(db_url: str) -> Config:
    """Create an Alembic Config pointing at the bundled migrations."""
    ini_path = _MIGRATIONS_DIR / "alembic.ini"
    cfg = Config(str(ini_path))
    cfg.set_main_option("script_location", str(_MIGRATIONS_DIR))
    cfg.set_main_option("sqlalchemy.url", db_url)
    return cfg


def get_head_revision() -> str | None:
    """Return the head revision from the migration scripts."""
    script = ScriptDirectory(str(_MIGRATIONS_DIR))
    return script.get_current_head()


def run_migrations(db_url: str) -> None:
    """Run all pending Alembic migrations on the database.

    Handles three scenarios:
    1. **New database** (no tables): Alembic creates everything via migrations.
    2. **Pre-Alembic database** (tables exist, no alembic_version):
       Stamps the DB at the baseline revision, then applies new migrations.
    3. **Migrated database** (alembic_version exists): Applies pending migrations.
    """
    head = get_head_revision()
    if head is None:
        logger.info("No migration scripts found, skipping migrations")
        return

    cfg = _get_alembic_config(db_url)
    engine = create_engine(db_url)

    try:
        insp = inspect(engine)
        table_names = insp.get_table_names()
        has_version_table = "alembic_version" in table_names
        has_app_tables = any(t != "alembic_version" for t in table_names)

        # Get current revision
        with engine.connect() as conn:
            ctx = MigrationContext.configure(conn)
            current = ctx.get_current_revision()

        if has_app_tables and not has_version_table:
            # Pre-Alembic database: stamp at baseline so future migrations apply
            script = ScriptDirectory(str(_MIGRATIONS_DIR))
            base = script.get_base()
            if base is None:
                logger.warning("No migration scripts found, nothing to stamp")
                return
            logger.info(
                "Pre-existing database detected without Alembic version table. "
                f"Stamping at baseline revision: {base}"
            )
            command.stamp(cfg, base)
            current = base

        if current == head:
            logger.debug(f"Database is already at head revision ({head})")
            return

        logger.info(f"Running migrations: {current} → {head}")
        command.upgrade(cfg, "head")
        logger.info("Migrations completed successfully")

    finally:
        engine.dispose()
