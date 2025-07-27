#!/bin/bash

# Diun update handler script
# Arguments: HubLink ImageName CurrentTag NewTag Status

HUB_LINK="$1"
IMAGE_NAME="$2"
CURRENT_TAG="$3"
NEW_TAG="$4"
STATUS="$5"

# Log the update check
echo "$(date): Auto-updating $IMAGE_NAME (patch/minor: $CURRENT_TAG -> $NEW_TAG)" >> /data/diun_updates.log

# Find the service directory and update
SERVICE_DIR="/opt/services"  # Mounted volume

# Try to find the service by image name
for service_path in "$SERVICE_DIR"/*; do
    if [ -f "$service_path/docker-compose.yml" ]; then
        if grep -q "$IMAGE_NAME" "$service_path/docker-compose.yml"; then
            echo "$(date): Found service at $service_path, updating..." >> /data/diun_updates.log
            cd "$service_path" || continue
            docker compose pull && docker compose up -d
            echo "$(date): Updated $IMAGE_NAME successfully" >> /data/diun_updates.log
            break
        fi
    fi
done
