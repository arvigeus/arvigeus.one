# Migration to Modular Structure

## What Changed

Your self-hosted setup has been refactored from a monolithic structure to a modular one:

### Before:
- Single `docker-compose.yml` with all services
- Single `config/caddy/Caddyfile` with all routes
- All configurations mixed together

### After:
```
services/
├── caddy/                    # Core reverse proxy
│   ├── docker-compose.yml
│   ├── caddy.conf           # System routes & redirects
│   └── config/
├── homer/                   # Dashboard service
│   ├── docker-compose.yml
│   ├── caddy.conf          # Homer-specific routes
│   └── config/
├── vaultwarden/            # Password manager
│   ├── docker-compose.yml
│   └── caddy.conf
├── miniflux/               # RSS reader + database
│   ├── docker-compose.yml
│   └── caddy.conf
├── _joplin/                # DISABLED service (prefix with _)
│   ├── docker-compose.yml
│   └── caddy.conf
└── ... (all other services)
```

## Key Benefits

1. **True Modularity**: Each service is completely self-contained
2. **Easy Enable/Disable**: Rename folder to start with `_` to disable
3. **Cleaner Separation**: Related services (app + database) stay together
4. **Better Maintainability**: Update individual services independently
5. **Industry Standard**: Follows Docker Compose best practices

## How to Use

### Start All Services
```bash
./run.sh start
```

### Stop All Services
```bash
./run.sh stop
```

### Check Status
```bash
./run.sh status
```

### Enable/Disable Services
```bash
# Disable a service
mv services/jellyfin services/_jellyfin

# Enable a service
mv services/_joplin services/joplin
```

### Update All Services
```bash
./run.sh update
```

## Important Notes

1. **Backups Created**: Your original files are backed up as:
   - `docker-compose.yml.backup`
   - `config/caddy/Caddyfile.backup`

2. **Caddy Configuration**: The main Caddyfile now imports all service-specific configs automatically

3. **Dependencies**: Services with databases (like miniflux, planka, joplin) are kept together in the same compose file

4. **Disabled Services**: Services prefixed with `_` are disabled and won't start

## Testing the Migration

1. Make sure you have a `.env` file (copy from `.env.example`)
2. Test with: `./run.sh status`
3. Start services: `./run.sh start`
4. Check logs: `docker logs caddy`

## Rollback (if needed)

If you need to rollback:
```bash
cp docker-compose.yml.backup docker-compose.yml
cp config/caddy/Caddyfile.backup config/caddy/Caddyfile
```