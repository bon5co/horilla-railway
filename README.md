# horilla-railway

Railway wrapper image for [Horilla](https://github.com/horilla-opensource/horilla),
the open-source HR management system (HRMS).

Built from upstream branch `2.0` pinned at commit
`d3443753e46f65a0b6793db4291b19ab141cf74b`, published as
`ghcr.io/bon5co/horilla-railway:2.0.0`.

## What this image changes

- **The first-run setup routes are blocked.** `POST /initialize-database-user/`
  creates a superuser and logs the caller in, and upstream gates the wizard's
  entry view on `DEBUG` but not that step, so any anonymous caller sending an
  `HX-Request` header can claim a public instance. `railway_guard.py` refuses
  `initialize-database*` and `load-demo-database*` before they reach a view.
- **The administrator is seeded from the environment before the port opens**,
  from `HORILLA_ADMIN_USERNAME` / `HORILLA_ADMIN_PASSWORD` /
  `HORILLA_ADMIN_EMAIL`. The container refuses to boot without them, or with a
  well-known default password, and re-applies the password on every boot — so a
  redeploy is a working password reset, which Horilla otherwise has no
  non-interactive path for. Any other superuser row is deactivated.
- **`MEDIA_ROOT` is `/app/media`**, the volume mount path, so uploaded documents
  and avatars survive a redeploy.
- **Gunicorn with exactly one worker** and threads. Horilla starts APScheduler
  jobs in-process; a second worker runs every scheduled job twice.
- **`$PORT` is honoured**, which is also what makes Railway's healthcheck pass.

## Environment

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Postgres connection string |
| `SECRET_KEY` | Django secret key (must not be a `django-insecure-` default) |
| `DB_INIT_PASSWORD` | required by Horilla's production gate |
| `DEBUG` | `False` |
| `HORILLA_ENV` | `production` |
| `ALLOWED_HOSTS` | derived from `RAILWAY_PUBLIC_DOMAIN` when unset; never `*` |
| `CSRF_TRUSTED_ORIGINS` | derived from `RAILWAY_PUBLIC_DOMAIN` when unset |
| `HORILLA_ADMIN_USERNAME` / `HORILLA_ADMIN_PASSWORD` / `HORILLA_ADMIN_EMAIL` | seeded administrator |
| `GUNICORN_THREADS` | worker threads, default 8 |
