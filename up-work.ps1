$env:COMPOSE_PROFILES = 'work'
$env:MECHBAY_VERSION     = python -c "import tomllib; v=tomllib.load(open('./MechBay/pyproject.toml','rb')); print(v['project']['version'])"
$env:WAYPOINT_VERSION    = python -c "import tomllib; v=tomllib.load(open('./waypoint/pyproject.toml','rb')); print(v['project']['version'])"
$env:TIMETRACKER_VERSION = python -c "import tomllib; v=tomllib.load(open('./TimeTracker/pyproject.toml','rb')); print(v['project']['version'])"
Write-Host "mechbay:$env:MECHBAY_VERSION  waypoint:$env:WAYPOINT_VERSION  timetracker:$env:TIMETRACKER_VERSION"
docker compose up -d --build