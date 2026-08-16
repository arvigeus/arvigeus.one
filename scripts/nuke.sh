# Shared command functions; sourced by ../run.sh.

function nuke_host_caches {
	echo "Cleaning reconstructible Debian host data..."

	if command -v apt-get >/dev/null 2>&1; then
		echo "Cleaning downloaded APT packages and package indexes..."
		run_privileged apt-get clean
		if run_privileged test -d /var/lib/apt/lists; then
			run_privileged find /var/lib/apt/lists -xdev -mindepth 1 -delete
		fi
	fi

	if command -v journalctl >/dev/null 2>&1; then
		echo "Rotating and shrinking the systemd journal to at most 3 days / 100 MB..."
		run_privileged journalctl --rotate
		run_privileged journalctl --vacuum-time=3d --vacuum-size=100M
	fi

	if command -v systemd-tmpfiles >/dev/null 2>&1; then
		echo "Removing temporary files that have expired under systemd policy..."
		run_privileged systemd-tmpfiles --clean
	fi

	if run_privileged test -d /var/log; then
		echo "Removing rotated and compressed legacy log files..."
		run_privileged find /var/log -xdev -type f \
			\( -name '*.gz' -o -name '*.old' -o -regextype posix-extended -regex '.*\.[0-9]+(\.old)?' \) \
			-delete
	fi

	for crash_dir in /var/lib/systemd/coredump /var/crash; do
		if run_privileged test -d "$crash_dir"; then
			echo "Removing stored crash reports from $crash_dir..."
			run_privileged find "$crash_dir" -xdev -mindepth 1 -delete
		fi
	done

	user_cache=$(realpath -m "$HOME/.cache")
	if [ "$user_cache" = "$HOME/.cache" ] && [ -d "$user_cache" ]; then
		echo "Clearing invoking-user cache: $user_cache"
		find "$user_cache" -xdev -mindepth 1 -delete
	fi

	if [ "$user_cache" != "/root/.cache" ] && run_privileged test -d /root/.cache; then
		echo "Clearing root's cache: /root/.cache"
		run_privileged find /root/.cache -xdev -mindepth 1 -delete
	fi
}

function nuke {
	if [ $# -ne 0 ]; then
		echo "Usage: $0 nuke" >&2
		echo "Nuking Docker is host-wide, so individual services cannot be selected." >&2
		return 1
	fi

	echo "Running cleanup hooks for all services..."
	services=$(get_services) || return 1
	found=0
	failed=0
	while IFS= read -r service_dir; do
		[ -z "$service_dir" ] && continue
		if [ ! -f "$service_dir/nuke.sh" ]; then
			continue
		fi

		found=$((found + 1))
		service_name=$(basename "$service_dir")
		echo "Running nuke hook for $service_name..."
		if ! (cd "$service_dir" && bash ./nuke.sh); then
			echo "ERROR: Nuke hook failed for $service_name." >&2
			failed=$((failed + 1))
		fi
	done <<<"$services"

	if [ "$found" -eq 0 ]; then
		echo "No service nuke hooks found."
	elif [ "$failed" -eq 0 ]; then
		echo "All $found service nuke hook(s) completed."
	else
		echo "$failed of $found service nuke hook(s) failed." >&2
		return 1
	fi

	nuke_host_caches

	if ! command -v docker >/dev/null 2>&1; then
		echo "ERROR: Docker is not installed." >&2
		return 1
	fi

	docker_root=$(docker info --format '{{.DockerRootDir}}') || {
		echo "ERROR: Could not determine Docker's data root." >&2
		return 1
	}
	docker_root=$(realpath -m "$docker_root")
	if [ "$docker_root" != "/var/lib/docker" ]; then
		echo "ERROR: Refusing to delete unexpected Docker data root: $docker_root" >&2
		echo "Expected exactly /var/lib/docker." >&2
		return 1
	fi

	load_env
	: "${DOCKER_NETWORK:?DOCKER_NETWORK is not set in $ENV}"

	echo "Stopping Docker and deleting its reconstructible data root: $docker_root"
	run_privileged systemctl stop docker.service docker.socket
	if ! run_privileged rm -rf -- "$docker_root"; then
		echo "ERROR: Docker data cleanup failed; restarting Docker." >&2
		run_privileged systemctl start docker.service
		return 1
	fi

	echo "Starting Docker and recreating all services..."
	run_privileged systemctl start docker.service
	docker network create "$DOCKER_NETWORK"
	start

	echo "Docker data-root reset and service recreation completed."
}

