# Whiteboard

Fitness tracking application to keep track of workouts > exercises > sets per user

## Features

- Create and manage workouts
- Add exercises with weights and reps
- Track progress over time
- Duplicate previous workouts for easy planning
- Real-time updates with LiveView

## Development

To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### Docker with Colima

The Nix dev shell includes Docker CLI, Docker Compose, and Colima on macOS. Start the project Colima profile before running Compose:

```bash
nix develop
colima start whiteboard-qemu --runtime docker --kubernetes=false --mount-inotify=false --vm-type qemu --mount-type 9p --cpu 4 --memory 6 --disk 60
docker compose ps
```

## Deployment

Whiteboard uses Docker-based deployment with automated continuous deployment. When you push to the main branch, changes are automatically deployed to production within 5 minutes.

For detailed deployment documentation, including how to access logs, IEx console, and the database, see **[docs/deploy.md](docs/deploy.md)**.

### Quick Deployment Commands

```bash
# View running containers
docker compose ps

# View application logs
docker compose logs whiteboard -f

# Access IEx console
docker exec -it whiteboard /app/bin/whiteboard remote

# Access database
docker exec -it whiteboard_db psql -U postgres -d whiteboard_prod

# Trigger manual deployment
sudo systemctl start whiteboard-deploy
```
