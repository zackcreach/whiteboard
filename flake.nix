{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    heroicons = {
      url = "github:tailwindlabs/heroicons/v2.2.0";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      deploy-rs,
      heroicons,
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
        mixNixDeps = import ./deps.nix {
          inherit (pkgs) lib;
          beamPackages = beamBuilder;
          overrides = _final: previous: {
            lazy_html = previous.lazy_html.overrideAttrs (_old: {
              preBuild = ''
                export HOME="$TMPDIR"
                export XDG_CACHE_HOME="$TMPDIR"
              '';
            });
            uxid = previous.uxid.overrideAttrs (_old: {
              postPatch = ''
                substituteInPlace mix.exs \
                  --replace-fail "elixirc_options: [warnings_as_errors: true]" \
                  "elixirc_options: [warnings_as_errors: false]"
              '';
            });
          };
        };
        updateMixDeps = pkgs.writeShellApplication {
          name = "update-mix-deps";
          runtimeInputs = [ pkgs.mix2nix ];
          text = ''
            mix2nix mix.lock | sed -e '$d' > deps.nix
          '';
        };
        dependencyFreshness =
          pkgs.runCommand "whiteboard-mix-dependencies-fresh"
            {
              nativeBuildInputs = [ pkgs.mix2nix ];
            }
            ''
              mix2nix ${./mix.lock} | sed -e '$d' > generated-deps.nix
              if ! cmp --silent generated-deps.nix ${./deps.nix}; then
                echo "deps.nix is stale. Run: nix run .#update-mix-deps" >&2
                diff --unified ${./deps.nix} generated-deps.nix >&2 || true
                exit 1
              fi
              touch $out
            '';
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
          inherit mixNixDeps;
          nativeBuildInputs = [ dependencyFreshness ];
          HEROICONS_PATH = "${heroicons}/optimized";
          MIX_ESBUILD_PATH = "${esbuild}/bin/esbuild";
          MIX_TAILWIND_PATH = "${tailwindcss_4}/bin/tailwindcss";
          postBuild = ''
            mix do deps.loadpaths --no-deps-check + tailwind whiteboard --minify + esbuild whiteboard --minify + phx.digest
          '';
          postInstall = ''
            mkdir -p $out/share/prominent-tools
            printf '%s\n' '${
              self.rev or self.dirtyRev or "0000000000000000000000000000000000000000"
            }' > $out/share/prominent-tools/revision
          '';
        };

        packages.deploy-rs = deploy-rs.packages.${system}.default;
        packages.dependency-freshness = dependencyFreshness;

        apps.update-mix-deps = {
          type = "app";
          program = "${updateMixDeps}/bin/update-mix-deps";
        };

        checks.dependency-freshness = dependencyFreshness;

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
            mix2nix
            glibcLocales
          ]
          ++ optional stdenv.isLinux inotify-tools
          ++ optionals stdenv.isDarwin [
            terminal-notifier
          ];

          MIX_ESBUILD_PATH = "${esbuild}/bin/esbuild";
          MIX_TAILWIND_PATH = "${tailwindcss_4}/bin/tailwindcss";
          HEROICONS_PATH = "${heroicons}/optimized";

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
    )
    // {
      deploy.nodes.symphony = {
        hostname = "127.0.0.1";
        sshUser = "prominent-deploy";
        sshOpts = [
          "-o"
          "StrictHostKeyChecking=accept-new"
          "-o"
          "IdentitiesOnly=yes"
          "-i"
          "/var/lib/prominent-deploy/.ssh/prominent-deploy"
        ];
        remoteBuild = false;
        profiles.whiteboard = {
          user = "prominent-deploy";
          profilePath = "/nix/var/nix/profiles/per-user/prominent-deploy/whiteboard";
          path = deploy-rs.lib.x86_64-linux.activate.custom self.packages.x86_64-linux.default "sudo /run/current-system/sw/bin/prominent-tools-activate whiteboard";
        };
      };

      checks.x86_64-linux = deploy-rs.lib.x86_64-linux.deployChecks self.deploy // {
        dependency-freshness = self.packages.x86_64-linux.dependency-freshness;
      };
    };
}
