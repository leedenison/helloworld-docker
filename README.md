# Docker Development Environment

## Prerequisites

- Docker
- Docker Compose
- Make
- Git

## Quick Start

1. **First-time setup:**
   ```bash
   make init-db
   ```

2. **Run the development service:**
   ```bash
   make run
   ```

## Available Commands

### Build Commands
- `make all` - Build all Docker images
- `make dev` - Build development Docker image
- `make prod` - Build production Docker image

### Database Commands
- `make init-db` - Initialize database
- `make delete-db` - Delete database data
- `make reset-db` - Run delete-db followed by init-db

### Test Commands
- `make test` - Run all tests
- `make func-test` - Run functional tests

### Docker Commands
- `make run` - Start development container with hot reloading (requires existing database)
- `make stop` - Stop development container
- `make logs` - View logs from development container
- `make logs-watch` - View logs with continuous monitoring

### Utility Commands
- `make clean` - Clean build artifacts
- `make clean-all` - Clean all artifacts (does not delete the database)
- `make status` - Show current build status

## Ports

- **gRPC**: localhost:50001
- **PostgreSQL**: localhost:5432

## PostgreSQL User Configuration

By default, PostgreSQL runs inside the container with UID/GID 1100:1100. This configuration can be customized at build time.

To override the default UID/GID, use Docker build arguments:

## Service Name Configuration

Change the service name using the SERVICE_NAME variable in the Makefile.