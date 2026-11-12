"""SQLAlchemy engine and session management."""

from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import database_url


class Base(DeclarativeBase):
    pass


def make_engine(url: str | None = None):
    target = url or database_url()
    options: dict[str, object] = {"pool_pre_ping": True}
    if target.startswith("sqlite"):
        options["connect_args"] = {"check_same_thread": False}
    return create_engine(target, **options)


engine = make_engine()
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_session() -> Generator[Session, None, None]:
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
