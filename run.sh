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
    
    # Phase 2: Start Docker services individually (Podman compatibility)
    echo "Phase 2: Starting Docker services..."
    docker_services=""
    while IFS= read -r service_dir; do
        [ -z "$service_dir" ] && continue
        if [ -f "$service_dir/docker-compose.yml" ]; then
            service_name=$(basename "$service_dir")
            docker_services="$docker_services $service_name"
            echo "Starting $service_name..."
            
            # Load environment variables for Podman compatibility
            set -a
            # shellcheck source=/dev/null
            source <(grep -v '^#' "$ENV" | grep -v '^$')
            set +a
            
            (cd "$service_dir" && docker compose up -d --build)
        fi
    done <<< "$services"
    
    if [ -n "$docker_services" ]; then
        echo "Started Docker services:$docker_services"
        
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
    
    # Phase 1: Stop Docker services individually (Podman compatibility)
    echo "Phase 1: Stopping Docker services..."
    docker_services=""
    while IFS= read -r service_dir; do
        [ -z "$service_dir" ] && continue
        if [ -f "$service_dir/docker-compose.yml" ]; then
            service_name=$(basename "$service_dir")
            docker_services="$docker_services $service_name"
            echo "Stopping $service_name..."
            
            # Load environment variables for Podman compatibility
            set -a
            # shellcheck source=/dev/null
            source <(grep -v '^#' "$ENV" | grep -v '^$')
            set +a
            
            (cd "$service_dir" && docker compose down)
        fi
    done <<< "$services"
    
    if [ -n "$docker_services" ]; then
        echo "Stopped Docker services:$docker_services"
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
    
    # Update Docker services individually (Podman compatibility)
    docker_services=""
    while IFS= read -r service_dir; do
        [ -z "$service_dir" ] && continue
        if [ -f "$service_dir/docker-compose.yml" ]; then
            service_name=$(basename "$service_dir")
            docker_services="$docker_services $service_name"
            echo "Updating $service_name..."
            
            # Load environment variables for Podman compatibility
            set -a
            # shellcheck source=/dev/null
            source <(grep -v '^#' "$ENV" | grep -v '^$')
            set +a
            
            (cd "$service_dir" && docker compose pull)
            (cd "$service_dir" && docker compose up --detach)
        fi
    done <<< "$services"
    
    if [ -n "$docker_services" ]; then
        echo "Updated Docker services:$docker_services"
        
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