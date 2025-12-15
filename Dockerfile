ARG BASE_TAG=17-3.5
FROM ghcr.io/cloudnative-pg/postgis:${BASE_TAG}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root

ARG PGVECTOR_VERSION=0.8.1

# Install pgvector extension from source
RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && mkdir -p /var/lib/apt/lists/partial \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        libpq-dev \
        postgresql-server-dev-all \
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
        libpq-dev \
        postgresql-server-dev-all \
    && rm -rf /var/lib/apt/lists/*

USER postgres
