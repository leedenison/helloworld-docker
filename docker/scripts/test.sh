#!/bin/bash

# Test script for Service
# This script initializes a test database, runs tests, and cleans up

set -e  # Exit on any error

# Environment variables
POSTGRES_DATA_DIR="${POSTGRES_DATA_DIR:-/var/lib/postgresql/17/main}"
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-db_user}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-test_password}"
POSTGRES_DB="${POSTGRES_DB:-${SERVICE_NAME}_test}"
DATABASE_URL="${DATABASE_URL:-postgres://db_user:test_password@localhost:5432/${SERVICE_NAME}_test}"
RUST_BACKTRACE="${RUST_BACKTRACE:-0}"

# Test file filtering
# TEST_FILES: Space-separated list of test file names (without .rs extension)
# Example: TEST_FILES="auth_tests user_tests"
TEST_FILES="${TEST_FILES:-}"
TEST_FILES_ARGS=""

# Function to build test file arguments
build_test_args() {
    if [ -n "$TEST_FILES" ]; then
        echo "Running tests for specific files: $TEST_FILES"
        # Convert space-separated list to cargo test arguments
        for file in $TEST_FILES; do
            TEST_FILES_ARGS="$TEST_FILES_ARGS --test $file"
        done
    else
        echo "Running all tests"
    fi
}

# Function to initialize test database
init_test_database() {
    # Set DB_ACTION to reset for the init-db.sh script to ensure clean state
    export DB_ACTION=reset
    
    # Run the database initialization script and redirect output to log file
    if ! /opt/service/scripts/init-db.sh > /tmp/${SERVICE_NAME}/logs/test/db-setup.log 2>&1; then
        echo "✗ Database initialization failed"
        echo "Check logs at: /tmp/${SERVICE_NAME}/logs/test/db-setup.log"
        exit 1
    fi
}

# Function to run tests
run_tests() {
    # Change to the source directory
    cd /opt/service/src
    
    if psql "$DATABASE_URL" -c "SELECT version();" > /dev/null 2>&1; then
        echo "✓ Database connection successful"
    else
        echo "✗ Database connection failed"
        return 1
    fi
    
    if [ -f "/opt/service/src/Cargo.toml" ]; then
        echo "✓ Source code is mounted correctly"
    else
        echo "✗ Source code not found"
        return 1
    fi
    
    if cargo check --quiet; then
        echo "✓ Project builds successfully"
    else
        echo "✗ Project build failed"
        return 1
    fi
    
    # Build test arguments
    build_test_args
    
    if cargo test $TEST_FILES_ARGS -- --nocapture ; then
        echo "All cargo tests passed ✓"
    else
        echo "cargo tests failed ✗"
        return 1
    fi
    
    echo "All tests passed! ✓"
}

# Function to clean up test database
cleanup_test_database() {
    # Set DB_ACTION to delete for the init-db.sh script
    export DB_ACTION=delete
    
    # Run the database cleanup script and redirect output to log file
    if ! /opt/service/scripts/init-db.sh > /tmp/${SERVICE_NAME}/logs/test/db-teardown.log 2>&1; then
        echo "✗ Database cleanup failed"
        echo "Check logs at: /tmp/${SERVICE_NAME}/logs/test/db-teardown.log"
        exit 1
    fi
}

# Main test workflow
main() {
    # Initialize the test database
    init_test_database
    
    # Run the tests
    if run_tests; then
        exit_code=0
    else
        exit_code=1
    fi
    
    # Clean up the test database
    cleanup_test_database
    
    exit $exit_code
}

# Run main function
main "$@" 