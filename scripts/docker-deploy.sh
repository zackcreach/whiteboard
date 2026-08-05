#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-whiteboard:latest}"
EXPECTED_POSTGRES_MAJOR="18"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Deploying ${IMAGE}..."

if ! docker inspect whiteboard_db >/dev/null 2>&1; then
  log "ERROR: whiteboard_db is not running; routine deployment will not create the database"
  log "Start the database deliberately or follow the retained PostgreSQL upgrade runbook"
  exit 1
fi

running_version_number=$(docker exec whiteboard_db psql -U postgres -d whiteboard_prod -Atqc "SHOW server_version_num")
running_postgres_major="${running_version_number:0:2}"

if [[ "$running_postgres_major" != "$EXPECTED_POSTGRES_MAJOR" ]]; then
  log "ERROR: configured PostgreSQL major ${EXPECTED_POSTGRES_MAJOR} differs from running major ${running_postgres_major}"
  log "Automatic deployment is stopped; follow the retained PostgreSQL upgrade runbook"
  exit 1
fi

log "Running database migrations..."
docker compose -f docker-compose.yml run --rm --no-deps whiteboard /app/bin/migrate

log "Recreating the application container..."
docker compose -f docker-compose.yml up -d --no-deps --force-recreate whiteboard

log "Waiting for health check..."
for attempt in {1..30}; do
  health_status=$(docker inspect whiteboard --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}')

  if [[ "$health_status" == "healthy" ]]; then
    break
  fi

  if [[ "$health_status" == "unhealthy" || "$attempt" == "30" ]]; then
    log "ERROR: Deployment failed with application status ${health_status}"
    docker compose -f docker-compose.yml logs whiteboard
    exit 1
  fi

  sleep 2
done

if [[ "$(docker inspect whiteboard --format='{{.State.Health.Status}}')" == "healthy" ]]; then
  log "Deployment successful!"
  log "Container is running"
  docker compose -f docker-compose.yml ps
else
  log "ERROR: Deployment failed!"
  log "Container logs:"
  docker compose -f docker-compose.yml logs whiteboard
  exit 1
fi
