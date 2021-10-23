{ pkgs ? import (import ~/dotfiles/nixpkgs) {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = with pkgs; [ vagrant nomad bind openssl apacheHttpd  ];
}
