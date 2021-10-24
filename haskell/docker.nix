{ pkgs ? import (import ../nix/sources.nix {}).nixpkgs {}
, project ? (import ./default.nix).svc1.components.exes.svc1
}:

pkgs.dockerTools.buildImage {
  name = "docker-registry.monoidmagma.com/svc1";
  contents = project;
  tag = "latest";
  config = {
    Cmd = [ "${project}/bin/svc1" ];
    ExposedPorts = { "8080/tcp" = {}; };
  };
}
