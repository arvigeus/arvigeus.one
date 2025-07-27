#!/bin/bash

echo "Installing Podman alongside Docker (compatible mode)..."

# Load environment variables
set -a
# shellcheck source=/dev/null
source <(grep -v '^#' ".env" | grep -v '^$')
set +a

# YOLO mode - no backups needed

# Install Podman in most compatible way
echo "Installing Podman packages..."
sudo apt update
sudo apt install -y \
    podman \
    podman-compose \
    podman-docker \
    cockpit-podman

# Configure Podman to be Docker-compatible
echo "Configuring Podman for Docker compatibility..."

# Enable Podman socket (rootful for maximum compatibility)
sudo systemctl enable --now podman.socket

# Create Docker-compatible socket symlink
sudo ln -sf /run/podman/podman.sock /var/run/docker.sock.podman

# Configure Podman to use same network as Docker
echo "Creating compatible network..."
sudo podman network create caddy_net 2>/dev/null || echo "Network already exists"

# Configure Podman registries (for Docker Hub compatibility)
sudo mkdir -p /etc/containers
sudo tee /etc/containers/registries.conf << EOF
[registries.search]
registries = ['docker.io', 'quay.io']

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF

# Configure storage to avoid conflicts
sudo mkdir -p /etc/containers
sudo tee /etc/containers/storage.conf << EOF
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options]
additionalimagestores = [
]

[storage.options.overlay]
mountopt = "nodev,metacopy=on"
EOF

# Test Podman installation
echo "Testing Podman installation..."
if sudo podman version >/dev/null 2>&1; then
    echo "✅ Podman installed successfully"
    sudo podman version
else
    echo "❌ Podman installation failed"
    exit 1
fi

# Test Docker compatibility
echo "Testing Docker compatibility..."
if sudo podman-docker version >/dev/null 2>&1; then
    echo "✅ Docker compatibility layer working"
else
    echo "⚠️  Docker compatibility layer may have issues"
fi

# podman_switch.sh already created separately

echo ""
echo "🎉 Podman installation complete!"
echo ""
echo "Next steps:"
echo "1. Test current Docker setup: ./run.sh status"
echo "2. Switch to Podman: ./podman_switch.sh enable"
echo "3. Test with Podman: ./run.sh status"
echo "4. If issues, revert: ./podman_switch.sh disable"
echo ""
echo "Management commands:"
echo "  ./podman_switch.sh status   - Check current state"
echo "  ./podman_switch.sh enable   - Use Podman"
echo "  ./podman_switch.sh disable  - Use Docker"
echo ""
echo "Cockpit Podman available at: https://system.$DOMAIN"