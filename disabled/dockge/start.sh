#!/bin/bash

echo "Setting up Dockge stacks directory..."

# Create the stacks directory if it doesn't exist
sudo mkdir -p /opt/stacks

# Set proper ownership for the stacks directory
# This allows Dockge to manage Docker Compose stacks
sudo chown -R $USER:$USER /opt/stacks