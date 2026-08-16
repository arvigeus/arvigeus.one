# Shared command functions; sourced by ../run.sh.

function cleanup {
	sudo docker system prune -a --volumes -f
}

function maintenance {
	if [ ! -x /usr/local/sbin/arvigeus-maintenance ]; then
		echo "ERROR: Automated maintenance is not installed." >&2
		echo "Run ./run.sh start maintenance first." >&2
		return 1
	fi
	run_privileged /usr/local/sbin/arvigeus-maintenance
}

function space {
	local command="${1:-report}"
	local mode="${2:-quick}"

	case "$command" in
	report | diagnose | usage)
		load_env

		echo "Disk usage:"
		df -hT -x tmpfs -x devtmpfs -x overlay 2>/dev/null || df -h

		echo ""
		echo "Inodes:"
		df -ih -x tmpfs -x devtmpfs -x overlay 2>/dev/null || df -ih

		if command -v docker >/dev/null 2>&1; then
			if docker info >/dev/null 2>&1; then
				echo ""
				echo "Docker usage:"
				docker system df

				echo ""
				echo "Docker details:"
				docker system df -v
			else
				echo ""
				echo "Docker usage unavailable: docker info failed"
			fi
		fi

		data_path=$(abs_path "${DATA:-}") || data_path=""
		projects_path=$(abs_path "${HOST_PROJECTS:-}") || projects_path=""

		show_top_usage "Project root top usage" "$(pwd)" 1
		show_top_usage "Configured DATA top usage" "$data_path" 2
		show_top_usage "Configured HOST_PROJECTS top usage" "$projects_path" 2
		show_top_usage "Home cache top usage" "$HOME/.cache" 1
		if [ "$mode" = "deep" ]; then
			show_top_usage "Home local/share top usage" "$HOME/.local/share" 1
		fi

		echo ""
		echo "Safe cleanup commands:"
		echo "  $0 space clean-docker      # stopped containers, dangling images, unused networks, build cache"
		echo "  $0 space clean-arch        # old pacman package cache, if paccache is available"
		echo "  $0 space clean-paru        # paru build/package cache, if paru is available"
		echo "  $0 space clean-journal     # systemd journal older than 7 days"
		echo "  $0 space clean-apt         # apt package cache, if apt is available"
		echo "  $0 space clean             # run all safe cleanup commands above"
		echo "  $0 space report deep       # include slower home local/share scan"
		echo ""
		echo "More aggressive existing commands:"
		echo "  $0 cleanup                 # Docker prune including unused images and volumes"
		echo "  $0 prune-stale             # remove stale compose containers, then full Docker prune"
		echo "  $0 nuke                    # clear service caches, reset Docker, and recreate services"
		;;
	clean-docker)
		if ! command -v docker >/dev/null 2>&1; then
			echo "Docker not found."
			return 0
		fi

		echo "Pruning conservative Docker leftovers..."
		docker container prune -f --filter "until=168h"
		docker image prune -f
		docker network prune -f --filter "until=168h"
		docker buildx prune -f --max-used-space 2gb
		docker system df
		;;
	clean-arch)
		if ! command -v paccache >/dev/null 2>&1; then
			echo "paccache not found. Install pacman-contrib to prune old pacman packages safely."
			return 0
		fi

		echo "Cleaning old pacman package cache..."
		sudo paccache -rk2
		sudo paccache -ruk0
		;;
	clean-paru)
		if ! command -v paru >/dev/null 2>&1; then
			echo "paru not found."
			return 0
		fi

		echo "Cleaning paru cache..."
		paru -Scc --noconfirm
		;;
	clean-journal)
		if ! command -v journalctl >/dev/null 2>&1; then
			echo "journalctl not found."
			return 0
		fi

		echo "Vacuuming systemd journal older than 7 days..."
		sudo journalctl --vacuum-time=30d --vacuum-size=1G
		;;
	clean-apt)
		if ! command -v apt-get >/dev/null 2>&1; then
			echo "apt-get not found."
			return 0
		fi

		echo "Cleaning apt package cache..."
		sudo apt-get clean
		;;
	clean)
		space clean-docker
		space clean-arch
		space clean-paru
		space clean-journal
		space clean-apt
		space report
		;;
	*)
		echo "Usage: $0 space [report [deep]|clean|clean-docker|clean-arch|clean-paru|clean-journal|clean-apt]"
		return 1
		;;
	esac
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

	# Deployment cleanup is intentionally conservative. Weekly maintenance
	# handles old tagged images and bounds build cache without touching volumes.
	docker image prune -f
	docker network prune -f --filter "until=168h"
	echo "Stale resource cleanup completed!"
}

