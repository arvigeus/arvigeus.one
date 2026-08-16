# Shared command functions; sourced by ../run.sh.

function run_privileged {
	if [ "$EUID" -eq 0 ]; then
		"$@"
	else
		sudo "$@"
	fi
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
	find services -maxdepth 2 -name docker-compose.yml -print0 |
		xargs -0 -r awk -F: '
			$1 ~ /^[[:space:]]*container_name[[:space:]]*$/ {
				name=$2
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
				gsub(/^["'\'']|["'\'']$/, "", name)
				if (name != "") print name
			}
		' |
		sort -u
}

function contains_line {
	local needle="$1"
	grep -Fxq "$needle"
}

function load_env {
	if [ -f "$ENV" ]; then
		set -a
		# shellcheck source=/dev/null
		source <(grep -v '^#' "$ENV" | grep -v '^$')
		set +a
	fi
}

function abs_path {
	local path="$1"
	if [ -z "$path" ]; then
		return 1
	fi

	if command -v realpath >/dev/null 2>&1; then
		realpath -m "$path"
	else
		(cd "$(dirname "$path")" 2>/dev/null && printf '%s/%s\n' "$PWD" "$(basename "$path")")
	fi
}

function show_top_usage {
	local title="$1"
	local path="$2"
	local depth="${3:-1}"

	if [ -z "$path" ] || [ ! -e "$path" ]; then
		return 0
	fi

	echo ""
	echo "$title: $path"
	du -xhd "$depth" "$path" 2>/dev/null | sort -hr | head -n 25 || true
}

