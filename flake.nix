{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs.lib) optional optionals optionalString;

        beamBuilder = pkgs.beam.packagesWith pkgs.beam.interpreters.erlang_29;

        elixir = beamBuilder.elixir_1_20;
      in
      with pkgs;
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            nodejs_24
            typescript-language-server
            prettier
            docker-client
            docker-compose
            elixir
            beamBuilder.expert
            postgresql_18_jit
            glibcLocales
          ] ++ optional stdenv.isLinux inotify-tools
          ++ optionals stdenv.isDarwin [
            colima
            lima
            terminal-notifier
          ];

          shellHook = optionalString stdenv.isDarwin ''
            export DOCKER_HOST="unix://$HOME/.colima/whiteboard-qemu/docker.sock"
          '';
        };
      });
}
