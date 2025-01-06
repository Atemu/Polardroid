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
      installing a temporary environment onto your phone which you may not want
      to have to configure the backup part of this project for.
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
        type = with lib.types; attrsOf anything;
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
        type = with lib.types; attrsOf anything;
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
    device.polardroid-restore =
      let
        inherit (this.borg)
          repo
          env
          ;
        exe = lib.getExe this.borg.package;
      in
      crossPkgs.writeShellApplication {
        name = "polardroid-restore";
        runtimeEnv = {
          # The paths to be restored. These are the paths that contain all the
          # known useful state. Keep this in sync with what is documented in the
          # README!
          RESTORE_PATHS = map (x: "sh:${this.path}/${x}") [
              "app/"
              "data/"
              "system/package*"
              "system/netpolicy.xml"
              "system/users/0/"
              "misc_de/0/apexdata/com.android.permission/"
              "user_de/0/"
              "media/0/"
              "misc/apexdata/com.android.wifi"
              "system/notification_policy.xml"
              "property/persistent_properties"
              "user_de/0/org.lineageos.lineagesettings"
              "misc/profiles/"
              "system_ce/"
          ];
        } // env;
        text = ''
          if [ -z "''${1:-}" ]; then
             echo "You must provide \`polardroid-restore\` with the name of the borg archive which you wish to restore."
             exit 1
          fi
          ARCHIVE_NAME="$1"
          shift

          declare -a paths

          if [ -z "''${1:-}" ]; then
            paths=("''${RESTORE_PATHS[@]}")
          else
            paths=("$@")
          fi

          for path in "''${paths[@]}" ; do
              ${exe} extract --progress --numeric-ids ${repo}::"$ARCHIVE_NAME" "$path" "$@"
          done
        '';
      };
  };
}
