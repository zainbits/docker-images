# Jellyfin Server Setup

This setup uses Docker Compose to run a Jellyfin media server with your existing configuration.

## Prerequisites

- Docker and Docker Compose installed
- Existing Jellyfin data in `/mnt/hdd/JellyFinDir`

## Directory Structure

The setup expects the following directory structure:
```
/mnt/hdd/JellyFinDir/
├── config/     # Configuration files
├── cache/      # Cache files
└── media/      # Media files
```

## Usage

1. Navigate to this directory:
   ```bash
   cd jellyfin-setup
   ```

2. Start the Jellyfin server:
   ```bash
   docker compose up -d
   ```
   
   Or use the management script:
   ```bash
   ./manage.sh start
   ```

3. Access Jellyfin at http://localhost:8096

4. To stop the server:
   ```bash
   docker compose down
   ```
   
   Or use the management script:
   ```bash
   ./manage.sh stop
   ```

## Management Script

The `manage.sh` script provides convenient commands for managing the Jellyfin server:
- `./manage.sh start` - Start the server
- `./manage.sh stop` - Stop the server
- `./manage.sh restart` - Restart the server
- `./manage.sh status` - Show server status
- `./manage.sh logs` - Show and follow server logs

## Updating Jellyfin

To update to the latest version of Jellyfin:
```bash
./update.sh
```

This will pull the latest image and restart the server.

## Ports

- 8096: HTTP access
- 8920: HTTPS access

## Volumes

The following volumes are mounted:
- `/mnt/hdd/JellyFinDir/config` → `/config` (Configuration)
- `/mnt/hdd/JellyFinDir/cache` → `/cache` (Cache)
- `/mnt/hdd/JellyFinDir/media` → `/media` (Media files)