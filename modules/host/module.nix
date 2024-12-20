{
  lib,
  config,
  ...
}:

let
  this = config.host;
in

{
  options.host = {
    user = lib.mkOption {
      type = lib.types.str;
      default =
        let
          user = builtins.getEnv "USER";
        in
        lib.warn ''No user name specified, impurely assuming "${user}" from the environment.'' user;
      description = ''
        The username used for actions on the host. This should be set to the
        username of the user you intend to run the host scripts as.
      '';
    };
    borg = {
      host = lib.mkOption {
        type = lib.types.str;
        default = "host";
        description = ''
          The host on which the borg repository resides.

          If this host requires a specific key to access, you must also set {option}`keyFile`.
        '';
      };
      repository = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          The path to the borg repository in the {option}`host` to store the backups in.
        '';
        apply = path: if path == null then null else lib.removePrefix "/" path;
      };
      keyFile = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          The path to the SSH key to install into the device with which it is able to authenticate against the {option}`host`.

          This path must exist on the host machine at the time at which you establish the reverse shell.

          You only need to set this so long as {option}`host.borg.host` is set and that host requires a specific SSH key (i.e. publickey authentication).
          SSH access to the host machine that you establish reverse shell access from is always provided.
        '';
      };
    };
    rsh = {
      enable =
        lib.mkEnableOption "reverse shell access from the device to the host computer via SSH"
        // lib.mkOption { default = true; };
      port = lib.mkOption {
        type = lib.types.port;
        default = 4222;
        description = ''
          TCP port to use for reverse SSH.
        '';
      };
    };
  };

  config = {
    backup.borg.repo = "ssh://${this.borg.host}/${this.borg.repository}";

    assertions = [
      {
        assertion = config.backup.enable -> this.borg.repository != null;
        message = "You must specify a `host.borg.repository` in order to use the {option}`backup.enable` functionality.";
      }
    ];
  };
}
