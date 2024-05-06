{
  config,
  lib,
  pkgs,
  ...
}:

let
  this = config.system;
in

{
  options.system = {
    targetSystem = lib.mkOption { default = "aarch64-linux"; };
    targetPkgs = lib.mkOption { default = import pkgs.path { system = this.targetSystem; }; };
    crossPkgs = lib.mkOption {
      default = import pkgs.path {
        crossSystem = {
          system = this.targetSystem;
        };
      };
    };
  };

  config.system = { };
}
