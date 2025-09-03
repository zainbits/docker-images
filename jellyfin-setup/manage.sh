#!/bin/bash

# Jellyfin Server Management Script

case "$1" in
    start)
        echo "Starting Jellyfin server..."
        docker compose up -d
        ;;
    stop)
        echo "Stopping Jellyfin server..."
        docker compose down
        ;;
    restart)
        echo "Restarting Jellyfin server..."
        docker compose down
        docker compose up -d
        ;;
    status)
        echo "Jellyfin server status:"
        docker compose ps
        ;;
    logs)
        echo "Jellyfin server logs:"
        docker compose logs -f
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the Jellyfin server"
        echo "  stop    - Stop the Jellyfin server"
        echo "  restart - Restart the Jellyfin server"
        echo " status  - Show the status of the Jellyfin server"
        echo "  logs    - Show and follow the Jellyfin server logs"
        ;;
esac