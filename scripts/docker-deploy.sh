#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-whiteboard:latest}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Deploying ${IMAGE}..."

log "Running database migrations..."
docker compose -f docker-compose.yml run --rm whiteboard /app/bin/migrate

log "Stopping old containers..."
docker compose -f docker-compose.yml down

log "Starting new containers..."
docker compose -f docker-compose.yml up -d

log "Waiting for health check..."
sleep 5

if docker ps | grep -q whiteboard; then
  log "Deployment successful!"
  log "Container is running"
  docker compose -f docker-compose.yml ps
else
  log "ERROR: Deployment failed!"
  log "Container logs:"
  docker compose -f docker-compose.yml logs whiteboard
  exit 1
fi
