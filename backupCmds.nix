{ lib
, writeShellScriptBin
, coreutils
, borgbackup
, ncdu
, borgEnvVars ? { BORG_KEY_FILE = "/tmp/key"; }
, borgArgs ? {
    compression = "zstd,10";
    files-cache = "mtime,size";
    progress = true;
  }
, extraBorgArgs ? [ ]
, borgRepo ? [ "'ssh://atemu@127.0.0.1:4222/mnt/borg/Phone::A0005.data.{now}'" ]
, borgPath ? "/data"
, extraNcduArgs ? [ ]
}:


let
  shellArgsPassthru = ''"$@"'';
in rec {
  exclusions = import ./exclusions.nix;

  # string -> string
  # "path1/" -> "path1"
  # "path2" -> "path2"
  normalisePath = path: lib.removeSuffix "/" path;

  # string -> [ string ]
  # "path1/" -> [ "--exclude" "'path1'" ]
  mkExcludeArg = path: [ "--exclude" (lib.escapeShellArg (normalisePath path)) ];

  # [ "path1/" "path2" ] -> [ "--exclude" "'path1'" "--exclude" "'path2'" ]
  mkExcludeArgs = paths: lib.flatten (map mkExcludeArg paths);

  # [ string ] -> string
  # [ "--exclude" "'path1'" "--exclude" "'path2'" ] -> "--exclude 'path1' --exclude 'path2'"
  args2cmd = args: lib.concatStringsSep " " args;

  # { string = toStringable; } -> [ string ]
  # { VAR1 = "test"; VAR2 = 1; } -> [ "VAR1='test'" "VAR2='1'" ]
  mkEnvVars = vars: lib.mapAttrsToList (name: value: "${name}='${toString value}'") vars;

  # Creates a CLI prefix for running a command with certain environment variables
  mkEnvCmd = vars: [ "${coreutils}/bin/env" ] ++ (mkEnvVars vars);

  # string -> string
  # "/test1" -> "/data/test1"
  # "test2" -> "/data/test2"
  prependBorgPath = path: "${borgPath}/" + lib.removePrefix "/" path;

  mkBorgArgs = list:
    let
      baseCmd = [ "${borgbackup}/bin/borg" "create" ] ++ lib.cli.toGNUCommandLine { } borgArgs;
    in
    mkEnvCmd borgEnvVars
    ++ baseCmd
    ++ extraBorgArgs
    ++ (mkExcludeArgs (map prependBorgPath list))
    ++ borgRepo
    ++ [ borgPath ]
    ++ [ shellArgsPassthru ];

  borgCmd = writeShellScriptBin "borgCmd" ''
    ${args2cmd (mkBorgArgs exclusions)}
  '';

  mkNcduArgs = paths: (mkExcludeArgs paths) ++ extraNcduArgs ++ [ shellArgsPassthru ];

  ncduCmd = writeShellScriptBin "ncduCmd" ''
    ${ncdu}/bin/ncdu ${args2cmd (mkNcduArgs exclusions)}
  '';
}
