"""Seed (and re-apply) the administrator account from the environment.

Horilla ships no non-interactive way to set or reset an administrator password:
``createhorillauser`` only creates, and the in-product reset path is an emailed
link a fresh deployment has no SMTP for. This runs on every boot, before the
web server binds a port, so a redeploy is a working password reset.
"""

import os
import sys
import uuid

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "horilla.settings")
django.setup()

from django.db import transaction  # noqa: E402

from employee.models import Employee  # noqa: E402
from horilla_auth.models import HorillaUser  # noqa: E402

USERNAME = os.environ.get("HORILLA_ADMIN_USERNAME", "").strip()
PASSWORD = os.environ.get("HORILLA_ADMIN_PASSWORD", "")
EMAIL = os.environ.get("HORILLA_ADMIN_EMAIL", "").strip()
FIRST_NAME = os.environ.get("HORILLA_ADMIN_FIRST_NAME", "Horilla").strip()
LAST_NAME = os.environ.get("HORILLA_ADMIN_LAST_NAME", "Admin").strip()

if not USERNAME or not PASSWORD:
    sys.exit(
        "FATAL: HORILLA_ADMIN_USERNAME and HORILLA_ADMIN_PASSWORD must both be set."
    )
if PASSWORD in {"admin", "admin123", "changeme", "password"}:
    sys.exit("FATAL: HORILLA_ADMIN_PASSWORD is a well-known default; refusing to boot.")

with transaction.atomic():
    user = HorillaUser.objects.filter(username=USERNAME).first()
    if user is None:
        user = HorillaUser.objects.create_superuser(
            username=USERNAME, email=EMAIL or None, password=PASSWORD
        )
        created = True
    else:
        created = False
    user.set_password(PASSWORD)
    if EMAIL:
        user.email = EMAIL
    user.is_staff = True
    user.is_superuser = True
    user.is_active = True
    user.save()

    if not Employee.objects.filter(employee_user_id=user).exists():
        employee = Employee()
        employee.employee_user_id = user
        employee.employee_first_name = FIRST_NAME
        employee.employee_last_name = LAST_NAME
        employee.email = EMAIL or f"{USERNAME}@example.com"
        employee.save()

    if not HorillaUser.objects.filter(username="Horilla Bot").exists():
        HorillaUser.objects.create_user(
            username="Horilla Bot", password=str(uuid.uuid4())
        )

    # Any other superuser is either the documented admin/admin account seeded by
    # a previous image or one created through the setup-wizard hole; leave the
    # row for auditing but make it unusable.
    stale = HorillaUser.objects.filter(is_superuser=True).exclude(pk=user.pk)
    for other in stale:
        if other.has_usable_password():
            other.set_unusable_password()
            other.is_active = False
            other.save()
            print(f"Disabled unexpected superuser: {other.username}")

print(f"Admin {'created' if created else 'password re-applied'}: {USERNAME}")
