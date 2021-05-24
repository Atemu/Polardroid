{ pkgs ? import <nixpkgs> { }, targetPkgs ? import <nixpkgs> { system = "aarch64-linux"; } }:

let
  backupCmds = targetPkgs.callPackage ./backupCmds.nix {
    inherit (pkgs.pkgsCross.aarch64-multiplatform) writeShellScriptBin;
  };
  inherit (backupCmds) borgCmd ncduCmd;
in

pkgs.buildEnv {
  name = "recovery";
  paths = with targetPkgs; [
    bashInteractive
    coreutils
    findutils
    less
    nix

    borgbackup
    ncdu

    rsync
    openssh

    # borgCmd
    ncduCmd
  ];
}
