# Deployment Documentation

## Overview

Whiteboard uses a Docker-based deployment system with automated continuous deployment. When you push code to the main branch, it automatically deploys to production within 5 minutes.

## Architecture

### Components

- **Docker Compose**: Orchestrates the application and PostgreSQL database containers
- **NixOS systemd services**: Manages the Docker containers and automated deployments
- **Git-based versioning**: Each deployment creates a Docker image tagged with the git commit hash

### Services

#### whiteboard.service
Main application service that manages the Docker Compose stack.

```bash
systemctl status whiteboard       # Check service status
sudo systemctl restart whiteboard # Restart the stack
```

#### whiteboard-deploy.timer
Runs every 5 minutes to check for new commits and deploy automatically.

```bash
systemctl status whiteboard-deploy.timer  # Check timer status
systemctl list-timers whiteboard-deploy.timer  # See next trigger time
sudo systemctl start whiteboard-deploy   # Trigger manual deployment
```

#### whiteboard-backup.timer
Creates daily database backups at 03:00.

```bash
systemctl status whiteboard-backup.timer  # Check timer status
sudo systemctl start whiteboard-backup    # Trigger manual backup
```

## Deployment Workflow

### Automatic Deployment

1. Push code to the main branch on GitHub
2. Within 5 minutes, the timer triggers
3. Service fetches from origin and detects new commits
4. Builds Docker image tagged with commit hash
5. Runs database migrations
6. Gracefully stops old containers
7. Starts new containers with health checks
8. Deployment complete (typically 30-60 seconds)

### Manual Deployment

You can also trigger deployments manually:

```bash
# From anywhere
sudo systemctl start whiteboard-deploy

# From the project directory
mix deploy
```

Force deployment even without new commits:

```bash
mix deploy --force
```

## Docker Operations

### Container Management

```bash
# View running containers
docker compose ps

# View all container details
docker ps -a

# Check container health
docker inspect whiteboard --format='{{.State.Health.Status}}'
docker inspect whiteboard_db --format='{{.State.Health.Status}}'

# Restart containers
docker compose restart whiteboard
docker compose restart

# Stop and start containers
docker compose down
docker compose up -d

# Rebuild and restart
./scripts/docker-build.sh
docker compose up -d
```

### Viewing Logs

```bash
# Follow application logs
docker compose logs whiteboard -f

# Follow database logs
docker compose logs whiteboard_db -f

# Follow all logs
docker compose logs -f

# View last 100 lines
docker compose logs whiteboard --tail=100

# View logs since a specific time
docker compose logs whiteboard --since="1h"
docker compose logs whiteboard --since="2025-11-22T20:00:00"
```

### Accessing IEx Console

To get an interactive Elixir shell (IEx) inside the running container:

```bash
# Connect to remote IEx console (recommended)
docker exec -it whiteboard /app/bin/whiteboard remote

# Start a new IEx session (alternative)
docker exec -it whiteboard /app/bin/whiteboard rpc "Application.started_applications()"

# For general shell access
docker exec -it whiteboard sh
```

Inside IEx, you can interact with your application:

```elixir
# List all running applications
Application.started_applications()

# Get application environment
Application.get_all_env(:whiteboard)

# Run database queries
Whiteboard.Repo.all(Whiteboard.Training.Workout)

# Call functions from your modules
Whiteboard.Training.list_workouts()
```

### Database Access

#### PostgreSQL Console (psql)

```bash
# Access database with psql
docker exec -it whiteboard_db psql -U postgres -d whiteboard_prod

# Run a single query
docker exec -it whiteboard_db psql -U postgres -d whiteboard_prod -c "SELECT COUNT(*) FROM workouts;"

# Execute SQL file
docker exec -i whiteboard_db psql -U postgres -d whiteboard_prod < query.sql
```

Inside psql:

```sql
-- List all tables
\dt

-- Describe a table
\d workouts

-- Show table sizes
\dt+

-- Run queries
SELECT COUNT(*) FROM workouts;
SELECT COUNT(*) FROM exercises;
SELECT COUNT(*) FROM sets;

-- Exit
\q
```

#### Database Backups

Backups are automatically created daily at 03:00 and stored in:
```
/home/zack/dev/whiteboard/creachignore/db_backups/
```

Manual backup:

```bash
# Create backup
docker exec whiteboard_db pg_dump -U postgres whiteboard_prod | gzip > backup-$(date +%Y-%m-%d).sql.gz

# Or trigger the backup service
sudo systemctl start whiteboard-backup
```

Restore from backup:

```bash
# Restore from gzipped backup
gunzip -c backup-2025-11-22.sql.gz | docker exec -i whiteboard_db psql -U postgres -d whiteboard_prod

# Restore from plain SQL
docker exec -i whiteboard_db psql -U postgres -d whiteboard_prod < backup.sql
```

## Monitoring

### Service Logs

```bash
# Watch deployment logs in real-time
journalctl -u whiteboard-deploy -f

# View recent deployment logs
journalctl -u whiteboard-deploy --since "1 hour ago"

# View specific deployment
journalctl -u whiteboard-deploy --since "2025-11-22 21:00:00" --until "2025-11-22 21:10:00"

# Check backup logs
journalctl -u whiteboard-backup --since "today"
```

### Health Checks

The application has built-in health checks that run every 30 seconds:

```bash
# Check if containers are healthy
docker compose ps

# Detailed health status
docker inspect whiteboard --format='{{json .State.Health}}' | jq

# Test health endpoint manually
curl http://localhost:4000
```

### Resource Usage

```bash
# View container resource usage
docker stats whiteboard whiteboard_db

# View disk usage
docker system df

# View image sizes
docker images whiteboard
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs for errors
docker compose logs whiteboard --tail=100

# Check health status
docker inspect whiteboard --format='{{json .State.Health}}' | jq

# Verify database is healthy
docker inspect whiteboard_db --format='{{.State.Health.Status}}'

# Try restarting
docker compose restart whiteboard
```

### Database Connection Issues

```bash
# Check if database is running
docker compose ps whiteboard_db

# Test database connectivity
docker exec whiteboard_db pg_isready -U postgres

# Check database logs
docker compose logs whiteboard_db --tail=50

# Verify DNS resolution inside container
docker exec whiteboard ping -c 3 db
```

### Deployment Failures

```bash
# Check deployment logs
journalctl -u whiteboard-deploy --since "10 minutes ago"

# Verify git connectivity
cd /home/zack/dev/whiteboard && git fetch origin

# Check Docker service
systemctl status docker

# Try manual deployment with verbose output
mix deploy
```

### Rolling Back

Each deployment creates a tagged Docker image. To rollback:

```bash
# List available images
docker images whiteboard

# Update docker-compose.yml to use specific tag
# Change: image: whiteboard:latest
# To: image: whiteboard:<commit-hash>

# Restart with old version
docker compose down
docker compose up -d

# Or rebuild from a specific commit
git checkout <previous-commit>
./scripts/docker-build.sh
docker compose up -d
git checkout main
```

## Image Management

### Listing Images

```bash
# View all whiteboard images
docker images whiteboard

# View with full details
docker images whiteboard --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}"
```

### Cleaning Up Old Images

Docker images accumulate over time. Clean them up periodically:

```bash
# Remove unused images (keeps last 3 versions)
docker images whiteboard --format "{{.Tag}}" | tail -n +4 | xargs -I {} docker rmi whiteboard:{}

# Remove all dangling images
docker image prune

# Remove all unused images
docker image prune -a
```

## Configuration

### Environment Variables

Environment variables are configured in `/home/zack/dev/whiteboard/.env`:

- `SECRET_KEY_BASE`: Phoenix secret key
- `GITHUB_TOKEN`: GitHub authentication token
- `DATABASE_URL`: PostgreSQL connection string
- `PHX_HOST`: Host used for generated Phoenix URLs
- `PHX_SCHEME`: External URL scheme, usually `http` or `https`
- `PHX_PORT`: External URL port, usually `4000` for direct HTTP or `443` for HTTPS
- `PHX_CHECK_ORIGIN`: Comma-separated websocket origins allowed by Phoenix

To update:

```bash
# Edit environment file
nano /home/zack/dev/whiteboard/.env

# Restart services
sudo systemctl restart whiteboard
```

For a friend-facing HTTPS Tailscale URL, set Phoenix to trust that websocket origin:

```bash
PHX_HOST=symphony.your-tailnet.ts.net
PHX_SCHEME=https
PHX_PORT=443
PHX_CHECK_ORIGIN=https://symphony.your-tailnet.ts.net,http://symphony:4000,http://localhost:4000,//*.ts.net
```

### Docker Compose Configuration

The `docker-compose.yml` file defines:
- Service definitions
- Port mappings
- Health checks
- Volume mounts
- Network configuration

To modify, edit `docker-compose.yml` and restart:

```bash
docker compose down
docker compose up -d
```

## Performance

### Typical Deployment Times

- **No changes detected**: ~1.5 seconds
- **Full deployment**: 30-60 seconds
  - Docker build: 10-20 seconds (mostly cached)
  - Container restart: 20-30 seconds
  - Health check validation: 5-10 seconds

### Resource Requirements

- **Application container**: ~50-100MB RAM
- **Database container**: ~50-100MB RAM
- **Docker images**: ~134MB per version

## Quick Reference

```bash
# View application
curl http://localhost:4000

# Watch logs
docker compose logs -f

# Access IEx
docker exec -it whiteboard /app/bin/whiteboard remote

# Access database
docker exec -it whiteboard_db psql -U postgres -d whiteboard_prod

# Trigger deployment
sudo systemctl start whiteboard-deploy

# View deployment logs
journalctl -u whiteboard-deploy -f

# Check container health
docker compose ps

# Restart everything
docker compose restart
```
