#!/bin/bash

set -euo pipefail

service_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
docker_config=$(mktemp)

cleanup() {
	rm -f "$docker_config"
}
trap cleanup EXIT

sudo install -m 0755 \
	"$service_dir/maintenance.sh" \
	/usr/local/sbin/arvigeus-maintenance
sudo install -m 0644 \
	"$service_dir/arvigeus-maintenance.service" \
	/etc/systemd/system/arvigeus-maintenance.service
sudo install -m 0644 \
	"$service_dir/arvigeus-maintenance.timer" \
	/etc/systemd/system/arvigeus-maintenance.timer

journal_changed=false
if ! sudo cmp -s \
	"$service_dir/journald-retention.conf" \
	/etc/systemd/journald.conf.d/arvigeus-retention.conf; then
	sudo install -D -m 0644 \
		"$service_dir/journald-retention.conf" \
		/etc/systemd/journald.conf.d/arvigeus-retention.conf
	journal_changed=true
fi

if sudo test -f /etc/docker/daemon.json; then
	sudo jq '
		. + {
			"log-driver": "json-file",
			"log-opts": (
				(.["log-opts"] // {}) + {
					"max-size": "10m",
					"max-file": "3"
				}
			)
		}
	' /etc/docker/daemon.json | tee "$docker_config" >/dev/null
else
	jq -n '{
		"log-driver": "json-file",
		"log-opts": {
			"max-size": "10m",
			"max-file": "3"
		}
	}' > "$docker_config"
fi

sudo dockerd --validate --config-file "$docker_config"
docker_changed=false
if ! sudo cmp -s "$docker_config" /etc/docker/daemon.json; then
	sudo install -m 0644 "$docker_config" /etc/docker/daemon.json
	docker_changed=true
fi

sudo systemctl daemon-reload
sudo systemctl enable --now arvigeus-maintenance.timer

if [ "$journal_changed" = true ]; then
	sudo systemctl restart systemd-journald
fi
if [ "$docker_changed" = true ]; then
	sudo systemctl restart docker
fi
