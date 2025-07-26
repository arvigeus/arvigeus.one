#!/bin/bash

ENV=.env # Do not touch

function setup {
    set -a  # automatically export all variables
    # shellcheck source=/dev/null
    source <(grep -v '^#' "$ENV" | grep -v '^$')
    set +a  # disable automatic export

    sudo apt update

    # Docker
    sudo apt-get install apt-transport-https software-properties-common ca-certificates curl gnupg lsb-release -y
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
    sudo apt update
    sudo apt -y install docker-ce docker-ce-cli docker-compose-plugin
    curl -s https://api.github.com/repos/docker/compose/releases/latest | grep browser_download_url | grep docker-compose-Linux-x86_64 | cut -d '"' -f 4 | wget -qi -
    chmod +x docker-compose-Linux-x86_64
    sudo mv docker-compose-Linux-x86_64 /usr/bin/docker-compose
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo docker network create caddy_net
    sudo usermod -a -G docker "$USER"

    # Cockpit
    sudo wget -qO - https://repo.45drives.com/key/gpg.asc | sudo gpg --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg
    sudo curl -sSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources
    sudo apt update
    sudo apt install -y cockpit cockpit-navigator
    sudo cp config/cockpit/cockpit.conf /etc/cockpit/cockpit.conf

    # UFW
    sudo apt install -y ufw
    sudo ufw allow 443/tcp comment "caddy"
    sudo ufw allow 80/tcp comment "caddy"
    sudo ufw allow 22/tcp comment 'Open port ssh tcp port 22'
    sudo ufw allow 51820/udp comment 'Wireguard'
    sudo ufw allow 9090/tcp comment 'Cockpit'
    sudo ufw allow smtp comment "smtp"
    sudo ufw allow pop3 comment "pop3"
    sudo ufw enable

    # WebDav
    sudo apt-get install davfs2

    # Tools
    sudo apt install jq
}

function help {
    echo "$0 - Initial system setup"
    echo "Usage: $0"
    echo ""
    echo "This script sets up:"
    echo "  - Docker and Docker Compose"
    echo "  - Cockpit web interface"
    echo "  - UFW firewall rules"
    echo "  - Required tools and dependencies"
}

function default {
    setup
}

TIMEFORMAT="Task completed in %3lR"
time "${@:-default}"