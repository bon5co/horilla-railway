"""Railway overrides. Imported last by horilla.settings, so these win."""

import os

from .base import MIDDLEWARE

# Railway mounts one volume; keep every uploaded file under it. base.py points
# MEDIA_ROOT at BASE_DIR/media, which is on the disposable container layer.
MEDIA_ROOT = os.environ.get("MEDIA_ROOT", "/app/media")

if "railway_guard.BlockSetupRoutesMiddleware" not in MIDDLEWARE:
    MIDDLEWARE.insert(0, "railway_guard.BlockSetupRoutesMiddleware")
