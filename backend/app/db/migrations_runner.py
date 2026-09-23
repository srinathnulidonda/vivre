# app/db/migrations_runner.py

import sys
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlsplit, urlunsplit

from alembic import command
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, text

from app.db.neon_utils import ensure_direct_neon_endpoint

_PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
_ADVISORY_LOCK_WAIT_TIMEOUT_SECONDS = 60
_MIGRATION_ADVISORY_LOCK_ID = 741852963017


def _build_sync_psycopg2_url(asyncpg_url: str) -> str:
    split_url = urlsplit(asyncpg_url)
    query_params = parse_qs(split_url.query)
    if "ssl" in query_params:
        query_params["sslmode"] = query_params.pop("ssl")
    normalized_query = urlencode(query_params, doseq=True)
    return urlunsplit(
        ("postgresql+psycopg2", split_url.netloc, split_url.path, normalized_query, split_url.fragment)
    )


def _is_already_at_head(alembic_config: Config, sync_engine) -> bool:
    script = ScriptDirectory.from_config(alembic_config)
    head_revision = script.get_current_head()
    with sync_engine.connect() as connection:
        migration_context = MigrationContext.configure(connection)
        current_revision = migration_context.get_current_revision()
    return current_revision is not None and current_revision == head_revision


def run_database_migrations() -> None:
    from app.core.config import get_settings

    alembic_config = Config(str(_PROJECT_ROOT / "alembic.ini"))
    alembic_config.set_main_option("script_location", str(_PROJECT_ROOT / "alembic"))

    settings = get_settings()
    direct_url = ensure_direct_neon_endpoint(settings.direct_database_url)
    sync_url = _build_sync_psycopg2_url(direct_url)
    sync_connect_args = {"connect_timeout": int(settings.migrations_connect_timeout_seconds)}
    sync_engine = create_engine(sync_url, connect_args=sync_connect_args)

    lock_connection = sync_engine.connect()
    lock_connection.exec_driver_sql(f"SET lock_timeout = '{_ADVISORY_LOCK_WAIT_TIMEOUT_SECONDS}s'")
    lock_acquired = False

    try:
        print("migrations_runner: acquiring distributed migration lock", flush=True)
        lock_connection.execute(
            text("SELECT pg_advisory_lock(:lock_id)"), {"lock_id": _MIGRATION_ADVISORY_LOCK_ID}
        )
        lock_connection.commit()
        lock_acquired = True
        print("migrations_runner: distributed migration lock acquired", flush=True)

        if _is_already_at_head(alembic_config, sync_engine):
            print("migrations_runner: database already at head revision, skipping alembic upgrade", flush=True)
        else:
            print("migrations_runner: running alembic upgrade head", flush=True)
            try:
                command.upgrade(alembic_config, "head")
            except Exception as exc:
                print(f"migrations_runner: alembic upgrade failed: {exc!r}", file=sys.stderr, flush=True)
                raise
            print("migrations_runner: alembic upgrade completed", flush=True)
    finally:
        if lock_acquired:
            try:
                lock_connection.execute(
                    text("SELECT pg_advisory_unlock(:lock_id)"), {"lock_id": _MIGRATION_ADVISORY_LOCK_ID}
                )
                lock_connection.commit()
            except Exception as exc:
                print(f"migrations_runner: failed to release advisory lock: {exc!r}", file=sys.stderr, flush=True)
        lock_connection.close()
        sync_engine.dispose()


if __name__ == "__main__":
    run_database_migrations()