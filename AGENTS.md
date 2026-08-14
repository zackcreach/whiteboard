# Whiteboard - Fitness Tracking Application

## Project Overview
Whiteboard is a Phoenix LiveView-based fitness tracking application that allows users to manage workouts, exercises, and sets. Users can create workouts, add exercises with weights and reps, track their progress, and duplicate previous workouts.

## Tech Stack
- **Backend**: Elixir 1.20.2 with Phoenix 1.8.9
- **Frontend**: Phoenix LiveView with TailwindCSS
- **Database**: PostgreSQL with Ecto
- **Development**: Nix flake environment
- **Runtime**: Erlang 29.0.4
- **Deployment**: Fly.io (fly.toml present)

## Key Development Commands

Use `nix develop -c mix setup` for a first checkout and `nix develop -c iex -S mix phx.server` for normal sessions. The Nix shell owns PostgreSQL 18 in `.direnv/postgresql-18`; use `nix develop -c dev-postgres status|stop` for lifecycle control. Docker Compose is only for container/release verification.

After changing Mix dependencies, run `nix run .#update-mix-deps`, commit `mix.lock` and `deps.nix` together, then run `nix flake check`.

### Setup & Running
```bash
mix setup                    # Install deps, setup DB, build assets
mix phx.server              # Start development server
iex -S mix phx.server       # Start server in IEx shell
```

### Database Management
```bash
mix ecto.setup              # Create, migrate, seed DB
mix ecto.reset              # Drop and recreate DB
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
```

### Testing
```bash
mix test                    # Run all tests (creates test DB first)
```

### Assets
```bash
mix assets.setup            # Install Tailwind & ESBuild
mix assets.build            # Build assets for development
mix assets.deploy           # Build minified assets for production
```

## Architecture Overview

### Core Contexts
- **Whiteboard.Training** (`lib/whiteboard/training.ex`): Main business logic context
- **Whiteboard.Training.Repo** (`lib/whiteboard/training/repo.ex`): Data access layer

### Database Schema
- **Workouts**: Main workout records with name, notes, timestamps
- **Exercises**: Individual exercises within workouts, linked to exercise names
- **Exercise Names**: Master list of exercise types
- **Exercise Categories**: Grouping for exercise names
- **Sets**: Individual sets with weight, reps, and notes

### LiveView Components
- **WorkoutLive** (`lib/whiteboard_web/live/workout_live.ex`): Main workout editing interface
- **ExerciseBrowser** (`lib/whiteboard_web/components/exercise_browser.ex`): Exercise selection component
- **Card** (`lib/whiteboard_web/components/card.ex`): Reusable card component

## Key Files for AI Reference

### Application Structure
- `lib/whiteboard.ex` - Main application module
- `lib/whiteboard/application.ex` - OTP application
- `mix.exs` - Project configuration and dependencies

### Web Layer
- `lib/whiteboard_web.ex` - Web module definitions
- `lib/whiteboard_web/router.ex` - Route definitions
- `lib/whiteboard_web/endpoint.ex` - Phoenix endpoint

### Database
- `priv/repo/migrations/` - Database migrations
- `priv/repo/seeds.exs` - Seed data
- `lib/whiteboard/repo.ex` - Main Ecto repo

### Configuration
- `config/` - Application configuration files
- `flake.nix` - Nix development environment
- `assets/css/app.css` - Tailwind CSS-first configuration

## Development Environment

### Nix Setup
The project uses a Nix flake for consistent development environments:
- Elixir 1.20.2
- Erlang 29.0.4
- Node.js 24.18.1
- PostgreSQL 18.4
- Language servers (Lexical, TypeScript, Tailwind)

### Dependencies
Key Elixir dependencies:
- Phoenix & LiveView for web framework
- Ecto & Postgrex for database
- ExMachina for test factories
- Heroicons for UI icons
- Tailwind for styling

## Common Development Tasks

### Adding New Features
1. Create/update schema in `lib/whiteboard/training/`
2. Add database migrations in `priv/repo/migrations/`
3. Update business logic in `lib/whiteboard/training.ex`
4. Add/update LiveView components in `lib/whiteboard_web/live/`
5. Run tests with `mix test`

### Database Changes
1. Generate migration: `mix ecto.gen.migration migration_name`
2. Edit migration file
3. Run migration: `mix ecto.migrate`
4. Update seeds if needed

### Testing Strategy
- Unit tests for business logic
- Integration tests for LiveView components
- Test factories using ExMachina in `test/support/factories/`

## Deployment
- Uses Fly.io for deployment (`fly.toml` configuration)
- Assets are built and digested for production
- Database runs on PostgreSQL

## URLs & Access
- Development: http://localhost:4000
- Uses Phoenix LiveDashboard for monitoring

## Notes for AI Assistants
- Always run `mix test` after making changes
- Use existing patterns from the codebase
- Database changes require migrations
- LiveView uses form-based interactions with phx-change/phx-submit
- UI uses TailwindCSS classes extensively
- Follow Elixir/Phoenix conventions for naming and structure
