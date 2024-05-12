{
  lib,
  pkgs,
  config,
  ...
}:

let
  this = config.host;
  cmds = pkgs.callPackage ./cmds.nix {
    prefix = config.recovery.prefix;
    recoveryEnv = config.recovery.env;
  };
in

{
  options.host = {
    user = lib.mkOption { default = ""; };
    ssh = {
      enable =
        lib.mkEnableOption "reverse SSH access from the device to the host computer"
        // lib.mkOption { default = true; };
    };
    env = lib.mkOption {
      internal = true;
      default = pkgs.buildEnv {
        name = "hostCmds";
        paths =
          with cmds;
          [
            installCmd
            removeCmd
          ]
          ++ lib.optionals this.ssh.enable [
            setupSsh
            tearDownSsh
          ];
      };
    };
  };

  config = { };
}
