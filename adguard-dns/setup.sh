#!/bin/bash

# Exit on any error
set -e

# --- Configuration ---
# Get the primary local IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')
ADGUARD_DIR="./adguard"
CONF_DIR="$ADGUARD_DIR/conf"
WORK_DIR="$ADGUARD_DIR/work"
CERT_FILE="$CONF_DIR/certificate.crt"
KEY_FILE="$CONF_DIR/private.key"
ADGUARD_CONFIG="$CONF_DIR/AdGuardHome.yaml"

# --- Main Script ---

echo "--- AdGuard Home with DoH Setup ---"

# 1. Create directories
echo "1. Creating directories..."
sudo mkdir -p $CONF_DIR $WORK_DIR
sudo chmod -R 777 $ADGUARD_DIR

# 2. Generate Self-Signed Certificate
echo "2. Generating self-signed SSL certificate..."
sudo openssl req -x509 -newkey rsa:4096 \
    -keyout $KEY_FILE -out $CERT_FILE \
    -sha256 -days 3650 -nodes \
    -subj "/CN=$IP_ADDRESS"

# 3. Create AdGuardHome.yaml from template
echo "3. Creating AdGuardHome.yaml from template..."
sudo cp AdGuardHome.yaml.template $ADGUARD_CONFIG
sudo sed -i "s/__IP_ADDRESS__/$IP_ADDRESS/g" $ADGUARD_CONFIG

# 4. Start the container
echo "4. Starting AdGuard Home container..."
docker compose up -d

echo ""
echo "--- Setup Complete ---"
echo "AdGuard Home is running."
echo "Access the web interface at: https://$IP_ADDRESS"
echo "(Your browser will show a security warning, which is normal for a self-signed certificate.)"
echo "On the welcome screen, you will be asked to create an admin user."