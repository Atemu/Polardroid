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
  failedAssertions = map (x: x.message) (lib.filter (x: !x.assertion) eval.config.assertions);

  cli = pkgs.callPackage ./cli.nix {
    inherit eval;
  };
in

if failedAssertions != [ ] then
  throw "\nFailed assertions:\n${lib.concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}"
else
  cli
