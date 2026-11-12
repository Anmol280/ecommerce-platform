"""Request and response contracts for the public API."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
import re
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator


class ProductCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    sku: str = Field(min_length=1, max_length=64, pattern=r"^[A-Za-z0-9._-]+$")
    name: str = Field(min_length=1, max_length=160)
    description: str = Field(default="", max_length=4000)
    category: str | None = Field(default=None, max_length=80)
    price: Decimal = Field(gt=0, max_digits=10, decimal_places=2)
    currency: str = Field(default="INR", min_length=3, max_length=3)
    stock: int = Field(default=0, ge=0)
    active: bool = True

    @field_validator("currency")
    @classmethod
    def uppercase_currency(cls, value: str) -> str:
        normalized = value.upper()
        if not re.fullmatch(r"[A-Z]{3}", normalized):
            raise ValueError("Currency must be a three-letter code")
        return normalized


class ProductUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=4000)
    category: str | None = Field(default=None, max_length=80)
    price: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)
    stock: int | None = Field(default=None, ge=0)
    active: bool | None = None

    @model_validator(mode="after")
    def has_update(self):
        if not self.model_fields_set:
            raise ValueError("At least one field must be supplied")
        for field in ("name", "description", "price", "stock", "active"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"{field} cannot be null")
        return self


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    sku: str
    name: str
    description: str
    category: str | None
    price: Decimal
    currency: str
    stock: int
    active: bool
    created_at: datetime
    updated_at: datetime


class OrderLineIn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    product_id: int = Field(gt=0)
    quantity: int = Field(gt=0, le=1000)


class OrderCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    customer_email: EmailStr
    items: list[OrderLineIn] = Field(min_length=1, max_length=50)


class OrderItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    product_id: int
    sku_snapshot: str
    name_snapshot: str
    quantity: int
    unit_price: Decimal
    line_total: Decimal


class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    customer_email: EmailStr
    status: str
    currency: str
    total_amount: Decimal
    created_at: datetime
    items: list[OrderItemOut]


class OrderStatusUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: Literal["confirmed", "shipped", "delivered", "cancelled"]


class HealthOut(BaseModel):
    status: str
    service: str


class AuditEventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    actor: str
    action: str
    entity_type: str
    entity_id: str
    details: dict
    created_at: datetime
