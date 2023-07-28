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
    adb shell mkdir /nix 2>/dev/null && \
    adb shell mount -t tmpfs tmpfs /nix || \
    { echo "/nix already exists. Files will been dirty-copied over the old Nix store closure."
      echo "This is not necessarily an issue if you've run this before."
      echo "Giving you two seconds to cancel.."
      sleep 2
    }

    tmpdir="$(mktemp -d)"

    # Create new Nix store in tmpdir on host
    nix-env --store "$tmpdir" -i ${recoveryEnv} -p "$tmpdir"/nix/var/nix/profiles/default --extra-substituters "auto?trusted=1"

    # Copy Nix store over to the device
    adb shell mount -o remount,size=4G /tmp
    time tar cf - -C "$tmpdir" nix/ | ${pkgs.pv}/bin/pv | gzip -2 | adb shell 'gzip -d | tar xf - -C /'

    chmod -R +w "$tmpdir" && rm -r "$tmpdir"

    # Provide handy script to enter an env with Nix
    adb shell 'echo "#!/nix/var/nix/profiles/default/bin/bash
    PATH=/nix/var/nix/profiles/default/bin:$PATH exec bash
    " > /nix/enter'
    adb shell chmod +x /nix/enter
    echo 'Nix has been installed, you can now run `adb shell` and then `/nix/enter` to get a Nix environment'

    # Fake `/etc/passwd` to make SSH work
    adb shell 'echo "root:x:0:0::/:" > /etc/passwd'
  '';

  removeCmd = adbScriptBin "removeCmd" ''
    adb shell umount /nix
    adb shell rmdir /nix
    adb shell rm /etc/passwd

    echo "All traces of Nix removed."
  '';

  # One step because you only need to run this once and it works from there on
  runSshd = pkgs.writeShellScriptBin "runSshd" ''
    echo 'Forwarding SSH port to host'
    adb reverse tcp:4222 tcp:4222

    echo 'Need to elevate privileges to run sshd'
    sudo echo "Received privileges!" || exit 1
    echo 'Starting new SSHD'
    sudo ${pkgs.openssh}/bin/sshd -D -f /etc/ssh/sshd_config -p 4222 &
    pid=$!

    USER="''${USER:=<hostusername>}"

    echo "You can now reach your host using \`ssh $USER@127.0.0.1 -p 4222\` from the device"
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
