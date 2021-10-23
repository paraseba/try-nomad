{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = with pkgs; [
      vagrant
      nomad
      bind
      openssl
      apacheHttpd
      docker
      docker-compose
      which
      nix

      # needed by vagrant
      ps
      systemd
      virtualbox
      curl
      openssh


      # extra tools
      vim
    ];
}
