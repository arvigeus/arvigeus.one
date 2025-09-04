#!/bin/bash

ENV=.env # Do not touch

function cleanup {
    sudo docker image prune -a
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
    done <<< "$services"
    
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
    done <<< "$services"
    
    if [ -n "$compose_files" ]; then
        echo "Starting Docker services:$docker_services"
        # shellcheck disable=SC2086
        docker compose --env-file "$ENV" $compose_files up -d --build --remove-orphans
        
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
    done <<< "$services"
    
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
    done <<< "$services"
    
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
    done <<< "$services"
    
    if [ -n "$compose_files" ]; then
        echo "Updating Docker services:$docker_services"
        echo "Pulling latest images..."
        # shellcheck disable=SC2086
        docker compose --env-file "$ENV" $compose_files pull
        
        echo "Updating services..."
        # shellcheck disable=SC2086
        docker compose --env-file "$ENV" $compose_files up --detach --remove-orphans
        
        docker image prune -f
        echo "Docker services updated!"
    else
        echo "No Docker services to update."
    fi
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
        find disabled -maxdepth 1 -type d -not -name "disabled" | sort | while read service_dir; do
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