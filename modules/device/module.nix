{
  lib,
  pkgs,
  targetPkgs ? config.targetPkgs,
  config,
  ...
}:

let
  inherit (lib) mkOption;
  this = config.device;
in
{
  options.device = {
    polardroid-borg = mkOption {
      internal = true;
      type = lib.types.package;
    };
    polardroid-ncdu = mkOption {
      internal = true;
      type = lib.types.package;
    };
    packages = mkOption {
      description = ''
        Packages to install inside the device env.

        Your host system must be able to realise these derivations! If your
        target is an aarch64 phone and the drvs are not cached, you *will* need
        an aarch64 builder. These should be taken from the targetPlatform in
        order to be exectuable on the device. If you need to make modifications,
        take from pkgsCross instead.

        Note that the entire closure needs to be transmitted to the device, so
        ideally keep this minimal.
      '';
      type = with lib.types; listOf package;
      default = with targetPkgs; [
        bashInteractive
        coreutils
        findutils
        less
        vim

        borgbackup
        ncdu

        rsync
        openssh
      ];
    };
    env = mkOption {
      internal = true;
      default = pkgs.buildEnv {
        name = "polardroid-device-env";
        paths =
          lib.optionals config.backup.enable [
            this.polardroid-borg
            this.polardroid-ncdu
          ]
          ++ this.packages;
      };
    };
    prefix = mkOption {
      description = ''
        The path where the device environment is installed into on the device.

        This does not necessarily need to be persistent but it needs to be able
        to hold the entire device env closure.
      '';
      default = "/data/local/tmp/nix-chroot"; # TODO default /tmp if with for tmpfs
      example = "/tmp";
    };
  };
}
