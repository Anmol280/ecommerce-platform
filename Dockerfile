# Pin the multi-platform Python image index and apply Debian security updates.
FROM python:3.12-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app
COPY pyproject.toml ./
COPY app ./app
COPY migrations ./migrations
COPY alembic.ini ./
COPY scripts ./scripts

RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && python -m pip install --no-cache-dir --upgrade "pip==26.3" "setuptools==84.2.1" \
    && pip install --no-cache-dir . \
    && python -m pip uninstall -y setuptools \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app app \
    && chmod 0555 /app/scripts/entrypoint.sh \
    && chown -R app:app /app

USER app:app
EXPOSE 8000
ENTRYPOINT ["/app/scripts/entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]

# Optional local quality target. It is not included in the default runtime image.
FROM runtime AS test
USER root
RUN pip install --no-cache-dir ".[dev]"
RUN pip install --no-cache-dir "pip-audit==2.10.1"
COPY tests ./tests
USER app:app
RUN ruff check app tests migrations \
    && ruff format --check app tests migrations \
    && pytest \
    && pip-audit . \
    && pip-audit --local --skip-editable

# Keep the production image as the default Docker build target.
FROM runtime AS final
