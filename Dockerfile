ARG BASE_TAG=17-3.5

FROM ghcr.io/cloudnative-pg/postgis:${BASE_TAG} AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root

ARG PGVECTOR_VERSION=0.8.1
ARG VCHORD_VERSION=1.0.0

# Build pgvector from source and VectorChord from source (packages against this base)
RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && PG_MAJOR="$(pg_config --version | awk '{print $2}' | cut -d. -f1)" \
    && CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")" \
    && mkdir -p /var/lib/apt/lists/partial \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ ${CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        pkg-config \
        libssl-dev \
        llvm \
        clang \
        "postgresql-server-dev-${PG_MAJOR}" \
    # pgvector from source
    && curl -sSL "https://github.com/pgvector/pgvector/archive/refs/tags/v${PGVECTOR_VERSION}.tar.gz" \
        | tar -xz -C /tmp \
    && cd /tmp/pgvector-${PGVECTOR_VERSION} \
    && make \
    && make install \
    && cd / \
    # VectorChord from source
    && curl -sSL "https://sh.rustup.rs" | sh -s -- -y --default-toolchain stable \
    && . "$HOME/.cargo/env" \
    && cargo install cargo-pgrx --version 0.16.1 \
    && cargo pgrx init --pg${PG_MAJOR} "/usr/lib/postgresql/${PG_MAJOR}/bin/pg_config" \
    && curl -sSL "https://github.com/tensorchord/VectorChord/archive/refs/tags/${VCHORD_VERSION}.tar.gz" \
        | tar -xz -C /tmp \
    && cd /tmp/VectorChord-${VCHORD_VERSION} \
    && . "$HOME/.cargo/env" \
    && cargo pgrx package --pg-config "/usr/lib/postgresql/${PG_MAJOR}/bin/pg_config" --features pg${PG_MAJOR} \
    && mkdir -p /tmp/vchord-out/lib /tmp/vchord-out/extension \
    && cp -R "target/release/vchord-pg${PG_MAJOR}/usr/lib/postgresql/${PG_MAJOR}/lib/." /tmp/vchord-out/lib/ \
    && cp -R "target/release/vchord-pg${PG_MAJOR}/usr/share/postgresql/${PG_MAJOR}/extension/." /tmp/vchord-out/extension/ \
    # Cleanup build deps and caches
    && rm -rf /tmp/pgvector-${PGVECTOR_VERSION} /tmp/VectorChord-${VCHORD_VERSION} \
    && apt-get purge -y --auto-remove \
        build-essential \
        curl \
        gnupg \
        libpq-dev \
        pkg-config \
        libssl-dev \
        llvm \
        clang \
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
COPY --from=builder /tmp/vchord-out/lib/ /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=builder /tmp/vchord-out/extension/ /usr/share/postgresql/${PG_MAJOR}/extension/

RUN set -eux \
    && PG_MAJOR="$(pg_config --version | awk '{print $2}' | cut -d. -f1)" \
    && for sample in /usr/share/postgresql/postgresql.conf.sample /usr/share/postgresql/${PG_MAJOR}/postgresql.conf.sample; do \
         if [[ -f "${sample}" ]]; then \
           perl -0pi -e "s/^#?shared_preload_libraries\\s*=.*$/shared_preload_libraries = 'pg_stat_statements,vchord'/m" "${sample}"; \
           grep -q "shared_preload_libraries = 'pg_stat_statements,vchord'" "${sample}" || echo "shared_preload_libraries = 'pg_stat_statements,vchord'" >> "${sample}"; \
         fi; \
       done

USER postgres
