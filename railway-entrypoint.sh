#!/bin/bash
set -euo pipefail

MEDIA_DIR="${MEDIA_ROOT:-/app/media}"
mkdir -p "$MEDIA_DIR" /app/staticfiles
chown -R root:root "$MEDIA_DIR" 2>/dev/null || true
echo "[railway] media volume owner=$(stat -c %u:%g "$MEDIA_DIR")"

# Horilla's production gate refuses ALLOWED_HOSTS=["*"], so derive the real
# hostnames from Railway when the deployer has not set them.
if [ -z "${ALLOWED_HOSTS:-}" ] || [ "${ALLOWED_HOSTS}" = "*" ]; then
  ALLOWED_HOSTS="${RAILWAY_PUBLIC_DOMAIN:-localhost},${RAILWAY_PRIVATE_DOMAIN:-localhost},healthcheck.railway.app,localhost,127.0.0.1"
  export ALLOWED_HOSTS
fi
if [ -z "${CSRF_TRUSTED_ORIGINS:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export CSRF_TRUSTED_ORIGINS="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

# Wait for the database rather than crash-looping through Railway's backoff.
python - <<'PY'
import os
import socket
import sys
import time
from urllib.parse import urlparse

url = os.environ.get("DATABASE_URL") or ""
if url:
    parsed = urlparse(url)
    host, port = parsed.hostname, parsed.port or 5432
    deadline = time.time() + 180
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=5):
                print(f"[railway] database reachable at {host}:{port}")
                sys.exit(0)
        except OSError as exc:
            print(f"[railway] waiting for database at {host}:{port} ({exc})")
            time.sleep(3)
    sys.exit(f"FATAL: database at {host}:{port} unreachable after 180s")
PY

python manage.py migrate --noinput
python manage.py collectstatic --noinput --clear >/dev/null

# Seed the administrator BEFORE any process binds the public port, so the URL
# is never live against an instance with no account.
python /app/railway_seed.py

PORT="${PORT:-8000}"
# Exactly one worker: Horilla starts APScheduler jobs in-process, and a second
# worker runs every scheduled job twice.
exec gunicorn horilla.wsgi:application \
  --bind "0.0.0.0:${PORT}" \
  --workers 1 \
  --worker-class gthread \
  --threads "${GUNICORN_THREADS:-8}" \
  --timeout 120 \
  --access-logfile - \
  --error-logfile -
