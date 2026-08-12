{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs.lib) optional optionals;

        beamBuilder = pkgs.beamMinimal29Packages.extend (
          _final: previous: {
            elixir = previous.elixir_1_20;
          }
        );

        elixir = beamBuilder.elixir_1_20;
        releaseSource = ./.;
        releaseVersion = "0.1.0";
        releaseDependencies = beamBuilder.fetchMixDeps {
          pname = "whiteboard-mix-deps";
          version = releaseVersion;
          src = releaseSource;
          hash = "sha256-Pzey2DSxqxl9HkuFCVZ2Rlx2D1GfsZTnxpyxKNaixPw=";
        };
        devPostgres = pkgs.writeShellApplication {
          name = "dev-postgres";
          runtimeInputs = [ pkgs.postgresql_18_jit ];
          text = ''
            root_dir="''${DEV_POSTGRES_ROOT_DIR:-$PWD/.direnv/postgresql-18}"
            data_dir="$root_dir/data"
            socket_dir="$root_dir/socket"

            case "''${1:-}" in
              start)
                mkdir -p "$data_dir" "$socket_dir"
                chmod 700 "$data_dir" "$socket_dir"
                if [[ ! -s "$data_dir/PG_VERSION" ]]; then
                  initdb --pgdata="$data_dir" --username=postgres --auth=trust
                fi
                if pg_ctl --pgdata="$data_dir" status >/dev/null 2>&1; then
                  echo "PostgreSQL is already running"
                else
                  pg_ctl --pgdata="$data_dir" --log="$data_dir/postgresql.log" \
                    --options="-c listen_addresses= -c unix_socket_directories='$socket_dir'" start
                fi
                ;;
              stop)
                pg_ctl --pgdata="$data_dir" stop
                ;;
              status)
                pg_ctl --pgdata="$data_dir" status
                ;;
              *)
                echo "Usage: dev-postgres start|stop|status" >&2
                exit 2
                ;;
            esac
          '';
        };
      in
      with pkgs;
      {
        packages.default = beamBuilder.mixRelease {
          pname = "whiteboard";
          version = releaseVersion;
          src = releaseSource;
          mixFodDeps = releaseDependencies;
          MIX_ESBUILD_PATH = "${esbuild}/bin/esbuild";
          MIX_TAILWIND_PATH = "${tailwindcss_4}/bin/tailwindcss";
          postBuild = ''
            mix do deps.loadpaths --no-deps-check + tailwind whiteboard --minify + esbuild whiteboard --minify + phx.digest
          '';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            nodejs_24
            typescript-language-server
            prettier
            elixir
            beamBuilder.expert
            postgresql_18_jit
            devPostgres
            esbuild
            tailwindcss_4
            glibcLocales
          ]
          ++ optional stdenv.isLinux inotify-tools
          ++ optionals stdenv.isDarwin [
            terminal-notifier
          ];

          MIX_ESBUILD_PATH = "${esbuild}/bin/esbuild";
          MIX_TAILWIND_PATH = "${tailwindcss_4}/bin/tailwindcss";

          shellHook = ''
            alias ips='iex -S mix phx.server'
            alias mdg='mix deps.get'
            alias mem='mix ecto.migrate'

            if [[ -z "''${DATABASE_URL:-}" && -z "''${DATABASE_SOCKET_DIR:-}" ]]; then
              export DEV_POSTGRES_ROOT_DIR="$PWD/.direnv/postgresql-18"
              export DATABASE_SOCKET_DIR="$DEV_POSTGRES_ROOT_DIR/socket"
              export DATABASE_USERNAME="postgres"
              export PGHOST="$DATABASE_SOCKET_DIR"
              export PGUSER="$DATABASE_USERNAME"
              dev-postgres start
            fi
          '';
        };
      }
    );
}
