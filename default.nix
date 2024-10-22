{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  configuration ? if builtins.pathExists ./configuration.nix then ./configuration.nix else { },
}:

let
  eval = lib.evalModules {
    modules =
      lib.mapAttrsToList (n: v: ./modules + "/${n}/module.nix") (builtins.readDir ./modules)
      ++ [
        (
          { config, ... }:
          {
            _module.args = {
              inherit pkgs;
              inherit (config.system) targetPkgs crossPkgs;
            };
          }
        )
        configuration
      ];
  };
in
pkgs.callPackage ./cli.nix {
  inherit eval;
}
