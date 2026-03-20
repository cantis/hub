param(
	[switch]$Force
)

if ($Force) {
	Write-Host "Force mode: stopping/removing containers only (volumes preserved)..."

	# Hard-stop running containers in this compose project.
	docker compose kill

    Write-Host ""

	# Force-remove project containers; preserve named volumes.
	docker compose rm -f -s
}

# Always keep data volumes intact unless explicitly removed elsewhere.
$downOutput = docker compose down --remove-orphans 2>&1
$downExitCode = $LASTEXITCODE

$downOutput | ForEach-Object { Write-Host $_ }

if ($downExitCode -ne 0) {
	$downText = ($downOutput -join "`n")
	if ($downText -match "Network .* Resource is still in use") {
		Write-Warning "Compose resources were removed, but the compose network is still attached to another container. Volumes were not removed."
		exit 0
	}

	exit $downExitCode
}
