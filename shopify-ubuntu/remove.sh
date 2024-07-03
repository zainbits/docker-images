#!/bin/bash

ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[0.0.0.0]:3022"

# Stop the container
sudo docker compose stop shopify-practice

# Remove the container
sudo docker compose rm -f shopify-practice

# Remove the image
sudo docker image rm shopify-practice