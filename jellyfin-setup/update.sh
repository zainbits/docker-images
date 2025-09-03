#!/bin/bash

# Jellyfin Server Update Script

echo "Updating Jellyfin server..."

# Pull the latest image
echo "Pulling latest Jellyfin image..."
docker compose pull

# Restart the container
echo "Restarting Jellyfin server..."
docker compose down
docker compose up -d

echo "Jellyfin server updated and restarted!"