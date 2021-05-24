{ pkgs ? import <nixpkgs> { }, targetSystem ? "aarch64-linux" }:

rec {
  targetPkgs = import <nixpkgs> { system = targetSystem; };
  recoveryEnv = import ./recoveryEnv.nix { inherit targetPkgs; };

  adbScriptBin = name: script: pkgs.writeShellScriptBin name ''
    command -V adb || { echo 'You need ADB in your PATH. You can install it via `programs.adb.enable` on NixOS'; exit 1; }

    ${script}
  '';

  installCmd = adbScriptBin "installCmd" ''
    tmpdir="$(mktemp -d)"

    # Create new Nix store in tmpdir on host
    nix-env --store "$tmpdir" -i ${recoveryEnv} -p "$tmpdir"/nix/var/nix/profiles/default --extra-substituters "auto?trusted=1"

    # Copy Nix store over to the device
    adb shell mount -o remount,size=4G /tmp
    time tar cf - -C "$tmpdir" nix/ | ${pkgs.pv}/bin/pv | gzip -2 | adb shell 'gzip -d | tar xf - -C /tmp/'
    chmod -R +w "$tmpdir" && rm -r "$tmpdir"
    adb shell mkdir /nix || echo "Not an issue if you've run this before."
    adb shell mount -o bind /tmp/nix /nix

    # Provide handy script to enter an env with Nix
    adb shell 'echo "#!/nix/var/nix/profiles/default/bin/bash
    PATH=/nix/var/nix/profiles/default/bin:$PATH exec bash
    " > /tmp/enter'
    adb shell chmod +x /tmp/enter
    echo 'Nix has been installed, you can now run `adb shell` and then `/tmp/enter` to get a Nix environment'
  '';

  removeCmd = adbScriptBin "removeCmd" ''
    adb shell 'while true ; do umount /nix 2>/dev/null || break ; done'
    adb shell 'rm -fr /tmp/nix'
    adb shell 'rm /tmp/enter'
    echo 'Removed Nix and connected state from device'
  '';

  hostCmds = pkgs.buildEnv {
    name = "hostCmds";
    paths = [
      installCmd
      removeCmd
    ];
  };
}
