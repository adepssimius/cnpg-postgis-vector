ARG BASE_TAG=17-3.5

FROM ghcr.io/cloudnative-pg/postgis:${BASE_TAG} AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root

ARG PGVECTOR_VERSION=0.8.1
ARG VCHORD_VERSION=1.0.0

# Build pgvector from source and install VectorChord from release artifacts
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
        build-essential \
        libpq-dev \
        "postgresql-server-dev-${PG_MAJOR}" \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ ${CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && apt-get update \
    # pgvector from source
    && curl -sSL "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" \
        | tar -xz -C /tmp \
    && cd /tmp/pgvector-${PGVECTOR_VERSION} \
    && make \
    && make install \
    && cd / \
    # VectorChord prebuilt extension (latest release)
    && ARCH="" \
    && case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
        amd64) ARCH=amd64 ;; \
        arm64) ARCH=arm64 ;; \
        aarch64) ARCH=arm64 ;; \
        *) echo "Unsupported arch ${TARGETARCH:-$(dpkg --print-architecture)}" >&2; exit 1 ;; \
    esac \
    && VCHORD_DEB="postgresql-${PG_MAJOR}-vchord_${VCHORD_VERSION}-1_${ARCH}.deb" \
    && curl -fsSL -o "/tmp/${VCHORD_DEB}" "https://github.com/tensorchord/VectorChord/releases/download/${VCHORD_VERSION}/${VCHORD_DEB}" \
    && dpkg -i "/tmp/${VCHORD_DEB}" \
    # Cleanup build deps and caches
    && rm -f "/tmp/${VCHORD_DEB}" \
    && rm -rf /tmp/pgvector-${PGVECTOR_VERSION} \
    && apt-get purge -y --auto-remove \
        build-essential \
        curl \
        gnupg \
        libpq-dev \
        "postgresql-server-dev-${PG_MAJOR}" \
    && rm -rf /var/lib/apt/lists/*

FROM ghcr.io/cloudnative-pg/postgis:${BASE_TAG}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root

ARG PGVECTOR_VERSION=0.8.1
ARG VCHORD_VERSION=1.0.0

# Copy compiled extensions from builder
RUN set -eux \
    && PG_MAJOR="$(pg_config --version | awk '{print $2}' | cut -d. -f1)" \
    && mkdir -p /usr/lib/postgresql/${PG_MAJOR}/lib \
    && mkdir -p /usr/share/postgresql/${PG_MAJOR}/extension \
    && mkdir -p /usr/include/postgresql/${PG_MAJOR}/server/extension

COPY --from=builder /usr/lib/postgresql/ /usr/lib/postgresql/
COPY --from=builder /usr/share/postgresql/ /usr/share/postgresql/
COPY --from=builder /usr/include/postgresql/ /usr/include/postgresql/

USER postgres
