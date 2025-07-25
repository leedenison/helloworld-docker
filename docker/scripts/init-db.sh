#!/bin/bash

# Database initialization script for Service
# This script initializes the database and handles reset functionality

set -e  # Exit on any error

# Environment variables from docker-compose.yml
POSTGRES_DATA_DIR="${POSTGRES_DATA_DIR:-/var/lib/postgresql/17/main}"
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-db_user}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-dev_password}"
POSTGRES_DB="${POSTGRES_DB:-${SERVICE_NAME}}"
DB_ACTION="${DB_ACTION:-init}"

# Database connection string
DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"

echo "=== Service Database Initialization ==="
echo "Data directory: $POSTGRES_DATA_DIR"
echo "Database: $POSTGRES_DB"
echo "User: $POSTGRES_USER"
echo "Host: $POSTGRES_HOST:$POSTGRES_PORT"
echo "DB Action: $DB_ACTION"
echo "=========================================="

# Function to check if database is initialized
is_database_initialized() {
    if [ -d "$POSTGRES_DATA_DIR" ] && [ "$(ls -A "$POSTGRES_DATA_DIR" 2>/dev/null)" ]; then
        echo "Database directory exists and contains data"
        return 0
    else
        echo "Database directory is empty or does not exist"
        return 1
    fi
}

# Function to initialize database
init_database() {
    echo "Initializing PostgreSQL cluster in $POSTGRES_DATA_DIR..."
    
    # Create data directory if it doesn't exist
    mkdir -p "$POSTGRES_DATA_DIR"
    chown postgres:postgres "$POSTGRES_DATA_DIR"
    
    # Check if cluster already exists in the data directory
    if [ -f "$POSTGRES_DATA_DIR/PG_VERSION" ]; then
        echo "PostgreSQL cluster already exists in $POSTGRES_DATA_DIR"
        # Start the cluster using the custom data directory
        su postgres -c "/usr/lib/postgresql/17/bin/pg_ctl -D $POSTGRES_DATA_DIR start" || {
            echo "Starting existing PostgreSQL cluster..."
        }
    else
        echo "Creating new PostgreSQL cluster in $POSTGRES_DATA_DIR"
        # Initialize new cluster in the mounted volume
        su postgres -c "/usr/lib/postgresql/17/bin/initdb -D $POSTGRES_DATA_DIR --encoding=UTF8 --locale=C"
        
        # Start the cluster
        su postgres -c "/usr/lib/postgresql/17/bin/pg_ctl -D $POSTGRES_DATA_DIR start"
    fi
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL to be ready..."
    until pg_isready -h localhost -p 5432; do
        echo "Waiting for PostgreSQL..."
        sleep 1
    done
    
    echo "PostgreSQL is ready"
}

# Function to delete database data
delete_database() {
    echo "Deleting database data..."
    
    # Remove data directory
    if [ -d "$POSTGRES_DATA_DIR" ]; then
        echo "Removing existing data directory..."
        rm -rf "$POSTGRES_DATA_DIR"/*
    fi
    
    echo "Database data deleted successfully"
}

# Function to configure the database (create user/db)
configure_database() {
    create_database_and_user
}

# Function to create database and user
create_database_and_user() {
    echo "Creating database and user..."
    
    # Set up postgres superuser password if not already set
    if [ -z "$POSTGRES_SUPERUSER_PASSWORD" ]; then
        export POSTGRES_SUPERUSER_PASSWORD="postgres_superuser_password"
        echo "Setting postgres superuser password..."
        su postgres -c "psql -c \"ALTER USER postgres PASSWORD '$POSTGRES_SUPERUSER_PASSWORD';\""
    fi
    
    # Create user if it doesn't exist
    su postgres -c "psql -c \"SELECT 1 FROM pg_roles WHERE rolname='$POSTGRES_USER';\"" | grep -q 1 || {
        echo "Creating user $POSTGRES_USER..."
        su postgres -c "psql -c \"CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';\""
    }
    
    # Create database if it doesn't exist
    su postgres -c "psql -lqt" | cut -d \| -f 1 | grep -qw "$POSTGRES_DB" || {
        echo "Creating database $POSTGRES_DB..."
        su postgres -c "psql -c \"CREATE DATABASE $POSTGRES_DB OWNER $POSTGRES_USER;\""
    }
    
    # Grant privileges
    su postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;\""
    su postgres -c "psql -c \"GRANT ALL ON SCHEMA public TO $POSTGRES_USER;\""
}



# Function to run all SQL migrations in the migrations directory
run_migrations() {
    echo "Applying SQL migrations..."
    MIGRATIONS_DIR="/opt/service/src/migrations"
    if [ -d "$MIGRATIONS_DIR" ]; then
        for migration in $(ls "$MIGRATIONS_DIR"/*.sql | sort); do
            echo "Applying migration: $migration"
            psql "$DATABASE_URL" -f "$migration"
        done
    else
        echo "Migrations directory not found: $MIGRATIONS_DIR"
        echo "Expected migrations in: /opt/service/src/migrations/"
        echo "Available migrations in: /opt/service/src/"
        ls -la /opt/service/src/ 2>/dev/null || echo "Source directory not accessible"
    fi
    echo "All migrations applied."
}

# Main initialization logic
main() {
    # Handle different DB_ACTION values
    case "$DB_ACTION" in
        "delete")
            delete_database
            ;;
        "reset")
            delete_database
            init_database
            configure_database
            run_migrations
            ;;
        "init")
            # Check if database is already initialized
            if is_database_initialized; then
                echo "Database appears to be already initialized"
            else
                init_database
                configure_database
                run_migrations
            fi
            ;;
        *)
            echo "Error: Invalid DB_ACTION value '$DB_ACTION'. Valid values are: init, delete, reset"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
