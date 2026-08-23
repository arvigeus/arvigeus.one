#!/bin/bash
set -euo pipefail

# Generate a static dashboard from all services' data.json files.
# Output: ./public/index.html (+ icons), served by Caddy's file_server.

# Load environment variables from project root
set -a
# shellcheck source=/dev/null
source <(grep -v '^#' "../../.env" | grep -v '^$')
set +a

OUT_DIR="./public"
ICON_DIR="$OUT_DIR/icons"

echo "Generating static dashboard..."
rm -rf "$OUT_DIR"
mkdir -p "$ICON_DIR"

entries_file=$(mktemp)
trap 'rm -f "$entries_file"' EXIT
: > "$entries_file"

add_entry() {
	# name subtitle category logo url order
	jq -nc \
		--arg name "$1" \
		--arg subtitle "$2" \
		--arg category "$3" \
		--arg logo "$4" \
		--arg url "$5" \
		--argjson order "$6" \
		'{name: $name, subtitle: $subtitle, category: $category, logo: $logo, url: $url, order: $order}' \
		>> "$entries_file"
}

copy_logo() {
	# <source file> [target file name]
	local source_logo="$1"
	local target_name="${2:-$(basename "$source_logo")}"
	if [ ! -f "$ICON_DIR/$target_name" ] || [ "$source_logo" -nt "$ICON_DIR/$target_name" ]; then
		cp "$source_logo" "$ICON_DIR/$target_name"
	fi
	echo "icons/$target_name"
}

detect_url() {
	# Explicit url wins; otherwise extract subdomain from the service's caddy.conf
	if [ -n "$1" ]; then
		echo "$1"
	elif [ -f "$2/caddy.conf" ]; then
		local subdomain
		subdomain=$(grep -E "^[a-zA-Z0-9.-]+\.\{\\\$DOMAIN\}" "$2/caddy.conf" | head -1 | cut -d'.' -f1 || true)
		if [ -n "$subdomain" ]; then
			echo "https://$subdomain.$DOMAIN"
		else
			echo "  WARNING: Could not auto-detect URL for $3" >&2
		fi
	else
		echo "  WARNING: No caddy.conf found for $3 - URL will be missing" >&2
	fi
}

# Scan all services for ui entries
for service_dir in ../../services/*/; do
	[ ! -d "$service_dir" ] && continue

	service_name=$(basename "$service_dir")
	data_file="$service_dir/data.json"
	[ ! -f "$data_file" ] && continue

	if ! jq -e '.ui | type == "array"' "$data_file" >/dev/null 2>&1; then
		echo "  Skipping $service_name: no ui array found"
		continue
	fi

	while IFS= read -r entry; do
		hidden=$(echo "$entry" | jq -r '.hidden // false')
		[ "$hidden" = "true" ] && continue

		name=$(echo "$entry" | jq -r '.name')
		subtitle=$(echo "$entry" | jq -r '.subtitle // ""')
		category=$(echo "$entry" | jq -r '.category // "System"')
		logo_prop=$(echo "$entry" | jq -r '.logo // ""')
		url_prop=$(echo "$entry" | jq -r '.url // ""')
		order=$(echo "$entry" | jq -r '.order // 999')

		# Handle logo: explicit path, else auto-detect logo.png/logo.svg
		logo_path=""
		if [ -n "$logo_prop" ]; then
			source_logo="$service_dir/$logo_prop"
			[ -f "$source_logo" ] && logo_path=$(copy_logo "$source_logo")
		else
			for ext in png svg; do
				source_logo="$service_dir/logo.$ext"
				if [ -f "${source_logo}" ]; then
					# Prefix with service name to avoid conflicts between services
					logo_path=$(copy_logo "$source_logo" "${service_name}_logo.$ext")
					break
				fi
			done
		fi

		url=$(detect_url "$url_prop" "$service_dir" "$name")

		add_entry "$name" "$subtitle" "$category" "$logo_path" "$url" "$order"
	done < <(jq -c '.ui[]' "$data_file")
done

# Static resource links (rendered as the final section)
if [ -f "./config/resources.json" ]; then
	while IFS= read -r entry; do
		name=$(echo "$entry" | jq -r '.name')
		subtitle=$(echo "$entry" | jq -r '.subtitle // ""')
		logo=$(echo "$entry" | jq -r '.logo // ""')
		url=$(echo "$entry" | jq -r '.url // ""')

		logo_path=""
		if [ -n "$logo" ] && [ -f "./assets/$(basename "$logo")" ]; then
			logo_path=$(copy_logo "./assets/$(basename "$logo")")
		fi

		add_entry "$name" "$subtitle" "Resources" "$logo_path" "$url" 0
	done < <(jq -c '.[]' ./config/resources.json)
fi

# Rank categories, then render static HTML fragments
services_html=$(jq -sc '
	map(.category_rank =
		({"Entertainment": 0, "Productivity": 1, "Development": 2, "System": 3, "Resources": 4}[.category] // 5))' "$entries_file" |
	jq -r -f ./config/render.jq)

count=$(jq -s 'length' "$entries_file")

# Inject fragments into the template
template=$(cat "./config/index.html")
html="${template//'__SERVICES_HTML__'/$services_html}"
html="${html//'__DOMAIN__'/$DOMAIN}"

printf '%s\n' "$html" > "$OUT_DIR/index.html"

echo "Dashboard generated: $OUT_DIR/index.html ($count entries)"
