from __future__ import annotations

from decimal import Decimal

from fastapi.testclient import TestClient

from tests.conftest import create_product


def test_health_endpoints(client: TestClient) -> None:
    assert client.get("/health/live").json()["status"] == "ok"
    assert client.get("/health/ready").json()["status"] == "ready"


def test_product_search_and_details(client: TestClient, admin_headers: dict[str, str]) -> None:
    product = create_product(client, admin_headers)
    response = client.get("/api/v1/products", params={"q": "backpack", "category": "outdoor"})
    assert response.status_code == 200
    assert [row["id"] for row in response.json()] == [product["id"]]
    assert client.get(f"/api/v1/products/{product['id']}").json()["sku"] == "DEMO-001"
    assert client.get("/api/v1/products/999").status_code == 404


def test_order_takes_price_snapshot_and_replays_idempotently(
    client: TestClient, admin_headers: dict[str, str]
) -> None:
    product = create_product(client, admin_headers, price="12.50", stock=5)
    order_request = {
        "customer_email": "buyer@example.com",
        "items": [{"product_id": product["id"], "quantity": 2}],
    }
    headers = {"Idempotency-Key": "order-key-0001"}
    created = client.post("/api/v1/orders", json=order_request, headers=headers)
    assert created.status_code == 201, created.text
    first = created.json()
    assert Decimal(first["total_amount"]) == Decimal("25.00")
    assert Decimal(first["items"][0]["unit_price"]) == Decimal("12.50")

    updated = client.patch(
        f"/api/v1/admin/products/{product['id']}",
        headers=admin_headers,
        json={"price": "17.00", "stock": 1},
    )
    assert updated.status_code == 200
    replay = client.post("/api/v1/orders", json=order_request, headers=headers)
    assert replay.status_code == 201
    assert replay.json()["id"] == first["id"]
    assert Decimal(replay.json()["items"][0]["unit_price"]) == Decimal("12.50")
    assert client.get("/api/v1/products/1").json()["stock"] == 1

    different_request = {
        "customer_email": "buyer@example.com",
        "items": [{"product_id": product["id"], "quantity": 1}],
    }
    conflict = client.post("/api/v1/orders", json=different_request, headers=headers)
    assert conflict.status_code == 409


def test_insufficient_stock_does_not_create_order(client: TestClient, admin_headers: dict[str, str]) -> None:
    product = create_product(client, admin_headers, stock=1)
    response = client.post(
        "/api/v1/orders",
        headers={"Idempotency-Key": "order-key-stock"},
        json={"customer_email": "buyer@example.com", "items": [{"product_id": product["id"], "quantity": 2}]},
    )
    assert response.status_code == 409
    assert client.get(f"/api/v1/products/{product['id']}").json()["stock"] == 1


def test_admin_updates_are_protected_and_audited(client: TestClient, admin_headers: dict[str, str]) -> None:
    body = {
        "sku": "LOCKED-1",
        "name": "Protected Item",
        "price": "9.99",
        "stock": 3,
    }
    assert client.post("/api/v1/admin/products", json=body).status_code == 401
    product = create_product(client, admin_headers, sku="AUDIT-1")
    changed = client.patch(
        f"/api/v1/admin/products/{product['id']}", headers=admin_headers, json={"stock": 7}
    )
    assert changed.status_code == 200
    assert changed.json()["stock"] == 7
    audit = client.get(
        "/api/v1/admin/audit-events",
        headers=admin_headers,
        params={"entity_id": product["id"]},
    )
    assert audit.status_code == 200
    assert [event["action"] for event in audit.json()] == ["product.updated", "product.created"]
    assert all(event["actor"] == "test-operator" for event in audit.json())


def test_empty_admin_configuration_never_authenticates(
    client: TestClient, monkeypatch
) -> None:
    monkeypatch.setenv("ADMIN_TOKEN", "")
    response = client.get("/api/v1/admin/audit-events", headers={"X-Admin-Token": ""})
    assert response.status_code == 401


def test_validation_rejects_invalid_product_and_order(
    client: TestClient, admin_headers: dict[str, str]
) -> None:
    invalid_product = client.post(
        "/api/v1/admin/products",
        headers=admin_headers,
        json={"sku": "BAD-1", "name": "Invalid stock", "price": "9.99", "stock": -1},
    )
    assert invalid_product.status_code == 422

    invalid_order = client.post(
        "/api/v1/orders",
        headers={"Idempotency-Key": "invalid-order-1"},
        json={"customer_email": "not-an-email", "items": []},
    )
    assert invalid_order.status_code == 422


def test_cancelling_order_releases_stock_and_status_is_audited(
    client: TestClient, admin_headers: dict[str, str]
) -> None:
    product = create_product(client, admin_headers, stock=5)
    created = client.post(
        "/api/v1/orders",
        headers={"Idempotency-Key": "order-key-cancel"},
        json={"customer_email": "buyer@example.com", "items": [{"product_id": product["id"], "quantity": 2}]},
    )
    order = created.json()
    assert client.get(f"/api/v1/products/{product['id']}").json()["stock"] == 3
    cancelled = client.patch(
        f"/api/v1/admin/orders/{order['id']}/status",
        headers=admin_headers,
        json={"status": "cancelled"},
    )
    assert cancelled.status_code == 200
    assert cancelled.json()["status"] == "cancelled"
    assert client.get(f"/api/v1/products/{product['id']}").json()["stock"] == 5
    assert client.patch(
        f"/api/v1/admin/orders/{order['id']}/status",
        headers=admin_headers,
        json={"status": "confirmed"},
    ).status_code == 409

