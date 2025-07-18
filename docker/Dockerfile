# Multi-stage Dockerfile for Service
FROM rust:1.81-slim AS base

# =============================================================================
# BASE STAGE - PostgreSQL Installation
# =============================================================================

# Switch to nightly Rust
# TODO: Switch to stable when 2024 edition is available
RUN rustup install nightly && rustup default nightly

# Build arguments for user/group configuration
ARG POSTGRES_UID=1100
ARG POSTGRES_GID=1100

# Install required utilities for repository setup
RUN apt-get update && apt-get install -y lsb-release wget gpg ca-certificates

# Add PostgreSQL APT repository
RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg \
    && apt-key add /usr/share/keyrings/postgresql-archive-keyring.gpg

# Create postgres user and group with specified UID/GID
RUN groupadd -g $POSTGRES_GID postgres && \
    useradd -r -u $POSTGRES_UID -g postgres -s /bin/bash postgres

# Install PostgreSQL dependencies
RUN apt-get update && apt-get install -y \
    postgresql-17 \
    postgresql-contrib-17 \
    postgresql-common \
    postgresql-client-17 \
    wget \
    gnupg2 \
    lsb-release \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*



# Remove the default cluster and re-create it
RUN pg_dropcluster --stop 17 main && \
    pg_createcluster 17 main

WORKDIR /opt/service

RUN mkdir -p /opt/service/etc /opt/service/scripts /var/log/postgresql

# Copy service scripts and make them executable
COPY scripts/ /opt/service/scripts/
RUN chmod +x /opt/service/scripts/*.sh

# =============================================================================
# DEPS STAGE - External Dependencies and Build Tools
# =============================================================================
FROM base AS deps

# Install build dependencies for Service
RUN apt-get update && apt-get install -y \
    protobuf-compiler \
    procps \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Install cargo-watch for development hot reloading
RUN cargo install cargo-watch

# =============================================================================
# DEVELOPMENT STAGE - Development Environment with Hot Reload
# =============================================================================
FROM deps AS dev

# Create src mount directory
RUN mkdir -p /opt/service/src

# Create test logs directory
RUN mkdir -p /tmp/service/logs/test

EXPOSE 50001 5432

# Use cargo-watch.sh as the main executable for dev stage
CMD ["/opt/service/scripts/cargo-watch.sh", "start"]

# =============================================================================
# PRODUCTION STAGE - Optimized Production Environment
# =============================================================================
FROM base AS prod

# Create prod-specific directory
RUN mkdir -p /var/lib/postgresql/data

# Copy the Service binary
COPY bin/$(SERVICE_NAME) /opt/service/$(SERVICE_NAME)

# Create a non-root user
RUN useradd -r -s /bin/false $(SERVICE_NAME) && \
    chown -R $(SERVICE_NAME):$(SERVICE_NAME) /opt/service

USER $(SERVICE_NAME)

EXPOSE 50001

CMD ["/opt/service/scripts/services.sh", "start"] 