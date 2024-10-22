{
  lib,
  pkgs,
  targetPkgs ? config.targetPkgs,
  config,
  ...
}:

let
  inherit (lib) mkOption;
  this = config.recovery;
in
{
  options.recovery = {
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
        Packages to install inside the recovery env.

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
        name = "recovery";
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
        The location where the recovery environment is installed on the device.
      '';
      default = "/data/local/tmp/nix-chroot"; # TODO default /tmp if with for tmpfs
    };
  };
}
