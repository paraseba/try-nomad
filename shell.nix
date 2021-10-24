{ pkgs ? import (import nix/sources.nix {}).nixpkgs {} }:
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
      inetutils

      # needed by vagrant
      ps
      systemd
      virtualboxHeadless
      curl
      openssh
      cacert

      # extra tools
      vim
    ];
}
