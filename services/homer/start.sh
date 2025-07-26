#!/bin/bash

# Load environment variables from project root
set -a
# shellcheck source=/dev/null
source <(grep -v '^#' "../../.env" | grep -v '^$')
set +a

# Clean up and create homer data directory
# echo "Cleaning and creating Homer data directory..."
sudo rm -rf "$DATA/homer"
sudo mkdir -p "$DATA/homer/icons"
sudo chown -R "$PUID:$PGID" "$DATA/homer"

# Initialize services array for each category
declare -A categories
categories["Entertainment"]="fas fa-music"
categories["Productivity"]="fas fa-desktop"
categories["System"]="fas fa-cogs"

# Initialize arrays to hold services by category
declare -a entertainment_services=()
declare -a productivity_services=()
declare -a system_services=()

# echo "Scanning services for Homer configuration..."

# Read all service directories
for service_dir in ../../services/*/; do
    [ ! -d "$service_dir" ] && continue
    
    service_name=$(basename "$service_dir")
    data_file="$service_dir/data.json"
    
    # Skip if no data.json file
    [ ! -f "$data_file" ] && continue
    
    # echo "Processing $service_name..."
    
    # Check if ui key exists and is array
    if ! jq -e '.ui | type == "array"' "$data_file" >/dev/null 2>&1; then
        echo "  Skipping $service_name: no ui array found"
        continue
    fi
    
    # Process each UI entry
    while IFS= read -r entry; do
        name=$(echo "$entry" | jq -r '.name')
        subtitle=$(echo "$entry" | jq -r '.subtitle // ""')
        category=$(echo "$entry" | jq -r '.category // "System"')
        logo_prop=$(echo "$entry" | jq -r '.logo // ""')
        url_prop=$(echo "$entry" | jq -r '.url // ""')
        
        # echo "  Processing UI entry: $name"
        
        # Handle logo
        logo_path=""
        if [ -n "$logo_prop" ] && [ "$logo_prop" != "null" ]; then
            # Use specified logo file
            source_logo="$service_dir/$logo_prop"
            if [ -f "$source_logo" ]; then
                logo_filename=$(basename "$logo_prop")
                target_logo="$DATA/homer/icons/$logo_filename"
                
                # Copy if newer or doesn't exist
                if [ ! -f "$target_logo" ] || [ "$source_logo" -nt "$target_logo" ]; then
                    # echo "    Copying logo: $logo_prop"
                    sudo cp "$source_logo" "$target_logo"
                    sudo chown "$PUID:$PGID" "$target_logo"
                fi
                logo_path="assets/icons/$logo_filename"
            fi
        else
            # Check for logo.png or logo.svg
            for ext in png svg; do
                source_logo="$service_dir/logo.$ext"
                if [ -f "$source_logo" ]; then
                    logo_filename="${service_name}_logo.$ext"
                    target_logo="$DATA/homer/icons/$logo_filename"
                    
                    # Copy if newer or doesn't exist
                    if [ ! -f "$target_logo" ] || [ "$source_logo" -nt "$target_logo" ]; then
                        # echo "    Copying auto-detected logo: logo.$ext"
                        sudo cp "$source_logo" "$target_logo"
                        sudo chown "$PUID:$PGID" "$target_logo"
                    fi
                    logo_path="assets/icons/$logo_filename"
                    break
                fi
            done
        fi
        
        # Handle URL
        url=""
        if [ -n "$url_prop" ] && [ "$url_prop" != "null" ]; then
            url="$url_prop"
        else
            # Auto-detect from caddy.conf
            caddy_conf="$service_dir/caddy.conf"
            if [ -f "$caddy_conf" ]; then
                # Look for reverse_proxy lines and extract subdomain
                subdomain=$(grep -E "^[a-zA-Z0-9.-]+\.\{\$DOMAIN\}" "$caddy_conf" | head -1 | cut -d'.' -f1)
                if [ -n "$subdomain" ]; then
                    url="https://$subdomain.$DOMAIN"
                    # echo "    Auto-detected URL: $url"
                fi
            fi
        fi
        
        # Build service entry
        service_entry="      - name: \"$name\""
        if [ -n "$subtitle" ] && [ "$subtitle" != "null" ]; then
            service_entry="$service_entry"$'\n'"        subtitle: \"$subtitle\""
        fi
        if [ -n "$logo_path" ]; then
            service_entry="$service_entry"$'\n'"        logo: \"$logo_path\""
        fi
        if [ -n "$url" ]; then
            service_entry="$service_entry"$'\n'"        url: \"$url\""
        fi
        
        # Add to appropriate category array
        case "$category" in
            "Entertainment")
                entertainment_services+=("$service_entry")
                ;;
            "Productivity")
                productivity_services+=("$service_entry")
                ;;
            "System")
                system_services+=("$service_entry")
                ;;
            *)
                system_services+=("$service_entry")
                ;;
        esac
    done < <(jq -c '.ui[]' "$data_file")
done

# echo "Generating Homer configuration..."

# Debug: Show what we found
# echo "Debug: Entertainment services: ${#entertainment_services[@]}"
# echo "Debug: Productivity services: ${#productivity_services[@]}"
# echo "Debug: System services: ${#system_services[@]}"

# Read the base config template
config_template=$(cat "./config/config.yml")

# Build services section
services_yaml="services:"

# Add Entertainment category if has services
if [ ${#entertainment_services[@]} -gt 0 ]; then
    services_yaml="$services_yaml"$'\n'"  - name: \"Entertainment\""
    services_yaml="$services_yaml"$'\n'"    icon: \"fas fa-music\""
    services_yaml="$services_yaml"$'\n'"    items:"
    for service_entry in "${entertainment_services[@]}"; do
        services_yaml="$services_yaml"$'\n'"$service_entry"
    done
    services_yaml="$services_yaml"$'\n'
fi

# Add Productivity category if has services
if [ ${#productivity_services[@]} -gt 0 ]; then
    services_yaml="$services_yaml"$'\n'"  - name: \"Productivity\""
    services_yaml="$services_yaml"$'\n'"    icon: \"fas fa-desktop\""
    services_yaml="$services_yaml"$'\n'"    items:"
    for service_entry in "${productivity_services[@]}"; do
        services_yaml="$services_yaml"$'\n'"$service_entry"
    done
    services_yaml="$services_yaml"$'\n'
fi

# Add System category if has services
if [ ${#system_services[@]} -gt 0 ]; then
    services_yaml="$services_yaml"$'\n'"  - name: \"System\""
    services_yaml="$services_yaml"$'\n'"    icon: \"fas fa-cogs\""
    services_yaml="$services_yaml"$'\n'"    items:"
    for service_entry in "${system_services[@]}"; do
        services_yaml="$services_yaml"$'\n'"$service_entry"
    done
    services_yaml="$services_yaml"$'\n'
fi

# Replace the services section in config
# First, remove the old services section
echo "$config_template" | sed '/^# Services will be auto-generated by start.sh script$/,/^services: \[\]$/d' > "/tmp/homer_config_base.yml"

# Then append the new services section
echo "# Services auto-generated by start.sh script" >> "/tmp/homer_config_base.yml"
echo "$services_yaml" >> "/tmp/homer_config_base.yml"

# Use the combined file
mv "/tmp/homer_config_base.yml" "/tmp/homer_config.yml"

# Copy the generated config to the target location
sudo cp "/tmp/homer_config.yml" "$DATA/homer/config.yml"
sudo chown "$PUID:$PGID" "$DATA/homer/config.yml"

# Copy other Homer files
# echo "Copying Homer configuration files..."
sudo cp "./config/links.yml" "$DATA/homer/"
sudo cp "./config/manifest.json" "$DATA/homer/"
sudo chown "$PUID:$PGID" "$DATA/homer/links.yml" "$DATA/homer/manifest.json"

# Copy original icons directory (merge with existing)
if [ -d "./config/icons" ]; then
    sudo cp -r "./config/icons/"* "$DATA/homer/icons/"
    sudo chown -R "$PUID:$PGID" "$DATA/homer/icons"
fi

echo "Homer configuration generated successfully!"
#echo "Config written to: $DATA/homer/config.yml"

# Clean up temp files
rm -f "/tmp/homer_config.yml" "/tmp/homer_config_base.yml"