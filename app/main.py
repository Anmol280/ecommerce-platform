"""HTTP API for product catalog, checkout, and order operations."""

from __future__ import annotations

import hashlib
import json
import logging
import re
import time
from decimal import Decimal
from secrets import compare_digest
from typing import Annotated
from uuid import uuid4

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, Response, status
from sqlalchemy import func, or_, select, text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session, selectinload

from app.config import admin_token, service_name
from app.database import get_session
from app.logging_config import configure_logging
from app.models import AuditEvent, Order, OrderItem, Product
from app.schemas import (
    AuditEventOut,
    HealthOut,
    OrderCreate,
    OrderOut,
    OrderStatusUpdate,
    ProductCreate,
    ProductOut,
    ProductUpdate,
)

configure_logging()
logger = logging.getLogger("ecommerce.api")

app = FastAPI(
    title="E-Commerce Product and Order API",
    description="A compact, deployable product catalog and order service.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url=None,
)


def _audit(
    db: Session,
    actor: str,
    action: str,
    entity_type: str,
    entity_id: int | str,
    details: dict,
) -> None:
    db.add(
        AuditEvent(
            actor=actor,
            action=action,
            entity_type=entity_type,
            entity_id=str(entity_id),
            details=details,
        )
    )


def require_admin(
    supplied: Annotated[str | None, Header(alias="X-Admin-Token")] = None,
    actor: Annotated[str | None, Header(alias="X-Admin-Actor")] = None,
) -> str:
    expected = admin_token()
    if not expected or supplied is None or not compare_digest(supplied, expected):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Valid admin token required")
    return (actor or "admin").strip()[:120] or "admin"


@app.middleware("http")
async def request_logging(request: Request, call_next):
    incoming_id = request.headers.get("X-Request-ID", "")
    request_id = incoming_id if re.fullmatch(r"[A-Za-z0-9._-]{1,64}", incoming_id) else str(uuid4())
    request.state.request_id = request_id
    started = time.perf_counter()
    response: Response | None = None
    try:
        response = await call_next(request)
        return response
    finally:
        duration_ms = round((time.perf_counter() - started) * 1000, 2)
        code = response.status_code if response is not None else 500
        logger.info(
            "http_request",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": code,
                "duration_ms": duration_ms,
            },
        )
        if response is not None:
            response.headers["X-Request-ID"] = request_id


@app.get("/health/live", response_model=HealthOut, tags=["health"])
def liveness() -> HealthOut:
    """Indicates that the API process is accepting requests."""
    return HealthOut(status="ok", service=service_name())


@app.get("/health/ready", response_model=HealthOut, tags=["health"])
def readiness(db: Session = Depends(get_session)) -> HealthOut:
    """Checks that the configured database can answer a simple query."""
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        raise HTTPException(status_code=503, detail="Database is not ready") from exc
    return HealthOut(status="ready", service=service_name())


@app.get("/api/v1/products", response_model=list[ProductOut], tags=["products"])
def search_products(
    q: str | None = Query(default=None, max_length=120),
    category: str | None = Query(default=None, max_length=80),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_session),
) -> list[Product]:
    statement = select(Product).where(Product.active.is_(True))
    if q and q.strip():
        term = f"%{q.strip()}%"
        statement = statement.where(
            or_(Product.name.ilike(term), Product.sku.ilike(term), Product.description.ilike(term))
        )
    if category and category.strip():
        statement = statement.where(func.lower(Product.category) == category.strip().lower())
    statement = statement.order_by(Product.id).offset(skip).limit(limit)
    return list(db.scalars(statement).all())


@app.get("/api/v1/products/{product_id}", response_model=ProductOut, tags=["products"])
def get_product(product_id: int, db: Session = Depends(get_session)) -> Product:
    product = db.scalar(select(Product).where(Product.id == product_id, Product.active.is_(True)))
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


def _canonical_order_hash(payload: OrderCreate) -> str:
    quantities: dict[int, int] = {}
    for item in payload.items:
        quantities[item.product_id] = quantities.get(item.product_id, 0) + item.quantity
    canonical = {
        "customer_email": str(payload.customer_email).lower(),
        "items": [
            {"product_id": product_id, "quantity": quantity}
            for product_id, quantity in sorted(quantities.items())
        ],
    }
    return hashlib.sha256(json.dumps(canonical, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _existing_idempotent_order(db: Session, key: str) -> Order | None:
    return db.scalar(select(Order).options(selectinload(Order.items)).where(Order.idempotency_key == key))


@app.post("/api/v1/orders", response_model=OrderOut, status_code=201, tags=["orders"])
def create_order(
    payload: OrderCreate,
    idempotency_key: Annotated[str, Header(alias="Idempotency-Key", min_length=8, max_length=128)],
    db: Session = Depends(get_session),
) -> Order:
    request_hash = _canonical_order_hash(payload)
    existing = _existing_idempotent_order(db, idempotency_key)
    if existing is not None:
        if existing.request_hash != request_hash:
            raise HTTPException(
                status_code=409,
                detail="Idempotency key was already used with a different request",
            )
        return existing

    quantities: dict[int, int] = {}
    for item in payload.items:
        quantities[item.product_id] = quantities.get(item.product_id, 0) + item.quantity

    # Lock products in stable ID order to avoid checkout deadlocks on PostgreSQL.
    products = list(
        db.scalars(
            select(Product).where(Product.id.in_(sorted(quantities))).order_by(Product.id).with_for_update()
        ).all()
    )
    by_id = {product.id: product for product in products}
    missing = sorted(set(quantities) - set(by_id))
    if missing:
        raise HTTPException(status_code=404, detail={"message": "Product not found", "product_ids": missing})
    for product_id, quantity in quantities.items():
        product = by_id[product_id]
        if not product.active:
            raise HTTPException(status_code=409, detail=f"Product {product.sku} is not available")
        if product.stock < quantity:
            raise HTTPException(status_code=409, detail=f"Insufficient stock for product {product.sku}")

    currencies = {by_id[product_id].currency for product_id in quantities}
    if len(currencies) != 1:
        raise HTTPException(status_code=409, detail="An order must contain products in one currency")
    currency = next(iter(currencies))
    order = Order(
        customer_email=str(payload.customer_email).lower(),
        status="pending",
        idempotency_key=idempotency_key,
        request_hash=request_hash,
        currency=currency,
        total_amount=Decimal("0.00"),
    )
    total = Decimal("0.00")
    for product_id, quantity in sorted(quantities.items()):
        product = by_id[product_id]
        product.stock -= quantity
        line_total = product.price * quantity
        total += line_total
        order.items.append(
            OrderItem(
                product_id=product.id,
                sku_snapshot=product.sku,
                name_snapshot=product.name,
                quantity=quantity,
                unit_price=product.price,
                line_total=line_total,
            )
        )
    order.total_amount = total
    db.add(order)
    try:
        db.commit()
    except IntegrityError:
        # A concurrent request with the same key may win after our first lookup.
        db.rollback()
        existing = _existing_idempotent_order(db, idempotency_key)
        if existing is not None:
            if existing.request_hash != request_hash:
                raise HTTPException(
                    status_code=409,
                    detail="Idempotency key was already used with a different request",
                )
            return existing
        raise HTTPException(status_code=409, detail="Order could not be created because of a data conflict")
    db.refresh(order)
    return order


@app.get("/api/v1/orders/{order_id}", response_model=OrderOut, tags=["orders"])
def get_order(order_id: int, db: Session = Depends(get_session)) -> Order:
    order = db.scalar(select(Order).options(selectinload(Order.items)).where(Order.id == order_id))
    if order is None:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@app.post("/api/v1/admin/products", response_model=ProductOut, status_code=201, tags=["admin"])
def create_product(
    payload: ProductCreate,
    actor: str = Depends(require_admin),
    db: Session = Depends(get_session),
) -> Product:
    product = Product(**payload.model_dump())
    db.add(product)
    try:
        db.flush()
        _audit(db, actor, "product.created", "product", product.id, {"sku": product.sku})
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="A product with that SKU already exists") from exc
    db.refresh(product)
    return product


@app.patch("/api/v1/admin/products/{product_id}", response_model=ProductOut, tags=["admin"])
def update_product(
    product_id: int,
    payload: ProductUpdate,
    actor: str = Depends(require_admin),
    db: Session = Depends(get_session),
) -> Product:
    product = db.scalar(select(Product).where(Product.id == product_id).with_for_update())
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    changes = payload.model_dump(exclude_unset=True)
    for field, value in changes.items():
        setattr(product, field, value)
    _audit(db, actor, "product.updated", "product", product.id, {"fields": sorted(changes)})
    db.commit()
    db.refresh(product)
    return product


@app.patch("/api/v1/admin/orders/{order_id}/status", response_model=OrderOut, tags=["admin"])
def update_order_status(
    order_id: int,
    payload: OrderStatusUpdate,
    actor: str = Depends(require_admin),
    db: Session = Depends(get_session),
) -> Order:
    order = db.scalar(
        select(Order).options(selectinload(Order.items)).where(Order.id == order_id).with_for_update()
    )
    if order is None:
        raise HTTPException(status_code=404, detail="Order not found")
    allowed = {
        "pending": {"confirmed", "cancelled"},
        "confirmed": {"shipped", "cancelled"},
        "shipped": {"delivered"},
        "delivered": set(),
        "cancelled": set(),
    }
    next_status = payload.status
    if next_status not in allowed.get(order.status, set()):
        raise HTTPException(
            status_code=409,
            detail=f"Invalid order status transition: {order.status} -> {next_status}",
        )
    previous_status = order.status
    if next_status == "cancelled":
        product_ids = sorted(item.product_id for item in order.items)
        products = list(
            db.scalars(
                select(Product).where(Product.id.in_(product_ids)).order_by(Product.id).with_for_update()
            ).all()
        )
        by_id = {product.id: product for product in products}
        for item in order.items:
            product = by_id.get(item.product_id)
            if product is not None:
                product.stock += item.quantity
    order.status = next_status
    _audit(
        db,
        actor,
        "order.status_changed",
        "order",
        order.id,
        {"from": previous_status, "to": next_status},
    )
    db.commit()
    db.refresh(order)
    return order


@app.get("/api/v1/admin/audit-events", response_model=list[AuditEventOut], tags=["admin"])
def list_audit_events(
    _actor: str = Depends(require_admin),
    entity_type: str | None = Query(default=None, max_length=40),
    entity_id: str | None = Query(default=None, max_length=80),
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_session),
) -> list[AuditEvent]:
    statement = select(AuditEvent)
    if entity_type:
        statement = statement.where(AuditEvent.entity_type == entity_type)
    if entity_id:
        statement = statement.where(AuditEvent.entity_id == entity_id)
    statement = statement.order_by(AuditEvent.id.desc()).limit(limit)
    return list(db.scalars(statement).all())
