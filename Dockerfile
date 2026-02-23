# ──────────────────────────────────────────────────────────────
#  Dockerfile — Flask App (Secure CRUD)
#
#  Security best practices:
#   ✔  Python 3.11-slim (Debian slim — small attack surface)
#   ✔  Non-root user (appuser)
#   ✔  Layer caching: dependencies installed before app code
#   ✔  No dev tools in final image
# ──────────────────────────────────────────────────────────────

FROM python:3.11-slim

# ── OS dependencies (curl for health checks only) ────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# ── Create non-root group & user ─────────────────────────────
RUN groupadd --system appgroup \
    && useradd  --system --gid appgroup --no-create-home appuser

# ── Working directory ─────────────────────────────────────────
WORKDIR /app

# ── Install Python dependencies (cached layer) ────────────────
COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Copy application source ───────────────────────────────────
COPY src/ .

# ── Set ownership to non-root user ────────────────────────────
RUN chown -R appuser:appgroup /app

# ── Switch to non-root user ───────────────────────────────────
USER appuser

# ── Expose internal port ──────────────────────────────────────
EXPOSE 5000

# ── Health check (Docker native) ─────────────────────────────
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=5 \
    CMD curl -f http://localhost:5000/health || exit 1

# ── Start Gunicorn (production WSGI server) ───────────────────
CMD ["gunicorn", \
     "--bind", "0.0.0.0:5000", \
     "--workers", "2", \
     "--timeout", "60", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:app"]
