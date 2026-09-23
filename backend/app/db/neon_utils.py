# app/db/neon_utils.py

from urllib.parse import parse_qs, urlsplit, urlunsplit

_POOLER_HOST_MARKER = "-pooler."
_LOCAL_HOSTNAMES = {"localhost", "127.0.0.1", "::1"}


def ensure_direct_neon_endpoint(database_url: str) -> str:
    split_url = urlsplit(database_url)
    hostname = split_url.hostname
    if not hostname or _POOLER_HOST_MARKER not in hostname:
        return database_url

    direct_hostname = hostname.replace(_POOLER_HOST_MARKER, ".", 1)

    netloc = direct_hostname
    if split_url.username:
        credentials = split_url.username
        if split_url.password:
            credentials = f"{credentials}:{split_url.password}"
        netloc = f"{credentials}@{netloc}"
    if split_url.port:
        netloc = f"{netloc}:{split_url.port}"

    return urlunsplit((split_url.scheme, netloc, split_url.path, split_url.query, split_url.fragment))


def parse_ssl_mode(database_url: str) -> str:
    """Extract an sslmode-style value from a connection URL's query string.

    Looks at both `sslmode` (libpq convention) and `ssl` (shorthand some
    providers use), normalizes booleans, and falls back to `require` for
    non-local hosts (Neon always requires TLS) or `disable` for localhost.
    """
    split_url = urlsplit(database_url)
    query_params = parse_qs(split_url.query)

    for key in ("sslmode", "ssl"):
        if key in query_params and query_params[key]:
            raw_value = query_params[key][0].strip().lower()
            if raw_value in ("true", "1", "yes"):
                return "require"
            if raw_value in ("false", "0", "no"):
                return "disable"
            if raw_value in ("disable", "allow", "prefer", "require", "verify-ca", "verify-full"):
                return raw_value

    hostname = split_url.hostname or ""
    return "disable" if hostname in _LOCAL_HOSTNAMES else "require"


def ensure_asyncpg_driver(database_url: str) -> str:
    """Normalize any postgres-style URL for use with the asyncpg driver.

    Rewrites the scheme to `postgresql+asyncpg` and strips ALL query
    parameters. asyncpg re-parses query-string parameters embedded in a
    DSN with much stricter validation than libpq (e.g. it rejects
    `channel_binding` outright, and is picky about exact `sslmode`
    string values). SSL and other connection options should instead be
    supplied explicitly via `connect_args` — see `parse_ssl_mode()`.
    """
    split_url = urlsplit(database_url)
    scheme = split_url.scheme
    new_scheme = "postgresql+asyncpg" if scheme in ("postgres", "postgresql", "postgresql+psycopg2") else scheme
    return urlunsplit((new_scheme, split_url.netloc, split_url.path, "", split_url.fragment))