ARG BASE_TAG=17-3.5
FROM ghcr.io/cloudnative-pg/postgis:${BASE_TAG}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root

ARG PGVECTOR_VERSION=0.8.1

# Install pgvector extension from source
RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && PG_MAJOR="$(pg_config --version | awk '{print $2}' | cut -d. -f1)" \
    && CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")" \
    && mkdir -p /var/lib/apt/lists/partial \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ ${CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        "postgresql-server-dev-${PG_MAJOR}" \
        "postgresql-${PG_MAJOR}-pgvector" \
        "postgresql-${PG_MAJOR}-vchord" \
    && curl -sSL "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" \
        | tar -xz -C /tmp \
    && cd /tmp/pgvector-${PGVECTOR_VERSION} \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/pgvector-${PGVECTOR_VERSION} \
    && apt-get purge -y --auto-remove \
        build-essential \
        curl \
        gnupg \
        libpq-dev \
        "postgresql-server-dev-${PG_MAJOR}" \
    && rm -rf /var/lib/apt/lists/*

USER postgres
