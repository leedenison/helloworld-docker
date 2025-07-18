#!/bin/bash

# PostgreSQL service script for Service
# Usage: postgres.sh {start|stop|status|restart}

POSTGRES_DATA_DIR="${POSTGRES_DATA_DIR:-/var/lib/postgresql/17/main}"
POSTGRES_LOG_DIR="/var/log/postgresql"
POSTGRES_CLUSTER="17 main"

# Function to start PostgreSQL
start_postgres() {
    echo "Starting PostgreSQL..."
    
    # Create log directory if it doesn't exist
    mkdir -p "$POSTGRES_LOG_DIR"
    
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
    
    echo "PostgreSQL started successfully"
}

# Function to stop PostgreSQL
stop_postgres() {
    echo "Stopping PostgreSQL..."
    su postgres -c "/usr/lib/postgresql/17/bin/pg_ctl -D $POSTGRES_DATA_DIR stop" || true
    echo "PostgreSQL stopped"
}

# Function to check PostgreSQL status
status_postgres() {
    if pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
        echo "PostgreSQL is running"
        return 0
    else
        echo "PostgreSQL is not running"
        return 1
    fi
}

# Function to restart PostgreSQL
restart_postgres() {
    stop_postgres
    sleep 2
    start_postgres
}

# Main script logic
case "$1" in
    start)
        start_postgres
        ;;
    stop)
        stop_postgres
        ;;
    status)
        status_postgres
        ;;
    restart)
        restart_postgres
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac 