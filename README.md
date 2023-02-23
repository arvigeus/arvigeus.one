# Home server

## System information

- Debian 11

## Setup

Rename `.env.example` to `.env`

Download caddy executable from [here](https://caddyserver.com/download) and move it in `config/caddy/caddy`

### Docker

It will be installed and configured as part of `./run.sh setup`

### User

Uncomment the following line in /etc/pam.d/su, by removing the leading '#':

```text
auth required pam_wheel.so
```

Create the group wheel with root privileges:

```sh
addgroup --system wheel
```

Execute `visudo` and add the following line:

```text
%wheel  ALL=(ALL)       NOPASSWD: ALL
```

Create user and add it to the `wheel` group:

```sh
useradd -m -g wheel arvigeus
passwd arvigeus
```

#### User misc

Use `bash` instead of `sh`

```sh
sudo chsh -s /bin/bash $(whoami)
```

Get user info

```sh
id
```

Get all groups:

```sh
less /etc/group
```

## Running containers

Allow `run.sh` to be executed:

```sh
sudo chmod +x run.sh
```

### Server

**Make sure volumes for `kavita`, `dim`, `koel` are commented out!**

```sh
# First time run
./run.sh setup

# manage containers:
./run.sh start
./run.sh stop
./run.sh restart
./run.sh update

# A manual hack for extra tweaks
./run.sh post-setup

# Other
./run.sh info IMAGE_NAME
```

## Databases

### Add new database to postgresql

```sh
docker exec -it postgres psql
```

```sql
CREATE USER $database WITH PASSWORD '$database';
CREATE DATABASE $database;
GRANT ALL PRIVILEGES ON DATABASE $database TO $database;
```

Replace `$database` with database name

### Remove database from postgresql

```sh
docker exec -it postgres psql
```

```sql
DROP USER $database;
DROP DATABASE $database;
```

Replace `$database` with database name

## Tips and tricks

## Troubleshooting

- `sudo: unable to resolve host localhost.localdomain: Name or service not known`: Add the following line to `/etc/hosts/`: `127.0.0.1 localhost.localdomain localhost`
- Check if website is reachable: `nslookup arvigeus.one` and `nslookup arvigeus.one 8.8.8.8` should return the same
- Check logs: `sudo docker container logs caddy`
- Some containers take a lot of time to boot, meanwhile they can return 404 (not found) or 502 (bad gateway) errors
- Check why site is not secure: <https://www.whynopadlock.com>
- Check if docker is working: `curl -H "Content-Type: application/json" --unix-socket /var/run/docker.sock http://localhost/_ping`
- Uncomment `DOZZLE_LEVEL: debug` in `docker-compose.yml`, then restart to see more detailed log
