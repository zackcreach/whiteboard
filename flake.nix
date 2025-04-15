{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs.lib) optional optionals;

        beamBuilder = pkgs.beam.packagesWith (pkgs.beam.interpreters.erlang_27.override {
          version = "27.3.2";
          sha256 = "sha256-Pybkcm3pLt0wV+S9ia/BAmM1AKp/nVSAckEzNn4KjSg=";
        });

        elixir = beamBuilder.elixir.override {
          version = "1.18.3";
          sha256 = "sha256-jH+1+IBWHSTyqakGClkP1Q4O2FWbHx7kd7zn6YGCog0=";
        };
      in
      with pkgs;
      {
        devShell = pkgs.mkShell {
          buildInputs = [
            nodejs_22
            nodePackages.typescript-language-server
            nodePackages.prettier
            elixir
            (lexical.override { elixir = elixir; })
            postgresql_16
            flyctl
            glibcLocales
          ] ++ optional stdenv.isLinux inotify-tools
          ++ optional stdenv.isDarwin terminal-notifier
          ++ optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
            CoreFoundation
            CoreServices
          ]);
        };
      });
}
