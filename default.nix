{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
}:

lib.evalModules {
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
    ];
}
