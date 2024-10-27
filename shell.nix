args@{
  pkgs ? import <nixpkgs> { },
  ...
}:

pkgs.mkShellNoCC { buildInputs = [ (import ./default.nix args) ]; }
