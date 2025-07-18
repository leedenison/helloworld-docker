#!/bin/bash

# Main startup script for Service container
# Starts PostgreSQL first, then Service application

set -e

SCRIPT_DIR="/opt/service/scripts"
POSTGRES_SCRIPT="$SCRIPT_DIR/postgres.sh"
SERVICE_SCRIPT="$SCRIPT_DIR/service.sh"

# Function to check if a script exists and is executable
check_script() {
    local script="$1"
    local name="$2"
    
    if [ ! -f "$script" ]; then
        echo "Error: $name script not found at $script"
        exit 1
    fi
    
    if [ ! -x "$script" ]; then
        echo "Error: $name script is not executable"
        exit 1
    fi
}

# Function to start all services
start_services() {
    echo "=== Starting Service Services ==="
    
    # Check scripts exist
    check_script "$POSTGRES_SCRIPT" "PostgreSQL"
    check_script "$SERVICE_SCRIPT" "Service"
    
    # Start PostgreSQL first
    "$POSTGRES_SCRIPT" start
    
    # Wait a moment for PostgreSQL to fully initialize
    sleep 2
    
    # Check PostgreSQL is running
    if ! "$POSTGRES_SCRIPT" status >/dev/null 2>&1; then
        echo "Error: PostgreSQL failed to start"
        exit 1
    fi
    
    echo "PostgreSQL is ready"
    
    # Start Service application
    "$SERVICE_SCRIPT" start
}

# Function to stop all services
stop_services() {
    echo "=== Stopping Service Services ==="
    
    # Stop Service first (if running)
    if [ -f "$SERVICE_SCRIPT" ]; then
        "$SERVICE_SCRIPT" stop || true
    fi
    
    # Stop PostgreSQL
    if [ -f "$POSTGRES_SCRIPT" ]; then
        "$POSTGRES_SCRIPT" stop || true
    fi
}

# Function to check status of all services
status_services() {
    echo "=== Service Services Status ==="
    
    echo "PostgreSQL:"
    if [ -f "$POSTGRES_SCRIPT" ]; then
        "$POSTGRES_SCRIPT" status || echo "  Not running"
    else
        echo "  Script not found"
    fi
    
    echo "Service:"
    if [ -f "$SERVICE_SCRIPT" ]; then
        "$SERVICE_SCRIPT" status || echo "  Not running"
    else
        echo "  Script not found"
    fi
}

# Main script logic
case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    status)
        status_services
        ;;
    restart)
        stop_services
        sleep 2
        start_services
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        echo ""
        echo "This script manages both PostgreSQL and Service services."
        echo "Services are started in the correct order: PostgreSQL first, then Service."
        exit 1
        ;;
esac 