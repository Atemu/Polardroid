{
  config,
  lib,
  targetPkgs ? config.targetPkgs,
  crossPkgs ? config.crossPkgs,
  ...
}:

let
  this = config.backup;
in

{
  options.backup = {
    enable = lib.mkEnableOption ''
      the backup functionality.

      This option exists because this project could also be used for just
      installing a temporary Nix environment onto your phone which you may not
      want to have to configure the backup part of this project for.
    '';
    path = lib.mkOption {
      description = ''
        The path to back up on the device.
      '';
      default = "/data";
    };
    exclusions = lib.mkOption {
      type = with lib.types; listOf str; # TODO check via regex?
      default = [ ];
      apply = map (lib.removeSuffix "/"); # Normalise the paths
      description = ''
        Path patterns as described in `borg help patterns`. Each one is supplied to a `--exclude` argument.
      '';
    };
    recommendedExclusions = lib.mkEnableOption ''
      a set of default exclusions which cover states that are replaceable, ephemeral, not able to be backed up and caches.

      Currently, this also includes media files which are assumed to be backed up separately which is subject to change.
    '';
    borg = {
      args = lib.mkOption {
        type = lib.types.attrs; # TODO is there a more accurate type here?
        description = ''
          The arguments to pass to Borg as an attrset passed to `lib.cli.toGNUCommandLineShell`.
        '';
        default = { };
      };
      repo = lib.mkOption {
        type = lib.types.str;
        internal = true;
        description = ''
          The URI to the repository on the host machine. This gets set automatically, you should not have to edit this.
        '';
        default = builtins.throw "No borg repo specified, the host module should have done that!";
      };
      env = lib.mkOption {
        description = ''
          The set of environment variables passed to Borg invocations.
        '';
        type = lib.types.attrs;
        default = { };
      };
      name = lib.mkOption {
        default = "{now}";
        description = ''
          The name of the snapshot. See the `borg create` documentation.
        '';
      };
      package = lib.mkPackageOption targetPkgs "borgbackup" { };
      patterns = lib.mkOption {
        type = with lib.types; nullOr (either str path);
        description = ''
          A string of patterns or a patterns file according to Borg's patterns.lst file format.

          Note that only Borg understands these patterns. Use {option}`backup.exclusions` for generic exclusions.
        '';
        default = null;
      };
    };
    ncdu = {
      package = lib.mkPackageOption targetPkgs "ncdu" { };
      args = lib.mkOption {
        type = with lib.types; attrs;
        default = { };
      };
      env = lib.mkOption {
        description = ''
          The set of environment variables passed to ncdu invocations.
        '';
        type = lib.types.attrs;
        default = { };
      };
    };
  };

  config = {
    backup = {
      borg.args = {
        exclude = map (exclusion: "${this.path}/${exclusion}") this.exclusions;
        patterns-from = this.borg.patterns;
      };
      ncdu.args = {
        exclude = this.exclusions;
      };
      exclusions = lib.mkIf this.recommendedExclusions (import ./exclusions.nix);
    };
    device.polardroid-borg =
      let
        inherit (this.borg)
          args
          repo
          env
          name
          ;
        exe = lib.getExe this.borg.package;
        argString = lib.cli.toGNUCommandLineShell { } args;
      in
      crossPkgs.writeShellScriptBin "polardroid-borg" ''
        set -o allexport # Export the following env vars
        ${lib.toShellVars env}
        exec ${exe} create ${argString} "${repo}::${name}" "${this.path}" "$@"
      '';
    device.polardroid-ncdu =
      let
        inherit (this.ncdu) args env;
        exe = lib.getExe this.ncdu.package;
        argString = lib.cli.toGNUCommandLineShell { } args;
      in
      crossPkgs.writeShellScriptBin "polardroid-ncdu" ''
        set -o allexport # Export the following env vars
        ${lib.toShellVars env}
        exec ${exe} ${argString} ${this.path} "$@"
      '';
  };
}
