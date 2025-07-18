# Service Docker Build System

# Load environment variables from .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

SERVICE_NAME ?= helloworld
export SERVICE_NAME

BUILD_DIR = docker/bin
POSTGRES_DATA_DIR = /tmp/$(SERVICE_NAME)/data
POSTGRES_LOGS_DIR = /tmp/$(SERVICE_NAME)/logs/postgresql
RUST_BACKTRACE ?= 0
GIT_SUBMODULE_FLAGS ?=

all: prod

help:
	@echo "Main Targets:"
	@echo "  all          - Build production and dev images (default)"
	@echo "  prod         - Build production Docker image"
	@echo "  dev          - Build development Docker image"
	@echo "  service      - Build $(SERVICE_NAME) binary only"
	@echo ""
	@echo "Database Management:"
	@echo "  init-db      - Initialize dev database"
	@echo "  delete-db    - Delete dev database"
	@echo "  reset-db     - Reset dev database (delete-db then init-db)"
	@echo ""
	@echo "Testing:"
	@echo "  test         - Run all tests"
	@echo "  func-test    - Run functional tests (runs in a dedicated container)"
	@echo ""
	@echo "Development:"
	@echo "  run          - Start dev environment with hot reloading"
	@echo "  logs         - View dev container logs"
	@echo "  logs-watch   - Watch dev container logs in real-time"
	@echo "  stop         - Stop dev containers"
	@echo ""
	@echo "Cleaning:"
	@echo "  clean        - Clean build artifacts"
	@echo "  clean-containers - Clean Docker containers"
	@echo "  clean-images - Clean Docker images"
	@echo "  clean-all    - Clean everything"
	@echo ""
	@echo "Information:"
	@echo "  status       - Show build status"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make dev     - Build development image"
	@echo "  make init-db - Initialize database"
	@echo "  make run     - Start development environment"
	@echo "  make logs-watch - Watch container logs"
	@echo "  make stop - Stop all containers"
	@echo "  make clean-all - Clean everything"
	
# Ensure PostgreSQL data directory exists
$(POSTGRES_DATA_DIR):
	@echo "Creating PostgreSQL data directory: $(POSTGRES_DATA_DIR)"
	@mkdir -p $(POSTGRES_DATA_DIR)

# Ensure PostgreSQL logs directory exists
$(POSTGRES_LOGS_DIR):
	@echo "Creating PostgreSQL logs directory: $(POSTGRES_LOGS_DIR)"
	@mkdir -p $(POSTGRES_LOGS_DIR)

# Initialize and update git submodule
external/$(SERVICE_NAME)/Cargo.toml:
	@echo "Initializing and updating Service submodule..."
	git $(GIT_SUBMODULE_FLAGS) submodule update --init --recursive

$(BUILD_DIR)/$(SERVICE_NAME): external/$(SERVICE_NAME)/Cargo.toml
	@echo "Building $(SERVICE_NAME) binary..."
	@mkdir -p $(BUILD_DIR)
	(cd external/$(SERVICE_NAME) && cargo build --release) && cp external/$(SERVICE_NAME)/target/release/$(SERVICE_NAME) $(BUILD_DIR)/$(SERVICE_NAME)

service: $(BUILD_DIR)/$(SERVICE_NAME)

# Build development Docker image
dev:
	@echo "Building development Docker image..."
	cd docker && docker build --target dev -t service:dev .

# Build production Docker image
prod: $(BUILD_DIR)/$(SERVICE_NAME)
	@echo "Building production Docker image..."
	cd docker && docker build --target prod -t service:prod .

# Initialize database (first run)
init-db: $(POSTGRES_DATA_DIR)
	cd docker && docker-compose --profile init up service-init

# Delete database data (clean slate)
delete-db: $(POSTGRES_DATA_DIR)
	cd docker && DB_ACTION=delete docker-compose --profile init up service-init

# Reset database (delete and rebuild from scratch)
reset-db: $(POSTGRES_DATA_DIR)
	cd docker && DB_ACTION=reset docker-compose --profile init up service-init

# Run functional tests
func-test:
	@echo "Running Service functional tests..."
	@cd docker && RUST_BACKTRACE=$(RUST_BACKTRACE) TEST_FILES="database" docker-compose --profile test up service-test

# Run tests (alias for func-test)
test: func-test

# Run development environment
run: docker $(POSTGRES_DATA_DIR) $(POSTGRES_LOGS_DIR)
	@echo "Starting development environment with cargo-watch..."
	cd docker && docker-compose up -d
	@echo "Development container started with hot reloading enabled."
	@echo "Source code changes will automatically trigger rebuilds and restarts."
	@echo "Run 'make logs' to view the container logs."

logs:
	cd docker && docker-compose logs --tail=20

logs-watch:
	cd docker && docker-compose logs -f

stop:
	@echo "Stopping containers..."
	cd docker && docker-compose down

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)

clean-containers:
	@echo "Cleaning Docker containers..."
	cd docker && docker-compose down --volumes --remove-orphans
	docker rm -f service-init 2>/dev/null || true
	docker rm -f service-dev 2>/dev/null || true
	docker rm -f service-test 2>/dev/null || true

clean-images:
	@echo "Cleaning Docker images..."
	cd docker && docker-compose down --rmi local
	docker rmi service:dev service:prod 2>/dev/null || true
	docker rmi docker-service-init:latest 2>/dev/null || true
	docker rmi docker-service-test:latest 2>/dev/null || true

clean-submodules:
	@echo "Cleaning submodule build artifacts..."
	cd external/$(SERVICE_NAME) && make clean 2>/dev/null || true

clean-all: clean clean-containers clean-images clean-submodules

status:
	@echo "=== $(SERVICE_NAME) Build Status ==="
	@echo "Production binary exists: $$([ -f $(BUILD_DIR)/$(SERVICE_NAME) ] && echo "Yes" || echo "No")"
	@echo "Submodule initialized: $$([ -d external/$(SERVICE_NAME) ] && echo "Yes" || echo "No")"
	@echo "PostgreSQL data directory exists: $$([ -d $(POSTGRES_DATA_DIR) ] && echo "Yes" || echo "No")"
	@echo "PostgreSQL logs directory exists: $$([ -d $(POSTGRES_LOGS_DIR) ] && echo "Yes" || echo "No")"
	@echo "Submodule status:"
	@git submodule status 2>/dev/null || echo "No submodules configured"
	@echo "Docker Compose services:"
	@cd docker && docker-compose ps

.PHONY: all help dev prod init-db delete-db reset-db test func-test test-files run logs logs-watch watch restart stop clean clean-containers clean-images clean-submodules clean-all status