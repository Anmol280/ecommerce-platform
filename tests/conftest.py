from __future__ import annotations

from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_session
from app.main import app


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch) -> Generator[TestClient, None, None]:
    monkeypatch.setenv("ADMIN_TOKEN", "test-secret-token")
    test_engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSession = sessionmaker(bind=test_engine, autoflush=False, expire_on_commit=False)
    Base.metadata.create_all(test_engine)

    def override_session():
        session: Session = TestingSession()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_session] = override_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    Base.metadata.drop_all(test_engine)
    test_engine.dispose()


@pytest.fixture()
def admin_headers() -> dict[str, str]:
    return {"X-Admin-Token": "test-secret-token", "X-Admin-Actor": "test-operator"}


def create_product(client: TestClient, headers: dict[str, str], **overrides) -> dict:
    body = {
        "sku": "DEMO-001",
        "name": "Trail Backpack",
        "description": "A compact day pack",
        "category": "Outdoor",
        "price": "49.99",
        "currency": "INR",
        "stock": 10,
        "active": True,
    }
    body.update(overrides)
    response = client.post("/api/v1/admin/products", headers=headers, json=body)
    assert response.status_code == 201, response.text
    return response.json()
