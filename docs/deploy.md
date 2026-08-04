# Symphony Deployment

Whiteboard runs as two Docker Compose services on Symphony. PostgreSQL has an independent lifecycle from routine application deployment. Automatic deployment must never create, recreate, stop, or remove the database service or its volume.

## Services

- `whiteboard.service` starts the Compose stack at boot and stops only the application when the unit is stopped.
- `whiteboard-deploy.timer` checks `origin/main` every five minutes and invokes `mix deploy` with Elixir 1.20.2 on OTP 29.0.4.
- `whiteboard-backup.timer` creates a validated PostgreSQL custom-format backup every day at 03:00.

```bash
systemctl status whiteboard
systemctl status whiteboard-deploy.timer
systemctl status whiteboard-backup.timer
systemctl list-timers whiteboard-deploy.timer whiteboard-backup.timer
```

## Routine deployment

The deploy task fetches `origin/main`, builds `whiteboard:<commit>` and `whiteboard:latest`, verifies that the running database is PostgreSQL 18, runs migrations with `docker compose run --rm --no-deps`, and force-recreates only `whiteboard`.

```bash
sudo systemctl start whiteboard-deploy.service
mix deploy --force
```

If the configured and running PostgreSQL major versions differ, deployment aborts and directs the operator to the retained PostgreSQL upgrade runbook. Do not bypass this guard.

## Application operations

```bash
docker compose ps
docker compose logs --follow whiteboard
docker inspect whiteboard --format '{{.State.Health.Status}}'
docker compose restart whiteboard
docker compose stop whiteboard
docker compose up -d --no-deps whiteboard
docker exec -it whiteboard /app/bin/whiteboard remote
```

Do not use `docker compose down` during deployment or application troubleshooting. It includes the database in its target set.

## Database operations

```bash
docker compose logs --follow db
docker inspect whiteboard_db --format '{{.State.Health.Status}}'
docker exec whiteboard_db pg_isready -U postgres -d whiteboard_prod
docker exec -it whiteboard_db psql -U postgres -d whiteboard_prod
docker inspect whiteboard_db --format '{{range .Mounts}}{{println .Name .Destination}}{{end}}'
```

PostgreSQL 18 uses the explicit `whiteboard_postgres18_data` volume mounted at `/var/lib/postgresql`. The previous PG16 volume must not be renamed, reused by PG18, or removed until the retention gate in the upgrade runbook has passed and deletion is explicitly approved.

## Backups and restore

Backups are stored in `creachignore/db_backups/` as timestamped `.dump` files with `.sha256` sidecars. The service writes to a temporary file, rejects empty or unreadable archives using `pg_restore --list`, then atomically publishes the dump and checksum.

```bash
sudo systemctl start whiteboard-backup.service
journalctl -u whiteboard-backup.service --since today
cd creachignore/db_backups
sha256sum --check whiteboard_prod_TIMESTAMP.dump.sha256
docker exec -i whiteboard_db pg_restore --list < whiteboard_prod_TIMESTAMP.dump
```

Use the routine restore and disposable-restore procedure in the retained PostgreSQL upgrade runbook. Never test a restore over the production database.

## Monitoring and rollback

```bash
journalctl -u whiteboard-deploy.service --follow
docker compose logs --tail=100 whiteboard
docker compose logs --tail=100 db
docker stats whiteboard whiteboard_db
curl --fail http://localhost:4000
```

Every build retains a commit-tagged image. Application-only rollback recreates `whiteboard` with the previous tag while retaining PostgreSQL 18. Database rollback rules differ before and after PG18 receives public writes and are defined in the upgrade runbook.
