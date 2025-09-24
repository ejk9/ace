#!/bin/bash

# Start Screenshot Service Script
# This script starts the Node.js screenshot service in the background

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCREENSHOT_SERVICE_DIR="$PROJECT_DIR/screenshot_service"
PID_FILE="$PROJECT_DIR/tmp/screenshot_service.pid"
LOG_FILE="$PROJECT_DIR/tmp/screenshot_service.log"

# Create tmp directory if it doesn't exist
mkdir -p "$PROJECT_DIR/tmp"

# Function to check if service is already running
is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Function to start the service
start_service() {
    echo "Starting screenshot service..."
    
    # Change to screenshot service directory
    cd "$SCREENSHOT_SERVICE_DIR"
    
    # Install dependencies if node_modules doesn't exist
    if [ ! -d "node_modules" ]; then
        echo "Installing screenshot service dependencies..."
        npm install
    fi
    
    # Start the service in background
    nohup node server.js > "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # Save PID
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment and check if it started successfully
    sleep 2
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "Screenshot service started successfully (PID: $pid)"
        echo "Logs available at: $LOG_FILE"
        return 0
    else
        echo "Failed to start screenshot service"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Function to stop the service
stop_service() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo "Stopping screenshot service (PID: $pid)..."
        kill "$pid"
        rm -f "$PID_FILE"
        echo "Screenshot service stopped"
    else
        echo "Screenshot service is not running"
    fi
}

# Function to show status
show_status() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo "Screenshot service is running (PID: $pid)"
        echo "Logs: $LOG_FILE"
    else
        echo "Screenshot service is not running"
    fi
}

# Main script logic
case "${1:-start}" in
    start)
        if is_running; then
            echo "Screenshot service is already running"
            show_status
        else
            start_service
        fi
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 1
        start_service
        ;;
    status)
        show_status
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            echo "No log file found at $LOG_FILE"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo "  start   - Start the screenshot service (default)"
        echo "  stop    - Stop the screenshot service"
        echo "  restart - Restart the screenshot service"
        echo "  status  - Show service status"
        echo "  logs    - Follow service logs"
        exit 1
        ;;
esac