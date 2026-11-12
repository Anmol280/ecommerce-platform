#!/bin/sh
set -eu

# Apply checked-in, ordered schema migrations before the API starts accepting traffic.
alembic upgrade head
exec "$@"
