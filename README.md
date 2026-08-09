# Whiteboard

Fitness tracking application to keep track of workouts > exercises > sets per user

Built with Phoenix 1.8.9 and LiveView 1.2.8 on Elixir 1.20.2, OTP 29.0.4, Node.js 24.18.1, and PostgreSQL 18.4.

## Features

- Create and manage workouts
- Add exercises with weights and reps
- Track progress over time
- Duplicate previous workouts for easy planning
- Real-time updates with LiveView

## Development

To start your Phoenix server:

```bash
nix develop
mix setup
iex -S mix phx.server
```

The Nix development shell provides the pinned Erlang, Elixir, Node, PostgreSQL client, and asset tooling. A PostgreSQL server must be running locally.

Without Nix, use [`flake.nix`](flake.nix) as the source of truth for tool versions and install matching Erlang, Elixir, Node, PostgreSQL, and asset tooling with mise, asdf, or equivalent tooling before running `mix setup`.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Deployment

Whiteboard is built as an immutable Nix Mix release and runs as `whiteboard-native.service` on Symphony. PostgreSQL 18.4 is managed by NixOS and accessed through `/run/postgresql`.

Deployments are intentional NixOS generation updates rather than automatic application rebuilds. See **[docs/deploy.md](docs/deploy.md)** for deployment, logs, database, backup, and rollback operations.

### Quick Deployment Commands

```bash
systemctl status whiteboard-native
journalctl -u whiteboard-native -f
curl --fail https://whiteboard.prominent.tools
```
