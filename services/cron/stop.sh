#!/bin/bash

set -euo pipefail

managed_prefix="arvigeus-cron-"
job_count=0

# Managed files have a dedicated prefix, so cleanup does not depend on source
# cron files still existing under the user's home directory.
for installed_job in /etc/cron.d/"${managed_prefix}"*; do
	[ -e "$installed_job" ] || continue
	sudo rm -f -- "$installed_job"
	echo "Removed cron job: $installed_job"
	job_count=$((job_count + 1))
done

echo "Cron service stopped; removed $job_count managed job(s)."
