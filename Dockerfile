# Build dependencies in a slim Python image. The runtime user is unprivileged.
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app
COPY pyproject.toml ./
COPY app ./app
COPY migrations ./migrations
COPY alembic.ini ./
COPY scripts ./scripts

RUN pip install --no-cache-dir . \
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
    && pip-audit .

# Keep the production image as the default Docker build target.
FROM runtime AS final
