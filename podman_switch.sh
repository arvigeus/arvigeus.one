#!/bin/bash

case "$1" in
    "enable")
        echo "Switching to Podman..."
        sudo systemctl stop docker
        sudo systemctl disable docker
        sudo systemctl enable --now podman.socket
        sudo mv /var/run/docker.sock /var/run/docker.sock.backup 2>/dev/null || true
        sudo ln -sf /run/podman/podman.sock /var/run/docker.sock
        echo "Switched to Podman. Docker socket now points to Podman."
        ;;
    "disable")
        echo "Switching back to Docker..."
        sudo rm -f /var/run/docker.sock
        sudo mv /var/run/docker.sock.backup /var/run/docker.sock 2>/dev/null || true
        sudo systemctl stop podman.socket
        sudo systemctl enable --now docker
        echo "Switched back to Docker."
        ;;
    "status")
        echo "Current status:"
        if systemctl is-active --quiet docker; then
            echo "Docker: ACTIVE"
        else
            echo "Docker: INACTIVE"
        fi
        if systemctl is-active --quiet podman.socket; then
            echo "Podman: ACTIVE"
        else
            echo "Podman: INACTIVE"
        fi
        if [ -L /var/run/docker.sock ]; then
            echo "Docker socket: SYMLINK ($(readlink /var/run/docker.sock))"
        else
            echo "Docker socket: REGULAR FILE"
        fi
        ;;
    *)
        echo "Usage: $0 {enable|disable|status}"
        echo "  enable  - Switch to Podman (stops Docker)"
        echo "  disable - Switch back to Docker (stops Podman)"
        echo "  status  - Show current status"
        ;;
esac