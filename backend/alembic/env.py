# alembic/env.py
import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from app.core.config import get_settings
from app.db.base import Base
from app.db.neon_utils import ensure_asyncpg_driver, ensure_direct_neon_endpoint, parse_ssl_mode
from app.models import health as _health_module
from app.models import notes as _notes_module
from app.models import notifications as _notifications_module
from app.models import personal as _personal_module
from app.models import reviews as _reviews_module
from app.models import user as _user_module
from app.models import work as _work_module

_registered_models = (
    _health_module,
    _notes_module,
    _notifications_module,
    _personal_module,
    _reviews_module,
    _user_module,
    _work_module,
)

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

MIGRATION_LOCK_TIMEOUT_SECONDS = 10
MIGRATION_STATEMENT_TIMEOUT_SECONDS = 60


def get_direct_url() -> str:
    return ensure_direct_neon_endpoint(get_settings().direct_database_url)


def get_url() -> str:
    return ensure_asyncpg_driver(get_direct_url())


def run_migrations_offline() -> None:
    context.configure(
        url=get_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    settings = get_settings()
    ssl_mode = parse_ssl_mode(get_direct_url())
    configuration = config.get_section(config.config_ini_section) or {}
    configuration["sqlalchemy.url"] = get_url()
    connect_args = {
        "timeout": settings.migrations_connect_timeout_seconds,
        "ssl": ssl_mode,
        "server_settings": {
            "lock_timeout": f"{MIGRATION_LOCK_TIMEOUT_SECONDS}s",
            "statement_timeout": f"{MIGRATION_STATEMENT_TIMEOUT_SECONDS}s",
        },
    }
    if ssl_mode == "disable":
        connect_args.pop("ssl")
    connectable = async_engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
        connect_args=connect_args,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
        await connection.commit()
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())