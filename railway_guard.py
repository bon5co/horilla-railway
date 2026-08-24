"""Railway hardening middleware for Horilla.

Horilla's first-run setup wizard exposes ``/initialize-database-user/``, which
creates a superuser and logs the caller in. Upstream guards the wizard's entry
view with ``if not settings.DEBUG: raise Http404`` but leaves the user-creation
step reachable by any anonymous caller carrying an ``HX-Request`` header, and
the demo-data loader is likewise unauthenticated. On a public URL that is an
instance takeover, so the routes are refused here before they reach a view.
"""

from django.http import HttpResponseNotFound

BLOCKED_PREFIXES = (
    "initialize-database",
    "initialize-db",
    "load-demo-database",
)


class BlockSetupRoutesMiddleware:
    """Return 404 for the unauthenticated first-run setup routes."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path = request.path.lstrip("/")
        if path.startswith(BLOCKED_PREFIXES):
            return HttpResponseNotFound(
                "Setup routes are disabled on this deployment."
            )
        return self.get_response(request)
