# Self-Hosted Infrastructure

A modular self-hosted setup using Docker Compose with automated service management and reverse proxy configuration.

## Architecture

### Modular Service Structure

```
services/                    # Active services
├── caddy/          [Docker] # Reverse proxy with auto-config
├── homer/          [Docker] # Dashboard with auto-generation
├── cockpit/        [Scripts]# System management (systemd service)
├── nextcloud/      [Caddy]  # External service redirects
└── ... (other services)

disabled/                    # Disabled services
├── jellyfin/               # Media server (disabled)
├── joplin/                 # Notes app (disabled)
└── mealie/                 # Recipe manager (disabled)
```

### Service Types

- **[Docker]**: Containerized services with docker-compose.yml (may also have scripts)
- **[Scripts]**: System services managed only via start.sh/stop.sh
- **[Caddy]**: External services with only reverse proxy config
- **[Mixed]**: Docker services with additional start.sh/stop.sh scripts

## Quick Start

### Initial Setup

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your domain and settings

# 2. Install system dependencies
./setup.sh

# 3. Start all services
./run.sh start

# 4. Post-installation configuration (optional)
./post-setup.sh
```

### Service Management

```bash
# All services
./run.sh start                    # Start all active services
./run.sh stop                     # Stop all services
./run.sh restart                  # Restart all services
./run.sh update                   # Update all services
./run.sh status                   # Show service status

# Individual services
./run.sh start caddy homer        # Start specific services
./run.sh stop vaultwarden         # Stop specific service

# Enable/disable services
mv services/jellyfin disabled/    # Disable service
mv disabled/joplin services/      # Enable service
```

## Key Features

### Automated Configuration

- **Homer Dashboard**: Auto-generates from service `data.json` files
- **Caddy Reverse Proxy**: Auto-imports service-specific configurations
- **URL Auto-Detection**: Extracts URLs from Caddy configs automatically
- **Logo Management**: Auto-copies and organizes service icons

### Service Discovery

- **Plug-and-Play**: Add services by creating folders with configs
- **Auto-Detection**: Scripts discover and configure services automatically
- **Mixed Types**: Supports Docker containers, system services, and external apps

### CI/CD Integration

- **GitHub Actions**: Auto-deploys on service changes
- **Smart Restart**: Only restarts services when `services/` directory changes
- **Git Safety**: Validates repository state before deployment

## Adding New Services

### Docker Service

```bash
# 1. Create service directory
mkdir services/myservice

# 2. Create docker-compose.yml
cat > services/myservice/docker-compose.yml << EOF
services:
  myservice:
    image: myservice/myservice:latest
    container_name: myservice
    restart: unless-stopped
    volumes:
      - \${DATA}/myservice:/data
networks:
  default:
    external: true
    name: \${DOCKER_NETWORK}
EOF

# 3. Create Caddy configuration
cat > services/myservice/caddy.conf << EOF
myservice.\{\$DOMAIN\} {
    reverse_proxy myservice:8080
    tls {
        dns hetzner \{\$HETZNER_API_TOKEN\}
    }
}
EOF

# 4. Create Homer configuration
cat > services/myservice/data.json << EOF
{
  "ui": [
    {
      "name": "My Service",
      "subtitle": "Service description",
      "category": "Productivity",
      "order": 1
    }
  ]
}
EOF

# 5. Start the service
./run.sh start myservice
```

### Script-Only Service

```bash
# 1. Create service directory
mkdir services/myservice

# 2. Create start script
cat > services/myservice/start.sh << EOF
#!/bin/bash
echo "Starting my service..."
sudo systemctl start myservice
EOF

# 3. Create stop script
cat > services/myservice/stop.sh << EOF
#!/bin/bash
echo "Stopping my service..."
sudo systemctl stop myservice
EOF

# 4. Make scripts executable and add to Homer
chmod +x services/myservice/{start,stop}.sh
# Add data.json and caddy.conf as needed
```

### Mixed Service (Docker + Scripts)

```bash
# 1. Create service directory with docker-compose.yml (as above)
mkdir services/myservice

# 2. Add docker-compose.yml and caddy.conf (as shown above)

# 3. Add custom start script for additional setup
cat > services/myservice/start.sh << EOF
#!/bin/bash
echo "Performing pre-start setup..."
# Custom initialization logic
sudo mkdir -p /custom/path
sudo chown \$PUID:\$PGID /custom/path
EOF

# 4. Add custom stop script for cleanup
cat > services/myservice/stop.sh << EOF
#!/bin/bash
echo "Performing cleanup..."
# Custom cleanup logic
sudo rm -rf /tmp/myservice-*
EOF

chmod +x services/myservice/{start,stop}.sh
```

## Configuration Files

### Environment Variables (.env)

```bash
DOMAIN=yourdomain.com           # Your domain
DATA=./data                     # Data directory path
CONFIG=./config                 # Config directory path
DOCKER_NETWORK=caddy_net        # Docker network name
HETZNER_API_TOKEN=your_token    # For DNS challenges
# ... (see .env.example for full list)
```

### Service Configuration (data.json)

```json
{
  "ui": [
    {
      "name": "Service Name",
      "subtitle": "Description",
      "category": "Entertainment|Productivity|System",
      "logo": "optional/path/to/logo.png",
      "url": "optional_direct_url",
      "order": 1
    }
  ]
}
```

## System Requirements

- **OS**: Debian 12 (or compatible Linux)
- **Docker**: Installed via setup.sh
- **Caddy**: Custom binary with Hetzner DNS plugin
- **Domain**: With DNS API access (Hetzner)
- **Ports**: 80, 443, 51820 (WireGuard)

## Debian Setup

### Initial System Configuration

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Create user with sudo privileges
sudo addgroup --system wheel
echo '%wheel ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers
sudo useradd -m -g wheel -s /bin/bash yourusername
sudo passwd yourusername

# Configure PAM for wheel group
sudo sed -i 's/^# auth.*pam_wheel.so/auth required pam_wheel.so/' /etc/pam.d/su

# Fix hostname resolution (if needed)
echo "127.0.0.1 localhost.localdomain localhost" | sudo tee -a /etc/hosts
```

### Unattended Upgrades

```bash
# Install unattended upgrades
sudo apt install unattended-upgrades apt-listchanges -y
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Configure automatic updates
echo 'APT::Periodic::Update-Package-Lists "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades

# Configure upgrade behavior
sudo tee /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Mail "your-email@domain.com";
Unattended-Upgrade::MailReport "only-on-error";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "false";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF
```

### Email Notifications (Optional)

```bash
# Install mail tools
sudo apt install msmtp msmtp-mta bsd-mailx -y

# Configure global SMTP settings (example for Gmail)
sudo bash -c 'cat > /etc/msmtprc << EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
#logfile        /var/log/msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           your-email@gmail.com
user           your-email@gmail.com
password       your-app-password

account default : gmail
EOF'

# Secure the config file
sudo chmod 600 /etc/msmtprc

# Test email
echo "Test message" | mail -s "Test from server" your-email@gmail.com
```

#### Email Notifications on low disk space

Create the monitoring script:

```sh
sudo cat > /usr/local/bin/check-disk-space.sh << 'EOF'
#!/bin/bash

EMAIL="your-email@gmail.com"
THRESHOLD=90

# Get filesystems over threshold
ALERT=$(df -h | grep -vE '^Filesystem|tmpfs|cdrom|udev|overlay' | awk -v threshold=$THRESHOLD '{
  usage = int($5);
  if (usage >= threshold) {
    print $6 " is at " $5 " capacity";
  }
}')

# Send email if any filesystem is over threshold
if [ -n "$ALERT" ]; then
  echo "Subject: [Alert] Disk Space Warning on $(hostname)

The following partitions are over ${THRESHOLD}% capacity:

$ALERT

Full disk usage:
$(df -h | grep -vE '^Filesystem|tmpfs|cdrom|udev|overlay')

Suggested actions:

    sudo systemctl stop docker
    sudo rm -rf /var/lib/docker
    sudo docker network create caddy_net
    sudo systemctl start docker
    ./run.sh start

---
Sent from $(hostname) at $(date)" | /usr/sbin/sendmail $EMAIL
fi
EOF
```

Make it executable:

```sh
sudo chmod +x /usr/local/bin/check-disk-space.sh
```

Create the cron job:

```sh
sudo cat > /etc/cron.d/check-disk-space << 'EOF'
# Check disk space daily at 8:00 AM
0 8 * * * root /usr/local/bin/check-disk-space.sh
EOF
```

## Updating PostgreSQL database

1. Stop container
1. Backup database somewhere else
1. Delete database dir
1. Dump old database and import it into the new db

```sh
docker exec -t <db-container> pg_dumpall -U <username> > backup.sql
cat backup.sql | docker exec -i <db-container> psql -U <username> -d <dbname>
rm backup.sql
```

## Troubleshooting

### Common Issues

```bash
# Check service status
./run.sh status

# View logs
docker logs caddy
docker logs servicename

# Check Caddy configuration
docker exec caddy caddy validate --config /etc/caddy/Caddyfile

# Test DNS resolution
nslookup yourdomain.com
nslookup subdomain.yourdomain.com

# Check Docker network
docker network ls
docker network inspect caddy_net
```

### Service Issues

- **404/502 errors**: Service may still be starting up
- **SSL issues**: Check DNS API token and domain configuration
- **Missing URLs**: Verify caddy.conf has correct subdomain pattern
- **Homer not updating**: Check data.json format and run `./run.sh restart homer`

### File Permissions

```bash
# Fix data directory permissions
sudo chown -R $PUID:$PGID ./data

# Fix service script permissions
chmod +x services/*/start.sh services/*/stop.sh
```

### Network and Connectivity

- **Hostname resolution**: Add `127.0.0.1 localhost.localdomain localhost` to `/etc/hosts` if getting hostname errors
- **DNS testing**: Use `nslookup yourdomain.com` and `nslookup yourdomain.com 8.8.8.8` - should return same results
- **SSL certificate issues**: Check <https://www.whynopadlock.com> for SSL problems
- **Docker connectivity**: Test with `curl -H "Content-Type: application/json" --unix-socket /var/run/docker.sock http://localhost/_ping`

### Service Startup Issues

- **404/502 errors**: Services may take time to start - check `docker logs servicename`
- **Port conflicts**: Ensure no other services are using ports 80, 443, 51820
- **Volume permissions**: Check that `$DATA` directory has correct ownership
- **Environment variables**: Verify `.env` file is properly formatted and sourced

### Advanced Debugging

```bash
# Enable detailed Caddy logging
# Uncomment DOZZLE_LEVEL: debug in dozzle service, then restart

# Check Caddy config syntax
docker exec caddy caddy validate --config /etc/caddy/Caddyfile

# View all container logs
docker logs --tail 50 caddy
docker logs --tail 50 servicename

# Check container resource usage
docker stats

# Inspect Docker networks
docker network inspect caddy_net

# Check disk space
df -h
du -sh ./data/*
```

### WebDAV Mounting

For mounting WebDAV shares, see: <https://sleeplessbeastie.eu/2017/09/04/how-to-mount-webdav-share/>
