#!/bin/bash

ENV=.env # Do not touch

function cleanup {
	sudo docker system prune -a --volumes -f
}

function get_services {
	if [ $# -eq 0 ]; then
		# Return all services in services/ directory
		find services -maxdepth 1 -type d -not -name "services" | sort
	else
		# Return only specified services, validate they exist
		for service in "$@"; do
			if [ -d "services/$service" ]; then
				echo "services/$service"
			else
				echo "Error: Service '$service' not found in services/" >&2
				return 1
			fi
		done
	fi
}

function get_container_names {
	# shellcheck disable=SC2016
	find services -maxdepth 2 -name docker-compose.yml -print0 \
		| xargs -0 -r awk -F: '
			$1 ~ /^[[:space:]]*container_name[[:space:]]*$/ {
				name=$2
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
				gsub(/^["'\'']|["'\'']$/, "", name)
				if (name != "") print name
			}
		' \
		| sort -u
}

function contains_line {
	local needle="$1"
	grep -Fxq "$needle"
}

function prune-stale {
	echo "Pruning containers not present in services/..."

	active_containers=$(get_container_names)
	if [ -z "$active_containers" ]; then
		echo "ERROR: No active containers found in services/" >&2
		return 1
	fi

	stale_containers=()
	while IFS=$'\t' read -r name compose_project; do
		[ -z "$name" ] && continue

		if printf '%s\n' "$active_containers" | contains_line "$name"; then
			continue
		fi

		# Only prune containers that Docker Compose created. This keeps unrelated
		# manually managed containers outside this repository alone.
		if [ -n "$compose_project" ]; then
			stale_containers+=("$name")
		fi
	done < <(docker ps -a --format '{{.Names}}\t{{.Label "com.docker.compose.project"}}')

	if [ ${#stale_containers[@]} -eq 0 ]; then
		echo "No stale Compose containers found."
	else
		echo "Removing stale containers: ${stale_containers[*]}"
		docker rm -f "${stale_containers[@]}"
	fi

	docker system prune -a --volumes -f
	echo "Prune completed!"
}

function start {
	if [ $# -eq 0 ]; then
		echo "Starting all services..."
	else
		echo "Starting services: $*"
	fi

	# Get services to start
	services=$(get_services "$@") || return 1

	# Phase 1: Run start scripts
	echo "Phase 1: Running start scripts..."
	while IFS= read -r service_dir; do
		[ -z "$service_dir" ] && continue
		service_name=$(basename "$service_dir")
		if [ -f "$service_dir/start.sh" ]; then
			echo "Running start script for $service_name..."
			(cd "$service_dir" && ./start.sh)
		fi
	done <<<"$services"

	# Phase 2: Build compose file list and start Docker services
	echo "Phase 2: Starting Docker services..."
	compose_files=""
	docker_services=""
	while IFS= read -r service_dir; do
		[ -z "$service_dir" ] && continue
		if [ -f "$service_dir/docker-compose.yml" ]; then
			compose_files="$compose_files -f $service_dir/docker-compose.yml"
			docker_services="$docker_services $(basename "$service_dir")"
		fi
	done <<<"$services"

	if [ -n "$compose_files" ]; then
		echo "Starting Docker services:$docker_services"
		# shellcheck disable=SC2086
		docker compose --env-file "$ENV" $compose_files up -d --build

		# Show caddy logs if it was started
		if echo "$docker_services" | grep -q "caddy"; then
			echo "Caddy logs:"
			docker container logs caddy
		fi
	else
		echo "No Docker services to start."
	fi

	echo "Start completed!"
}

function stop {
	if [ $# -eq 0 ]; then
		echo "Stopping all services..."
	else
		echo "Stopping services: $*"
	fi

	# Get services to stop
	services=$(get_services "$@") || return 1

	# Phase 1: Stop Docker services first
	echo "Phase 1: Stopping Docker services..."
	compose_files=""
	docker_services=""
	while IFS= read -r service_dir; do
		[ -z "$service_dir" ] && continue
		if [ -f "$service_dir/docker-compose.yml" ]; then
			compose_files="$compose_files -f $service_dir/docker-compose.yml"
			docker_services="$docker_services $(basename "$service_dir")"
		fi
	done <<<"$services"

	if [ -n "$compose_files" ]; then
		echo "Stopping Docker services:$docker_services"
		# shellcheck disable=SC2086
		docker compose --env-file "$ENV" $compose_files down
	else
		echo "No Docker services to stop."
	fi

	# Phase 2: Run stop scripts
	echo "Phase 2: Running stop scripts..."
	while IFS= read -r service_dir; do
		[ -z "$service_dir" ] && continue
		service_name=$(basename "$service_dir")
		if [ -f "$service_dir/stop.sh" ]; then
			echo "Running stop script for $service_name..."
			(cd "$service_dir" && ./stop.sh)
		fi
	done <<<"$services"

	echo "Stop completed!"
}

function restart {
	if [ $# -eq 0 ]; then
		echo "Restarting all services..."
	else
		echo "Restarting services: $*"
	fi
	stop "$@"
	start "$@"
}

function update {
	if [ $# -eq 0 ]; then
		echo "Updating all services..."
	else
		echo "Updating services: $*"
	fi

	# Get services to update (only Docker services)
	services=$(get_services "$@") || return 1

	# Build compose file list for Docker services only
	compose_files=""
	docker_services=""
	while IFS= read -r service_dir; do
		[ -z "$service_dir" ] && continue
		if [ -f "$service_dir/docker-compose.yml" ]; then
			compose_files="$compose_files -f $service_dir/docker-compose.yml"
			docker_services="$docker_services $(basename "$service_dir")"
		fi
	done <<<"$services"

	if [ -n "$compose_files" ]; then
		echo "Updating Docker services:$docker_services"
		echo "Pulling latest images..."
		# shellcheck disable=SC2086
		docker compose --env-file "$ENV" $compose_files pull

		echo "Updating services..."
		# shellcheck disable=SC2086
		docker compose --env-file "$ENV" $compose_files up --detach

		docker system prune -a --volumes -f
		echo "Docker services updated!"
	else
		echo "No Docker services to update."
	fi
}

function smoke {
	# Load DOMAIN from .env so we can resolve {$DOMAIN} placeholders
	set -a
	# shellcheck source=/dev/null
	source <(grep -v '^#' "$ENV" | grep -v '^$')
	set +a

	if [ -z "$DOMAIN" ]; then
		echo "ERROR: DOMAIN not set in $ENV"
		return 1
	fi

	services=$(get_services "$@") || return 1

	declare -a urls=()
	while IFS= read -r service_dir; do
		[ -z "$service_dir" ] && continue

		# Prefer explicit health checks from data.json, then UI URLs.
		data_file="$service_dir/data.json"
		if [ -f "$data_file" ]; then
			data_urls=$(jq -r '.ui[]? | if has("hc") then .hc else .url // empty end | select(. != false)' "$data_file" 2>/dev/null)
			if [ -n "$data_urls" ]; then
				while IFS= read -r u; do
					urls+=("$u")
				done <<<"$data_urls"
				continue
			fi
		fi

		# Fall back to caddy.conf hostname extraction
		conf="$service_dir/caddy.conf"
		[ -f "$conf" ] || continue
		while IFS= read -r host_token; do
			urls+=("https://${host_token//\{\$DOMAIN\}/$DOMAIN}")
		done < <(grep -E '^[a-zA-Z0-9._{}$-]+[[:space:]]*\{[[:space:]]*$' "$conf" | sed -E 's/[[:space:]]*\{[[:space:]]*$//')
	done <<<"$services"

	if [ ${#urls[@]} -eq 0 ]; then
		echo "No HTTP endpoints to smoke-test"
		return 0
	fi

	curl_auth_args=()
	if [ -n "$BASICAUTH_USER" ] && [ -n "$BASICAUTH_PASS_PLAIN" ]; then
		curl_auth_args=(--user "${BASICAUTH_USER}:${BASICAUTH_PASS_PLAIN}")
	fi

	echo "Smoke testing ${#urls[@]} endpoint(s)..."
	failed=0
	for url in "${urls[@]}"; do
		# Up to 3 attempts to absorb container startup race
		code=000
		for attempt in 1 2 3; do
			code=$(curl "${curl_auth_args[@]}" -sS -o /dev/null -w "%{http_code}" -m 10 --connect-timeout 5 "$url" 2>/dev/null || echo "000")
			# 1xx-4xx = server reachable and responding; authenticated 401/403 means auth failed.
			if [ "$code" -ge 100 ] && [ "$code" -lt 500 ] && { [ ${#curl_auth_args[@]} -eq 0 ] || { [ "$code" -ne 401 ] && [ "$code" -ne 403 ]; }; }; then
				break
			fi
			[ $attempt -lt 3 ] && sleep 5
		done

		if [ "$code" -ge 100 ] && [ "$code" -lt 500 ] && { [ ${#curl_auth_args[@]} -eq 0 ] || { [ "$code" -ne 401 ] && [ "$code" -ne 403 ]; }; }; then
			echo "  OK    $url ($code)"
		else
			echo "  FAIL  $url ($code)"
			failed=$((failed + 1))
		fi
	done

	if [ $failed -gt 0 ]; then
		echo "$failed endpoint(s) unhealthy"
		return 1
	fi
	echo "All endpoints healthy"
	return 0
}

function status {
	echo "Service status:"
	echo "Active services:"
	for service_dir in $(get_services); do
		service_name=$(basename "$service_dir")
		has_docker=""
		has_scripts=""

		if [ -f "$service_dir/docker-compose.yml" ]; then
			has_docker="[Docker]"
		fi

		if [ -f "$service_dir/start.sh" ] || [ -f "$service_dir/stop.sh" ]; then
			has_scripts="[Scripts]"
		fi

		echo "  ✓ $service_name $has_docker $has_scripts"
	done

	echo ""
	echo "Disabled services:"
	if [ -d "disabled" ]; then
		find disabled -maxdepth 1 -type d -not -name "disabled" | sort | while read -r service_dir; do
			service_name=$(basename "$service_dir")
			echo "  ✗ $service_name"
		done
	else
		echo "  (none)"
	fi
}

function info {
	docker image inspect --format '{{json .}}' "$1" | jq -r '. | {Id: .Id, Digest: .Digest, RepoDigests: .RepoDigests, Labels: .Config.Labels}'
}

function default {
	# Default task to execute
	help
}

function help {
	echo "$0 <task> <args>"
	echo "Tasks:"
	compgen -A function | cat -n
}

TIMEFORMAT="Task completed in %3lR"
time "${@:-default}"
