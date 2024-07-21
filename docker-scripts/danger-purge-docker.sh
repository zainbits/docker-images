#!/bin/bash

# Function to log messages
log() {
    echo "[INFO] $1"
}

# Function to log errors
error() {
    echo "[ERROR] $1" >&2
}

# Check if the user is root
if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root. Use sudo."
    exit 1
fi

log "Starting Docker uninstallation process..."

# Function to remove Docker packages
remove_docker_packages() {
    log "Removing Docker packages..."
    apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

# Function to remove Docker dependencies
remove_docker_dependencies() {
    log "Removing Docker dependencies..."
    apt-get autoremove -y
}

# Function to remove Docker directories
remove_docker_directories() {
    log "Removing Docker directories..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
}

# Function to remove Docker group and user if exist
remove_docker_group_user() {
    log "Removing Docker group and user if they exist..."
    if getent group docker >/dev/null; then
        groupdel docker
    fi

    if id -u docker >/dev/null 2>&1; then
        userdel docker
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to uninstall Docker using snap if installed via snap
remove_docker_snap() {
    if command_exists snap; then
        if snap list | grep -q docker; then
            log "Removing Docker installed via snap..."
            snap remove docker
        fi
    fi
}

# Function to clean up residual files
cleanup_residual_files() {
    log "Cleaning up residual Docker files..."
    rm -rf /etc/docker
    rm -rf /etc/systemd/system/docker.service
    rm -rf /etc/systemd/system/docker.socket
    rm -rf /usr/libexec/docker
    rm -rf /usr/local/bin/docker-compose
    rm -rf /usr/share/docker
}

# Function to reload the systemd daemon
reload_systemd_daemon() {
    log "Reloading systemd daemon..."
    systemctl daemon-reload
}

# Function to remove Docker GPG key
remove_docker_gpg_key() {
    log "Removing Docker GPG key..."
    apt-key del 7EA0A9C3F273FCD8
}

# Function to remove Docker APT source list
remove_docker_apt_source() {
    log "Removing Docker APT source list..."
    rm -f /etc/apt/sources.list.d/docker.list
}

# Main uninstallation process
main() {
    remove_docker_packages
    if [ $? -ne 0 ]; then
        error "Failed to remove Docker packages. Aborting."
        exit 1
    fi

    remove_docker_dependencies
    if [ $? -ne 0 ]; then
        error "Failed to remove Docker dependencies. Continuing..."
    fi

    remove_docker_directories
    remove_docker_group_user
    remove_docker_snap
    cleanup_residual_files
    reload_systemd_daemon
    remove_docker_gpg_key
    remove_docker_apt_source

    log "Docker has been successfully uninstalled from your system."
}

# Execute the main function
main
