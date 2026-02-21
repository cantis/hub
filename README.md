# Hub
My first attempt at a containerized application hub using Caddy as a reverse proxy. This project serves as a central gateway to access multiple web applications from a single localhost endpoint.

## Architecture

- **Caddy**: Reverse proxy server handling HTTP routing and path-based redirection
- **MechBay**: BattleTech miniature inventory manager accessible at `/mechbay`
- **TimeTracker**: Time tracking application accessible at `/timetracker`
- **Waypoint**: Contact management application accessible at `/waypoint`

All services run in isolated Docker containers connected via a shared bridge network. Data is persisted using named Docker volumes, so it survives container restarts and rebuilds.

## Prerequisites

- Docker Desktop (or Docker Engine + Docker Compose)
- PowerShell (for Windows scripts)

## Quick Start

### Starting the Hub

```powershell
./up.ps1
```

This command:
- Builds all Docker images
- Starts all containers in detached mode
- Creates necessary networks

### Stopping the Hub

```powershell
./down.ps1
```

This command:
- Stops all running containers
- Removes containers
- **Preserves data volumes** for persistence across restarts

## Accessing Applications

Once the hub is running, access applications at:

- **Hub Landing**: http://localhost/
- **MechBay**: http://localhost/mechbay/
- **TimeTracker**: http://localhost/timetracker/
- **Waypoint**: http://localhost/waypoint/

Each application handles authentication independently. Default admin credentials are configured within each application's documentation.

## Configuration

### Caddyfile

The `Caddyfile` defines routing rules:
- Strips path prefixes before forwarding to applications
- Adds proxy headers (`X-Script-Name`, `X-Forwarded-Prefix`) for Flask path awareness
- Redirects paths without trailing slashes

### Docker Compose

The `compose.yml` file defines:
- Service configurations for proxy, mechbay, timetracker, and waypoint
- Network topology (bridge network named `hub`)
- Environment variables for application root paths
- Named volumes for data persistence:
  - `mechbay-data`: MechBay database
  - `waypoint-data`: Waypoint database
  - `timetracker-data` & `timetracker-instance`: TimeTracker database and instance files

### Application Configuration

Each application is configured with:
- `APPLICATION_ROOT` environment variable specifying its subpath
- `ProxyFix` middleware to handle reverse proxy headers correctly
- Port 5000 exposed internally (not published to host)

## Troubleshooting

### Containers won't start
```powershell
docker compose logs
```

### Application shows blank page
- Verify containers are running: `docker compose ps`
- Check application logs: `docker compose logs [mechbay|waypoint|timetracker]`
- Ensure applications finished initialization (migrations, seeding)

### Port 80 already in use
Stop any services using port 80, or modify the `compose.yml` to use a different host port:
```yaml
proxy:
  ports:
    - "8080:80"  # Change 80 to 8080 or another available port
```

## Development

### Rebuilding After Changes

```powershell
./down.ps1
./up.ps1
```

### Accessing Container Logs

```powershell
# All services
docker compose logs -f

# Specific service
docker compose logs -f [proxy|mechbay|timetracker|waypoint]
```

### Executing Commands in Containers

```powershell
docker compose exec [service-name] [command]

# Examples
docker compose exec mechbay uv run python
docker compose exec waypoint uv run flask shell
docker compose exec timetracker sh
```

## License

Each application maintains its own license. See individual application directories for details.
