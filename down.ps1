docker compose down
docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -like 'hub-*' } | ForEach-Object { docker rmi $_ }
