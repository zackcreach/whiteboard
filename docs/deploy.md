# Symphony Deployment

Whiteboard is an immutable Nix Mix release managed by `whiteboard-native.service`. It connects to the NixOS-managed PostgreSQL 18.4 cluster through `/run/postgresql` as `whiteboard_prod`.

## Deploy

Push the application commit, then update and activate its pinned input from `/etc/nixos`:

```bash
nix flake update whiteboard
nix build .#nixosConfigurations.symphony.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#symphony
```

The systemd dependency runs `whiteboard-native-migrate.service` before the application starts. A failed build or migration prevents the new release from replacing the working generation.

## Operations

```bash
systemctl status whiteboard-native
journalctl -u whiteboard-native --follow
sudo systemctl restart whiteboard-native
curl --fail https://whiteboard.prominent.tools
```

## Database and backups

```bash
sudo -u postgres psql whiteboard_prod
systemctl status postgresql
systemctl status postgresqlBackup-whiteboard_prod.timer
sudo systemctl start postgresqlBackup-whiteboard_prod.service
journalctl -u postgresqlBackup-whiteboard_prod.service
```

Backups are compressed SQL dumps under `/var/backup/postgresql/symphony` on Biltmore. Restore tests must use an isolated database, never `whiteboard_prod`.

## Rollback

Use the previous NixOS generation for an application rollback. The pre-cutover Docker database container and named volume are retained only during the temporary migration rollback window and must not receive new production writes.
