#!/bin/bash

echo "Installing Podman (replacing Docker)..."

# Load environment variables
set -a
# shellcheck source=/dev/null
source <(grep -v '^#' ".env" | grep -v '^$')
set +a

# Stop and remove Docker first
echo "Removing Docker..."
sudo systemctl stop docker
sudo systemctl disable docker
sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt autoremove -y

# Install Podman in most compatible way
echo "Installing Podman packages..."
sudo apt update

# Install Podman packages (no conflicts now)
sudo apt install -y \
    podman \
    podman-compose \
    podman-docker \
    cockpit-podman

echo "✅ Podman packages installed with Docker compatibility"

# Configure Podman to be Docker-compatible
echo "Configuring Podman for Docker compatibility..."

# Enable Podman socket (rootful for maximum compatibility)
sudo systemctl enable --now podman.socket

# Create Docker-compatible socket
sudo ln -sf /run/podman/podman.sock /var/run/docker.sock

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
if docker version >/dev/null 2>&1; then
    echo "✅ Docker compatibility layer working"
    docker version
else
    echo "❌ Docker compatibility layer failed"
    exit 1
fi

echo ""
echo "🎉 Podman installation complete!"
echo ""
echo "Next steps:"
echo "1. Test Podman setup: ./run.sh status"
echo "2. Start services: ./run.sh start"
echo "3. If issues, restore Docker: ./install_docker.sh"
echo ""
echo "Cockpit Podman available at: https://system.$DOMAIN"