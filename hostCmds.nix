{ pkgs ? import <nixpkgs> { }, targetSystem ? "aarch64-linux" }:

let
  inherit (pkgs.lib) getExe getBin optionalString;

  targetPkgs = import <nixpkgs> { system = targetSystem; };
  recoveryEnv = import ./recoveryEnv.nix { inherit targetPkgs; };

  prefix = "/data/local/tmp/nix-chroot";

  # TODO make non-tmpfs installation work again
  useTmpfs = true;

  sshdConfig = (import <nixpkgs/nixos> {
    configuration.services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      hostKeys = [ ];
    };
  }).config.environment.etc."ssh/sshd_config".source;
  sshdConfigPatched = pkgs.runCommand "sshdConfigPatched" { } ''
    substitute ${sshdConfig} $out --replace "UsePAM yes" ""
  '';
  sshdWrapperName = "sshd-for-adb";
  sshdWrapper = pkgs.writeShellScript sshdWrapperName ''exec ${pkgs.openssh}/bin/sshd "$@"'';
in

rec {
  enterScript = pkgs.writeScript "enter" ''
    #!/bin/sh

    for dir in proc dev data ; do
      mkdir -p ${prefix}/$dir

      # Don't bind again if it's already mounted
      if ! grep ${prefix}/$dir /proc/mounts > /dev/null ; then
        mount -o bind /$dir ${prefix}/$dir
      fi
    done

    PATH=/nix/var/nix/profiles/default/bin:$PATH chroot ${prefix} bash

    ${prefix}/cleanup
  '';

  cleanupScript = pkgs.writeScript "cleanup" ''
    #!/bin/sh

    for dir in ${prefix}/* ; do
      if grep $dir /proc/mounts > /dev/null ; then
        umount $dir
      fi
    done
  '';

  removalScript = pkgs.writeScript "remove" ''
    #!/bin/sh
    ${prefix}/cleanup

    if grep ${prefix}/ /proc/mounts > /dev/null ; then
      echo Error: There is still a mount active under ${prefix}, umount them first. If you only wanted to clean up before reboot, you can safely reboot now.
      exit 1
    else
      exit 0
    fi
  '';

  adbScriptBin = name: script: pkgs.writeShellScriptBin name (
    (if pkgs ? android-tools then ''
      PATH=${pkgs.android-tools}/bin/:$PATH
    '' else ''
      command -V adb || {
        echo 'You need to build this with nixpkgs >= 21.11 or have ADB in your PATH. You can install adb via `programs.adb.enable` on NixOS'
        exit 1
      }
    '') + script);

  installCmd = adbScriptBin "installCmd" (''
    if adb shell 'ls -d ${prefix} 2>&1 > /dev/null' ; then
      echo Error: Nix environment has been installed already. Remove it using the removeCmd.
      exit 1
    fi

    # Copy Nix store over to the device
    adb shell mkdir -p ${prefix}
  '' + optionalString useTmpfs ''
    adb shell mount -t tmpfs tmpfs ${prefix}
  '' + ''
    nix-store --query --requisites ${recoveryEnv} | cut -c 2- \
      | tar cf - -C / --files-from=/dev/stdin | ${getExe pkgs.pv} | gzip -2 | adb shell 'gzip -d | tar xf - -C ${prefix}/'
    adb shell "mkdir -p ${prefix}/nix/var/nix/profiles/ && ln -s ${recoveryEnv} ${prefix}/nix/var/nix/profiles/default"

    # Provide handy script to enter an env with Nix
    adb push ${enterScript} ${prefix}/enter
    adb push ${cleanupScript} ${prefix}/cleanup
    adb push ${removalScript} ${prefix}/remove
    adb shell chmod +x ${prefix}/enter
    adb shell chmod +x ${prefix}/cleanup
    adb shell chmod +x ${prefix}/remove
    echo 'Nix has been installed, you can now run `adb shell` and then `${prefix}/enter` to get a Nix environment'

    # Fake `/etc/passwd` to make SSH work
    adb shell 'mkdir -p ${prefix}/etc/'
    adb shell 'echo "root:x:0:0::/:" > ${prefix}/etc/passwd'
  '');

  removeCmd = adbScriptBin "removeCmd" (''
    adb shell sh ${prefix}/remove
  '' + optionalString useTmpfs ''
    adb shell umount ${prefix}
    adb shell rmdir ${prefix}
  '' + ''

    echo "All traces of Nix removed."
  '');

  # One step because you only need to run this once and it works from there on
  setupSsh = pkgs.writeShellScriptBin "setupSsh" ''
    echo 'Forwarding SSH port to host'
    adb reverse tcp:4222 tcp:4222

    tmpdir=$(mktemp -d)

    ${getBin pkgs.openssh}/bin/ssh-keygen -N "" -t ed25519 -f $tmpdir/client-key > /dev/null
    ${getBin pkgs.openssh}/bin/ssh-keygen -N "" -t ed25519 -f $tmpdir/host-key > /dev/null

    adb shell mkdir -p ${prefix}/.ssh/
    adb push $tmpdir/client-key* ${prefix}/.ssh/
    # adb push $tmpdir/host-key.pub ${prefix}/.ssh/known_hosts

    # Write sshd_config to $tmpdir
    echo 'Starting new SSHD'
    ${sshdWrapper} -D -f ${sshdConfigPatched} -p 4222 -o HostKey=$tmpdir/host-key -o AuthorizedKeysFile=$tmpdir/client-key.pub -o PubkeyAuthentication=yes -o StrictModes=no &
    pid=$!

    USER="''${USER:=<hostusername>}"

    echo "You can now reach your host using \`ssh $USER@127.0.0.1 -p 4222\` from the device"
    echo 'To stop this sshd, run `kill' $pid'`.'
  '';

  tearDownSsh = pkgs.writeShellScriptBin "tearDownSsh" ''
    echo 'Removing all adb port forwards'
    adb forward --remove-all
    adb reverse --remove-all

    kill $(pidof ${sshdWrapperName})
  '';

  hostCmds = pkgs.buildEnv {
    name = "hostCmds";
    paths = [
      installCmd
      removeCmd
      setupSsh
      tearDownSsh
    ];
  };
}
