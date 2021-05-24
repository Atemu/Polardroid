{ lib
, writeShellScriptBin
, borgbackup
, ncdu
, extraBorgArgs ? [ ]
, extraNcduArgs ? [ ]
}:


rec {
  exclusions = import ./exclusions.nix;

  # [ string ] -> [ string ]
  # [ "path1/" "path2" ] -> [ "--exclude" "'path1'" "--exclude" "'path2'" ]
  mkExcludeArgs = list:
    with lib;
    flatten (map (item:
      [ "--exclude" (escapeShellArg (removeSuffix "/" item)) ]
    ) list);

  # [ string ] -> string
  # [ "--exclude" "'path1'" "--exclude" "'path2'" ] -> "--exclude 'path1' --exclude 'path2'"
  args2cmd = args: lib.concatStringsSep " " args;

  mkNcduArgs = list: (mkExcludeArgs list) ++ extraNcduArgs ++ [ ''"$@"'' ];
  mkBorgArgs = list: (mkExcludeArgs list) ++ extraBorgArgs ++ [ ''"$@"'' ];


  borgCmd = writeShellScriptBin "borgCmd" ''
    ${borgbackup}/bin/borg ${args2cmd (mkBorgArgs exclusions)}
  '';

  ncduCmd = writeShellScriptBin "ncduCmd" ''
    ${ncdu}/bin/ncdu ${args2cmd (mkNcduArgs exclusions)}
  '';
}
