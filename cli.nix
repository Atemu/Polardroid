{
  lib,
  openssh,
  writeShellScript,
  writeScript,
  writeText,
  writeShellApplication,
  runCommand,
  android-tools,
  pv,

  eval,
}:

let
  inherit (lib) getExe getBin optionalString;

  prefix = eval.config.device.prefix;
  deviceEnv = eval.config.device.env;
  rshPort = toString eval.config.host.rsh.port;
  inherit (eval.config.host) user;
  inherit (eval.config.host.borg) keyFile;

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

  adbScript =
    name: script:
    writeShellScript name ''
      PATH=${android-tools}/bin/:$PATH

      ${script}
    '';

  install = adbScript "polardroid-install" (
    ''
      if adb shell 'ls -d ${prefix} > /dev/null 2>&1' ; then
        echo 'Error: Polardroid environment appears to have already been installed. Remove it using `polardroid remove`.'
        exit 1
      fi

      # Copy Nix store over to the device
      adb shell mkdir -p ${prefix}
    ''
    + optionalString useTmpfs ''
      adb shell mount -t tmpfs tmpfs ${prefix}
    ''
    + ''
      # As of Android 14, you cannot pipe "large" quantities into ADB.
      # We must do a dance with temporary files instead. Ugh.
      # TODO make tempfile cleanup more robust
      tmptar="$(mktemp)"
      devicetmp=${prefix}/tmp/polardroid-device-env.tar.gz

      nix-store --query --requisites ${deviceEnv} | cut -c 2- | tar cf - -C / --files-from=/dev/stdin | gzip -2 > $tmptar
      adb shell mkdir -p "$(dirname "$devicetmp")"
      adb push $tmptar $devicetmp
      rm $tmptar
      echo Populating nix store on the device
      adb shell "gzip -d < $devicetmp | tar xf - -C ${prefix}/"
      adb shell rm $devicetmp

      adb shell "mkdir -p ${prefix}/nix/var/nix/profiles/ && ln -s ${deviceEnv} ${prefix}/nix/var/nix/profiles/default"
      adb shell "mkdir -p ${prefix}/bin/ && ln -s /nix/var/nix/profiles/default/bin/sh ${prefix}/bin/sh"

      # Provide handy script to enter an env with Nix
      adb push ${enterScript} ${prefix}/enter
      adb push ${cleanupScript} ${prefix}/cleanup
      adb push ${removalScript} ${prefix}/remove
      adb shell chmod +x ${prefix}/enter
      adb shell chmod +x ${prefix}/cleanup
      adb shell chmod +x ${prefix}/remove
      echo 'Polardroid has been installed, you can now run `adb shell` and then `${prefix}/enter` to enter your environment'

      # Fake `/etc/passwd` to make SSH work
      adb shell 'mkdir -p ${prefix}/etc/'
      adb shell 'echo "root:x:0:0::/:" > ${prefix}/etc/passwd'
    ''
  );

  remove = adbScript "polardroid-remove" (
    ''
      adb shell sh ${prefix}/remove
    ''
    + optionalString useTmpfs ''
      adb shell umount ${prefix}
      adb shell rmdir ${prefix}
    ''
    + ''

      echo "All traces of Polardroid removed."
    ''
  );

  sshConfig = writeText "polardroid-device-ssh-config" ''
    # Assume it's the host's username on any other host too
    User ${user}

    # This is the host machine the device is connected to
    Host host
      HostName 127.0.0.1
      Port ${rshPort}
      IdentityFile ~/.ssh/client-key
      # Disable ProxyJump for this machine for obvious reasons
      ProxyJump none

    # Every other machine is accessible via the host
    Host *
      ProxyJump host
      IdentityFile ~/.ssh/config.host.borg.keyFile
  '';

  # One step because you only need to run this once and it works from there on
  rshUp = writeShellScript "polardroid-rsh-up" ''
    echo 'Forwarding SSH port to host'
    adb reverse tcp:${rshPort} tcp:${rshPort}

    tmpdir=$(mktemp -d)

    ${getBin openssh}/bin/ssh-keygen -N "" -t ed25519 -f $tmpdir/client-key > /dev/null
    ${getBin openssh}/bin/ssh-keygen -N "" -t ed25519 -f $tmpdir/host-key > /dev/null

    adb shell mkdir -p ${prefix}/.ssh/
    adb push $tmpdir/client-key* ${prefix}/.ssh/
    ${optionalString (keyFile != null) "adb push ${keyFile} ${prefix}/.ssh/config.host.borg.keyFile"}
    adb shell chmod 600 ${prefix}/.ssh/*
    adb push ${sshConfig} ${prefix}/.ssh/config

    echo "[127.0.0.1]:${rshPort} ssh-ed25519 $(cut -f 2 -d ' ' $tmpdir/host-key.pub)" > $tmpdir/known_hosts
    adb push $tmpdir/known_hosts ${prefix}/.ssh/

    echo 'Starting new SSHD'
    ${openssh}/bin/sshd -f ${sshdConfigPatched} -o Port=${rshPort} -o HostKey=$tmpdir/host-key -o AuthorizedKeysFile=$tmpdir/client-key.pub -o PubkeyAuthentication=yes -o StrictModes=no &

    echo 'You can now reach your host using `ssh host` from the device'
    echo 'To stop this sshd and remove the forwards, run the `tearDownSshd` script.'
  '';

  rshDown = writeShellScript "polardroid-rsh-down" ''
    echo 'Removing all adb port forwards'
    adb forward --remove-all
    adb reverse --remove-all

    adb shell rm -r ${prefix}/.ssh

    pkill -f Port=${rshPort}
  '';
in
writeShellApplication {
  name = "polardroid";
  text = builtins.readFile ./cli.sh;
  runtimeEnv = {
    inherit
      install
      remove
      rshUp
      rshDown
      ;
      enableRsh = eval.config.host.rsh.enable;
  };

  derivationArgs = {
    passthru = {
      inherit eval;
    };
  };
}
