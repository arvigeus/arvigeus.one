#!/bin/bash

ENV=.env # Do not touch

function setup {
    export $(cat $ENV | sed 's/#.*//g' | xargs)

    sudo apt update

    # Docker
    sudo apt-get install apt-transport-https software-properties-common ca-certificates curl gnupg lsb-release -y
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
    sudo apt update
    sudo apt -y install docker-ce docker-ce-cli
    curl -s https://api.github.com/repos/docker/compose/releases/latest | grep browser_download_url | grep docker-compose-Linux-x86_64 | cut -d '"' -f 4 | wget -qi -
    chmod +x docker-compose-Linux-x86_64
    sudo mv docker-compose-Linux-x86_64 /usr/bin/docker-compose
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo docker network create caddy_net
    sudo usermod -a -G docker $USER

    # Cockpit
    sudo wget -qO - https://repo.45drives.com/key/gpg.asc | sudo gpg --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg
    sudo curl -sSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources
    sudo apt update
    sudo apt install -y cockpit cockpit-navigator
    sudo cp $CONFIG/cockpit/cockpit.conf /etc/cockpit/cockpit.conf
    
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

    # Postgres
    sudo chmod +x $CONFIG/postgres/docker-entrypoint-initdb.d/create-multiple-postgresql-databases.sh

    # Tools
    sudo apt install jq
}

function cleanup {
    sudo docker image prune -a
}

function start {
    echo Starting services $*
    if [ -z "$1" ]; then
        sudo docker-compose --env-file $ENV up -d --build
    else
        for ARG in $*
        do
            sudo docker-compose --env-file up -d --build $ENV $ARG
        done
    fi
    sudo docker-compose exec nextcloud chown -R 82:root /var/www/html
    docker container logs caddy
}

function stop {
    echo Stopping services $*
    if [ -z "$1" ]; then
        sudo docker-compose --env-file $ENV down --remove-orphan
    else
        for ARG in $*
        do
            sudo docker-compose --env-file $ENV rm -s -v $ARG
        done
    fi
}

function restart {
    stop $*
    start $*
}

function update {
    docker-compose pull
    docker-compose up --detach
    docker image prune -f
}

function info {
    docker image inspect --format '{{json .}}' "$1" | jq -r '. | {Id: .Id, Digest: .Digest, RepoDigests: .RepoDigests, Labels: .Config.Labels}'
}

function post-setup {
    docker exec -u www-data app-server php occ --no-warnings app:install calendar
    docker exec -u www-data app-server php occ --no-warnings app:install contacts
    docker exec -u www-data app-server php occ --no-warnings app:install notes

    docker cp filestash:/app/data/state $DATA/filestash
    sudo chmod -R 777 $DATA/filestash

    stop $*

    echo "Now uncomment volumes for `filestash`, `kavita`, `dim`, `koel`, then run `./run.sh start`"
}

function default {
    # Default task to execute
    help
}

function help {
    echo "$0 <task> <args>"
    echo "Tasks:"
    compgen -A function | cat -n
}

TIMEFORMAT="Task completed in %3lR"
time ${@:-default}
