#!/bin/bash

set -euo pipefail

cron_root="$HOME/Projects/scripts"
managed_prefix="arvigeus-cron-"
desired_jobs=$(mktemp)

cleanup() {
	rm -f "$desired_jobs"
}
trap cleanup EXIT

# Do not interpret a missing/mis-mounted scripts directory as an empty config:
# that could otherwise remove every currently managed job.
if [ ! -d "$cron_root" ]; then
	echo "Cron source directory does not exist: $cron_root" >&2
	exit 1
fi

sudo mkdir -p /etc/cron.d
sudo systemctl enable --now cron

job_count=0
for cron_file in "$cron_root"/*/cron; do
	[ -f "$cron_file" ] || continue

	project_name=$(basename -- "$(dirname -- "$cron_file")")
	safe_name=$(printf '%s' "$project_name" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-')
	name_hash=$(printf '%s' "$project_name" | sha256sum | cut -c1-12)
	destination="/etc/cron.d/${managed_prefix}${safe_name}-${name_hash}"

	sudo install -o root -g root -m 0644 "$cron_file" "$destination"
	printf '%s\n' "$destination" >>"$desired_jobs"
	echo "Installed cron job for $project_name: $destination"
	job_count=$((job_count + 1))
done

# Reconcile previously installed jobs as well as adding current ones. This
# removes jobs whose source project or cron file has disappeared.
for installed_job in /etc/cron.d/"${managed_prefix}"*; do
	[ -e "$installed_job" ] || continue
	if ! grep -Fxq -- "$installed_job" "$desired_jobs"; then
		sudo rm -f -- "$installed_job"
		echo "Removed stale cron job: $installed_job"
	fi
done

# cron watches /etc/cron.d, so no daemon restart is needed.
echo "Cron service started with $job_count managed job(s)."
