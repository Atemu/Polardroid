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
    name = lib.mkOption {
      default = "{now}";
    };
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
        default = "'ssh://atemu@127.0.0.1:4222/Users/atemu/Backups/Android/Data::FP4.data.{now}'"; # TODO
      };
      env = lib.mkOption {
        description = ''
          The set of environment variables passed to Borg invocations.
        '';
        type = lib.types.attrs;
        default = { };
      };
      package = lib.mkPackageOption targetPkgs "borgbackup" { };
    };
    ncdu = {
      args = lib.mkOption { };
    };

    path = lib.mkOption {
      description = ''
        The path to back up on the device.
      '';
      default = "/data";
    };
  };

  config = {
    recovery.borgCmd =
      let
        inherit (this.borg) args repo env package;
        exe = lib.getExe package;
        argString = lib.cli.toGNUCommandLineShell { } args;
      in
      crossPkgs.writeShellScriptBin "borgCmd" ''
        set -o allexport # Export the following env vars
        ${lib.toShellVars env}
        exec ${exe} ${argString} ${repo}::${this.name} "$@"
      '';
  };
}
