"""Insert repeatable demo products without overwriting operator data."""

import argparse

from sqlalchemy import func, select

from app.database import SessionLocal
from app.models import Product


DEMO_PRODUCTS = [
    {
        "sku": "ALG-HEADPHONES-01",
        "name": "Studio Wireless Headphones",
        "description": "Over-ear wireless headphones with a fold-flat travel design.",
        "category": "Electronics",
        "price": "2499.00",
        "currency": "INR",
        "stock": 18,
        "active": True,
    },
    {
        "sku": "ALG-MUG-01",
        "name": "Insulated Steel Bottle",
        "description": "A reusable bottle for commuting and day trips.",
        "category": "Accessories",
        "price": "799.00",
        "currency": "INR",
        "stock": 30,
        "active": True,
    },
    {
        "sku": "ALG-LAMP-01",
        "name": "Desk Lamp Mini",
        "description": "Compact adjustable lamp with a weighted base.",
        "category": "Home",
        "price": "1199.00",
        "currency": "INR",
        "stock": 12,
        "active": True,
    },
]


def main(*, only_if_empty: bool = False) -> None:
    added = 0
    with SessionLocal() as db:
        if only_if_empty and db.scalar(select(func.count()).select_from(Product)):
            print("Demo catalog seed skipped; products already exist.")
            return
        for item in DEMO_PRODUCTS:
            existing = db.scalar(select(Product).where(Product.sku == item["sku"]))
            if existing is None:
                db.add(Product(**item))
                added += 1
        db.commit()
    print(f"Demo catalog ready; added {added} new product(s).")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--if-empty",
        action="store_true",
        help="seed the demo catalog only when the product table is empty",
    )
    main(only_if_empty=parser.parse_args().if_empty)
