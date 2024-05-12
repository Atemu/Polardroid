{
  lib,
  openssh,
  writeShellScriptBin,
  writeScript,
  writeText,
  runCommand,
  android-tools,
  pv,

  prefix,
  recoveryEnv,
  sshPort,
}:

let
  inherit (lib) getExe getBin optionalString;

  # TODO make non-tmpfs installation work again
  useTmpfs = true;

  sshdConfig =
    (import <nixpkgs/nixos> {
      configuration.system.stateVersion = lib.versions.majorMinor lib.version; # not relevant
      configuration.services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
        };
        hostKeys = [ ];
      };
    }).config.environment.etc."ssh/sshd_config".source;
  sshdConfigPatched = runCommand "sshdConfigPatched" { } ''
    substitute ${sshdConfig} $out --replace "UsePAM yes" ""
  '';
in

rec {
  enterScript = writeScript "enter" ''
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

  cleanupScript = writeScript "cleanup" ''
    #!/bin/sh

    for dir in ${prefix}/* ; do
      if grep $dir /proc/mounts > /dev/null ; then
        umount $dir
      fi
    done
  '';

  removalScript = writeScript "remove" ''
    #!/bin/sh
    ${prefix}/cleanup

    if grep ${prefix}/ /proc/mounts > /dev/null ; then
      echo Error: There is still a mount active under ${prefix}, umount them first. If you only wanted to clean up before reboot, you can safely reboot now.
      exit 1
    else
      exit 0
    fi
  '';

  adbScriptBin =
    name: script:
    writeShellScriptBin name ''
      PATH=${android-tools}/bin/:$PATH

      ${script}
    '';

  installCmd = adbScriptBin "installCmd" (
    ''
      if adb shell 'ls -d ${prefix} 2>&1 > /dev/null' ; then
        echo Error: Nix environment has been installed already. Remove it using the removeCmd.
        exit 1
      fi

      # Copy Nix store over to the device
      adb shell mkdir -p ${prefix}
    ''
    + optionalString useTmpfs ''
      adb shell mount -t tmpfs tmpfs ${prefix}
    ''
    + ''
      nix-store --query --requisites ${recoveryEnv} | cut -c 2- \
        | tar cf - -C / --files-from=/dev/stdin | ${getExe pv} | gzip -2 | adb shell 'gzip -d | tar xf - -C ${prefix}/'
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
    ''
  );

  removeCmd = adbScriptBin "removeCmd" (
    ''
      adb shell sh ${prefix}/remove
    ''
    + optionalString useTmpfs ''
      adb shell umount ${prefix}
      adb shell rmdir ${prefix}
    ''
    + ''

      echo "All traces of Nix removed."
    ''
  );

  # One step because you only need to run this once and it works from there on
  setupSsh = writeShellScriptBin "setupSsh" ''
    echo 'Forwarding SSH port to host'
    adb reverse tcp:${sshPort} tcp:${sshPort}

    tmpdir=$(mktemp -d)

    ${getBin openssh}/bin/ssh-keygen -N "" -t ed25519 -f $tmpdir/client-key > /dev/null
    ${getBin openssh}/bin/ssh-keygen -N "" -t ed25519 -f $tmpdir/host-key > /dev/null

    adb shell mkdir -p ${prefix}/.ssh/
    adb push $tmpdir/client-key* ${prefix}/.ssh/
    adb shell chmod 600 ${prefix}/.ssh/client-key*
    adb push ${writeText "config" "IdentityFile ~/.ssh/client-key"} ${prefix}/.ssh/config

    echo "[127.0.0.1]:${sshPort} ssh-ed25519 $(cut -f 2 -d ' ' $tmpdir/host-key.pub)" > $tmpdir/known_hosts
    adb push $tmpdir/known_hosts ${prefix}/.ssh/

    echo 'Starting new SSHD'
    ${openssh}/bin/sshd -f ${sshdConfigPatched} -o Port=${sshPort} -o HostKey=$tmpdir/host-key -o AuthorizedKeysFile=$tmpdir/client-key.pub -o PubkeyAuthentication=yes -o StrictModes=no &

    USER="''${USER:=<hostusername>}"

    echo "You can now reach your host using \`ssh $USER@127.0.0.1 -p ${sshPort}\` from the device"
    echo 'To stop this sshd and remove the forwards, run the `tearDownSshd` script.'
  '';

  tearDownSsh = writeShellScriptBin "tearDownSsh" ''
    echo 'Removing all adb port forwards'
    adb forward --remove-all
    adb reverse --remove-all

    adb shell rm -r ${prefix}/.ssh

    pkill -f Port=${sshPort}
  '';
}
