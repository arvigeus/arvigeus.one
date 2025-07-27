#!/bin/bash

echo "Installing Docker (replacing Podman)..."

# Load environment variables
set -a
# shellcheck source=/dev/null
source <(grep -v '^#' ".env" | grep -v '^$')
set +a

# Stop and remove Podman first
echo "Removing Podman..."
sudo systemctl stop podman.socket
sudo systemctl disable podman.socket
sudo apt remove -y podman podman-compose podman-docker cockpit-podman
sudo apt autoremove -y

# Remove Podman socket symlink
sudo rm -f /var/run/docker.sock

# Install Docker
echo "Installing Docker packages..."
sudo apt update
sudo apt install -y apt-transport-https software-properties-common ca-certificates curl gnupg lsb-release

# Add Docker repository
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Note: Using modern 'docker compose' plugin instead of legacy docker-compose

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Create Docker network
sudo docker network create caddy_net 2>/dev/null || echo "Network already exists"

# Add user to docker group
sudo usermod -a -G docker $USER

# Test Docker installation
echo "Testing Docker installation..."
if sudo docker version >/dev/null 2>&1; then
    echo "✅ Docker installed successfully"
    sudo docker version
else
    echo "❌ Docker installation failed"
    exit 1
fi

# Test Docker Compose
echo "Testing Docker Compose..."
if docker compose version >/dev/null 2>&1; then
    echo "✅ Docker Compose working"
    docker compose version
else
    echo "❌ Docker Compose failed"
    exit 1
fi

echo ""
echo "🎉 Docker installation complete!"
echo ""
echo "Next steps:"
echo "1. Log out and back in (for docker group membership)"
echo "2. Test Docker setup: ./run.sh status"
echo "3. Start services: ./run.sh start"
echo "4. If issues, try Podman: ./install_podman.sh"
echo ""
echo "Cockpit available at: https://system.$DOMAIN"