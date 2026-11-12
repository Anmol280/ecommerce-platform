"""Environment-based application settings."""

from __future__ import annotations

import os

from sqlalchemy.engine import URL


def database_url() -> str:
    explicit_url = os.getenv("DATABASE_URL")
    if explicit_url:
        return explicit_url

    postgres_host = os.getenv("POSTGRES_HOST")
    if postgres_host:
        url = URL.create(
            "postgresql+psycopg",
            username=os.getenv("POSTGRES_USER", "ecommerce"),
            password=os.getenv("POSTGRES_PASSWORD", ""),
            host=postgres_host,
            port=int(os.getenv("POSTGRES_PORT", "5432")),
            database=os.getenv("POSTGRES_DB", "ecommerce"),
        )
        return url.render_as_string(hide_password=False)

    return "sqlite:///./local.db"


def admin_token() -> str:
    # Compose supplies a local-only demo token. A bare process without explicit
    # configuration has no usable admin credential by default.
    return os.getenv("ADMIN_TOKEN", "")


def service_name() -> str:
    return os.getenv("SERVICE_NAME", "ecommerce-product-order-api")
