# Horilla HR (HRMS) — Railway wrapper image.
#
# Built from upstream source at a pinned commit rather than a moving tag, and
# adapted for Railway: media on the volume, the setup wizard's unauthenticated
# superuser routes blocked, an admin account seeded before the port opens, and
# a real WSGI server bound to $PORT.
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

ARG HORILLA_REF=d3443753e46f65a0b6793db4291b19ab141cf74b

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git build-essential libpq-dev libjpeg-dev zlib1g-dev libcairo2-dev \
        libpango1.0-dev libgdk-pixbuf-xlib-2.0-dev libxml2-dev libxslt1-dev \
        libffi-dev pkg-config gcc g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git init . \
    && git remote add origin https://github.com/horilla-opensource/horilla.git \
    && git fetch --depth 1 origin "${HORILLA_REF}" \
    && git checkout FETCH_HEAD \
    && rm -rf .git

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip \
    && pip install --no-cache-dir -r /src/requirements.txt gunicorn psycopg2-binary

FROM python:3.12-slim AS production

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    DJANGO_SETTINGS_MODULE=horilla.settings

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpq5 libjpeg62-turbo zlib1g libcairo2 libpango-1.0-0 \
        libgdk-pixbuf-xlib-2.0-0 libxml2 libxslt1.1 libffi8 curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /src /app

# Railway-specific overrides. local_settings.py is the last module the settings
# package imports, so these win over base.py and addons.py.
COPY railway_guard.py /app/railway_guard.py
COPY railway_seed.py /app/railway_seed.py
COPY local_settings.py /app/horilla/settings/local_settings.py
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# Fail the build rather than ship an image whose guard is not wired in.
RUN grep -q "railway_guard.BlockSetupRoutesMiddleware" /app/horilla/settings/local_settings.py \
    && python -c "import ast,sys; ast.parse(open('/app/base/views.py').read())" \
    && grep -q "def initialize_database_user" /app/base/views.py

RUN mkdir -p /app/media /app/staticfiles

EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
