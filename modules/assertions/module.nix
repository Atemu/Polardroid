# SPDX-License-Identifier: MIT
# Adapted from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/assertions.nix
{ lib, ... }:

{
  options.assertions = lib.mkOption {
    type = with lib.types; listOf unspecified;
    internal = true;
    default = [ ];
    example = [
      {
        assertion = false;
        message = "you can't enable this for that reason";
      }
    ];
    description = ''
      This option allows modules to express conditions that must
      hold for the evaluation of the system configuration to
      succeed, along with associated error messages for the user.
    '';
  };
}
