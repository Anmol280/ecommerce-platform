#!/bin/sh
set -eu

# Apply checked-in, ordered schema migrations before the API starts accepting traffic.
alembic upgrade head
python -m scripts.seed_demo_data --if-empty
exec "$@"
