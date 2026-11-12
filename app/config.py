"""Environment-based application settings."""

from __future__ import annotations

import os


def database_url() -> str:
    return os.getenv("DATABASE_URL", "sqlite:///./local.db")


def admin_token() -> str:
    # Compose supplies a local-only demo token. A bare process without explicit
    # configuration has no usable admin credential by default.
    return os.getenv("ADMIN_TOKEN", "")


def service_name() -> str:
    return os.getenv("SERVICE_NAME", "ecommerce-product-order-api")
