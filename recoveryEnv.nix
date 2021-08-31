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
    # Warning: You need to be able to realise these on your host machine!
    # If they're not cached, you will need an aarch64 builder!
    bashInteractive
    coreutils
    findutils
    less
    nix

    borgbackup
    ncdu

    rsync
    openssh

    borgCmd
    ncduCmd
  ];
}
