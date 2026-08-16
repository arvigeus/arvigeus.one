# Shared command functions; sourced by ../run.sh.

function smoke {
	# Load DOMAIN from .env so we can resolve {$DOMAIN} placeholders
	set -a
	# shellcheck source=/dev/null
	source <(grep -v '^#' "$ENV" | grep -v '^$')
	set +a

	DOMAIN="${DOMAIN:-}"
	BASICAUTH_USER="${BASICAUTH_USER:-}"
	BASICAUTH_PASS_PLAIN="${BASICAUTH_PASS_PLAIN:-}"
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
			has_ui=$(jq '[.ui[]?] | length' "$data_file" 2>/dev/null)
			if [ "$has_ui" -gt 0 ]; then
				data_urls=$(jq -r '.ui[]? | if has("hc") then .hc else .url // empty end | select(. != false)' "$data_file" 2>/dev/null)
				if [ -n "$data_urls" ]; then
					while IFS= read -r u; do
						urls+=("$u")
					done <<<"$data_urls"
				fi
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

