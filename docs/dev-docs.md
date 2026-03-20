# Hub — Developer Documentation

This document covers developer workflows not included in the general README: adding new sub-applications, managing individual containers, working with volumes, and other day-to-day development tasks.

---

## Table of Contents

- [Project Structure](#project-structure)
- [Profiles](#profiles)
- [Adding a New Sub-Application](#adding-a-new-sub-application)
- [Working with Individual Containers](#working-with-individual-containers)
- [Volume Management](#volume-management)
- [Rebuilding After Code Changes](#rebuilding-after-code-changes)
- [Logs and Debugging](#logs-and-debugging)
- [Network Details](#network-details)

---

## Project Structure

```
hub/
├── compose.yml          # Root compose file — defines all services, volumes, network
├── Caddyfile            # Caddy reverse proxy routing rules
├── up.ps1               # Start hub (home profile)
├── up-work.ps1          # Start hub (work profile)
├── down.ps1             # Stop and remove all containers
├── MechBay/             # Sub-application (git submodule)
├── TimeTracker/         # Sub-application (git submodule)
├── waypoint/            # Sub-application (git submodule)
└── docs/                # Developer documentation
```

Each sub-application lives in its own subdirectory and has its own `Dockerfile`. The root `compose.yml` builds and wires them all together.

---

## Profiles

Profiles control which services start in a given environment. The `proxy` service always starts; sub-applications are assigned to profiles.

| Profile | Services started |
|---------|-----------------|
| `home`  | proxy, mechbay, waypoint, timetracker |
| `work`  | proxy, waypoint, timetracker |

Use `up.ps1` for the home profile and `up-work.ps1` for the work profile. To run a custom set of services, set the profile manually:

```powershell
$env:COMPOSE_PROFILES = 'home'
docker compose up -d --build
```

---

## Adding a New Sub-Application

### 1. Create the application directory

Add the application as a subdirectory (or git submodule) at the root of the hub:

```powershell
# As a new folder
mkdir MyApp

# Or add as a git submodule
git submodule add <repo-url> MyApp
```

### 2. Ensure the application has a Dockerfile

The application needs a `Dockerfile` in its root. The Caddy proxy expects the app to listen on port `5000` internally.

The application must also support a configurable `APPLICATION_ROOT` (subpath), typically via an environment variable and middleware such as Flask's `ProxyFix`.

### 3. Add the service to `compose.yml`

```yaml
services:
  myapp:
    build: ./MyApp
    expose:
      - "5000"
    environment:
      - APPLICATION_ROOT=/myapp
      # Add any other required env vars here
    volumes:
      - myapp-data:/data
    networks:
      - hub
    profiles: ['home']   # or ['work', 'home'] to include in both

volumes:
  myapp-data:            # Add a named volume for persistence
```

Keep the service name (e.g. `myapp`) short and lowercase — it doubles as the internal DNS hostname used by Caddy.

### 4. Add routing rules to `Caddyfile`

Add a no-trailing-slash redirect and a `handle` block. Copy the pattern used by the existing apps:

```caddy
@myapp_noslash path /myapp
redir @myapp_noslash /myapp/ 308

handle /myapp/* {
  uri strip_prefix /myapp
  reverse_proxy myapp:5000 {
    header_up X-Script-Name /myapp
    header_up X-Forwarded-Prefix /myapp
  }
}
```

The `X-Script-Name` and `X-Forwarded-Prefix` headers tell Flask (via `ProxyFix`) what subpath it is mounted at.

### 5. Rebuild and restart

```powershell
./up.ps1
```

Or if only testing the new service:

```powershell
docker compose --profile home up --build -d myapp
```

---

## Working with Individual Containers

All commands run from the `s:\hub` directory (where `compose.yml` lives).

### Stop a single container

```powershell
docker compose stop waypoint
```

The container is stopped but not removed, and its volume data is preserved.

### Stop and remove a single container

```powershell
docker compose rm -s waypoint
```

### Rebuild and restart a single container

```powershell
docker compose --profile home up --build -d waypoint
```

- `--build` forces a fresh image build, picking up any code changes.
- `-d` runs detached (background).
- Specifying the service name targets only that container; all others are unaffected.

### Restart without rebuilding

```powershell
docker compose restart waypoint
```

Use this when only environment variables or config files have changed and no new image build is needed.

### Check which containers are running

```powershell
docker compose ps
```

---

## Volume Management

Named volumes persist data across container stops, restarts, and rebuilds. Volumes are **not** removed by `down.ps1` (`docker compose down` without `--volumes`).

### List all hub volumes

```powershell
docker volume ls --filter name=hub
```

### Inspect a volume (find mount path)

```powershell
docker volume inspect hub_waypoint-data
```

> Volume names are prefixed with the compose project name (`hub_` by default).

### Back up a volume

```powershell
docker run --rm `
  -v hub_waypoint-data:/data `
  -v ${PWD}:/backup `
  alpine tar czf /backup/waypoint-backup.tar.gz -C /data .
```

### Restore a volume from backup

```powershell
docker run --rm `
  -v hub_waypoint-data:/data `
  -v ${PWD}:/backup `
  alpine tar xzf /backup/waypoint-backup.tar.gz -C /data
```

### Delete a volume (destructive — data loss)

Only do this when you want to wipe a service's data completely (e.g. to reset to a clean state):

```powershell
# Stop the relevant container first
docker compose stop waypoint

# Remove the volume
docker volume rm hub_waypoint-data
```

The volume will be recreated (empty) on the next `docker compose up`.

### Wipe all hub volumes

```powershell
docker compose down --volumes
```

This removes **all** named volumes defined in `compose.yml`. Use with caution.

---

## Rebuilding After Code Changes

| Scenario | Command |
|----------|---------|
| Rebuild one service | `docker compose --profile home up --build -d <service>` |
| Rebuild everything | `./up.ps1` |
| Force re-pull base images | `docker compose build --pull <service>` |
| Remove cached build layers | `docker compose build --no-cache <service>` |

---

## Logs and Debugging

### Tail logs for one service

```powershell
docker compose logs -f waypoint
```

### View recent logs for all services

```powershell
docker compose logs --tail=50
```

### Open a shell inside a running container

```powershell
docker compose exec waypoint sh
```

### Inspect environment variables inside a container

```powershell
docker compose exec waypoint env
```

---

## Network Details

All services are connected to a single bridge network named `hub`. Service names act as DNS hostnames within the network:

| Hostname      | Internal port | Description |
|---------------|--------------|-------------|
| `proxy`       | 80           | Caddy reverse proxy (only port published to host) |
| `mechbay`     | 5000         | MechBay Flask app |
| `waypoint`    | 5000         | Waypoint Flask app |
| `timetracker` | 5000         | TimeTracker Flask app |

Only port `80` on the `proxy` service is published to the host. Sub-application ports are exposed to the internal network only (`expose:` not `ports:`), so they are not directly reachable from the host machine.

To inspect the network:

```powershell
docker network inspect hub_hub
```
