# ---------- Stage 1: Build dependencies ----------
FROM python:3.11-slim AS builder

WORKDIR /build

COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ---------- Stage 2: Final runtime image ----------
FROM python:3.11-slim

# Create a non-root user (security best practice)
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

# Copy only the installed packages from the builder stage (keeps image small)
COPY --from=builder /root/.local /home/appuser/.local
COPY app/ .

ENV PATH=/home/appuser/.local/bin:$PATH \
    APP_VERSION=1.0.0 \
    PYTHONUNBUFFERED=1

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
