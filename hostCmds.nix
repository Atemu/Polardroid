{ pkgs ? import <nixpkgs> { }, targetSystem ? "aarch64-linux" }:

rec {
  targetPkgs = import <nixpkgs> { system = targetSystem; };
  recoveryEnv = import ./recoveryEnv.nix { inherit targetPkgs; };

  adbScriptBin = name: script: pkgs.writeShellScriptBin name (
    (if pkgs ? android-tools then ''
      PATH=${pkgs.android-tools}/bin/:$PATH
    '' else ''
      command -V adb || {
        echo 'You need to build this with nixpkgs >= 21.11 or have ADB in your PATH. You can install adb via `programs.adb.enable` on NixOS'
        exit 1
      }
    '') + script);

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

    # Fake `/etc/passwd` to make SSH work
    adb shell 'echo "root:x:0:0::/:" > /etc/passwd'
  '';

  removeCmd = adbScriptBin "removeCmd" ''
    adb shell 'while true ; do umount /nix 2>/dev/null || break ; done'
    adb shell 'rm -fr /tmp/nix'
    adb shell 'rm /tmp/enter'
    adb shell 'rm /etc/passwd'
    echo 'Removed Nix and connected state from device'
  '';

  # One step because you only need to run this once and it works from there on
  runSshd = pkgs.writeShellScriptBin "runSshd" ''
    echo 'Forwarding SSH port to host'
    adb reverse tcp:4222 tcp:4222

    echo 'Starting new SSHD'
    sudo ${pkgs.openssh}/bin/sshd -D -f /etc/ssh/sshd_config -p 4222 &
    pid=$!

    echo 'You can now reach your host using `ssh <hostusername>@127.0.0.1 -p 4222` from the device'
    echo 'To stop the sshd, run `sudo kill' $pid'`.'
  '';

  removeForwards = pkgs.writeShellScriptBin "removeForwards" ''
    echo 'Removing all adb port forwards'
    adb forward --remove-all
    adb reverse --remove-all
  '';

  hostCmds = pkgs.buildEnv {
    name = "hostCmds";
    paths = [
      installCmd
      removeCmd
      runSshd
      removeForwards
    ];
  };
}
