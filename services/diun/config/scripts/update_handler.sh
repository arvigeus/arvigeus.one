#!/bin/bash

# Diun update handler script
# Arguments: HubLink ImageName CurrentTag NewTag Status

HUB_LINK="$1"
IMAGE_NAME="$2"
CURRENT_TAG="$3"
NEW_TAG="$4"
STATUS="$5"

LOG_FILE="/data/diun_updates.log"

# Function to extract version numbers from semver tags
parse_version() {
    local version="$1"
    # Remove 'v' prefix if present and extract major.minor.patch
    version=$(echo "$version" | sed 's/^v//')
    # Extract major, minor, patch using regex
    if [[ $version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
    else
        echo "0 0 0"  # Default for non-semver tags
    fi
}

# Function to check if update should proceed (only minor/patch updates)
should_update() {
    local current="$1"
    local new="$2"
    
    # Skip if tags are the same
    if [ "$current" = "$new" ]; then
        return 1
    fi
    
    # Parse versions
    read -r current_major current_minor current_patch <<< "$(parse_version "$current")"
    read -r new_major new_minor new_patch <<< "$(parse_version "$new")"
    
    # Only update if major version is the same
    if [ "$current_major" -eq "$new_major" ]; then
        # Allow minor or patch updates
        if [ "$new_minor" -gt "$current_minor" ] || 
           ([ "$new_minor" -eq "$current_minor" ] && [ "$new_patch" -gt "$current_patch" ]); then
            return 0
        fi
    fi
    
    return 1
}

# Log the update check
echo "$(date): Checking update for $IMAGE_NAME ($CURRENT_TAG -> $NEW_TAG)" >> "$LOG_FILE"

# Check if we should proceed with the update
if ! should_update "$CURRENT_TAG" "$NEW_TAG"; then
    echo "$(date): Skipping $IMAGE_NAME - major version change or invalid version detected" >> "$LOG_FILE"
    exit 0
fi

echo "$(date): Auto-updating $IMAGE_NAME (minor/patch: $CURRENT_TAG -> $NEW_TAG)" >> "$LOG_FILE"

# Find the service directory and update
SERVICE_DIR="/opt/services"  # Mounted volume

# Try to find the service by image name
for service_path in "$SERVICE_DIR"/*; do
    if [ -f "$service_path/docker-compose.yml" ]; then
        if grep -q "$IMAGE_NAME" "$service_path/docker-compose.yml"; then
            echo "$(date): Found service at $service_path, updating..." >> "$LOG_FILE"
            cd "$service_path" || continue
            if docker compose pull && docker compose up -d; then
                echo "$(date): Updated $IMAGE_NAME successfully" >> "$LOG_FILE"
            else
                echo "$(date): Failed to update $IMAGE_NAME" >> "$LOG_FILE"
            fi
            exit 0
        fi
    fi
done

echo "$(date): Service not found for $IMAGE_NAME" >> "$LOG_FILE"
