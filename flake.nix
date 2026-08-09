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
          hash = "sha256-OjxHOPlAXNYCMZpRPbhQLSavAbvdBFVjO4Bs1BdaAj8=";
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
            glibcLocales
          ]
          ++ optional stdenv.isLinux inotify-tools
          ++ optionals stdenv.isDarwin [
            terminal-notifier
          ];
        };
      }
    );
}
