{
  lib,
  pkgs,
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
    borg.repository = lib.mkOption {
      type = lib.types.str;
      default = builtins.throw "You must specify a `host.borg.repository` in order to use the {option}`backup.enable` functionality.";
      description = ''
        The path to the borg repository on the host machine to store backups in.
      '';
      apply = lib.removePrefix "/";
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
    backup.borg.repo = "ssh://host/${this.borg.repository}";
  };
}
