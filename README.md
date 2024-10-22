# Polardroid

Polardroid is a tool that aims to provide efficient full Android system backups by utilising [borgbackup](https://www.borgbackup.org/) to back up the Android userdata filesystem state.

The [Nix package manager](https://nixos.org/) and associated [Nixpkgs package distribution](https://github.com/NixOS/nixpkgs) are used to construct a software environment containing the required executables on the device. The backup environment and surrounding infrastructure are configured declaratively using a NixOS module system.

## Prerequisites

You must have root shell access to your Android device which requires an unlocked bootloader in most cases. Unlocking an Android device implies wiping userdata. If you have not unlocked your device, the system data held on the device is practically inaccessible to you and cannot be backed up.

You must have the Nix package manager installed. Its and surrounding projects' functions are fundamental to this project. You can install it beside your primary distribution without interference using the official installer on https://nixos.org/download/#nix-install-linux. macOS should work too but is less tested and has known limitations surrounding case sensitivity of software files to be installed onto the device.  
There is no support for M$ Windows. Install a proper operating system; perhaps using a VM/WSL if you have no other option.

## Usage

1. Bring your Android device into an (ideally) read-only state with root access. See [Getting a root shell](#getting-a-root-shell) on how to achieve that. Ensure that you can get into `adb shell` as root and that nothing else is running.
2. Configure the backup according to your setup, needs and preferences using the provided options in a configuration module. It works the same way your NixOS config works on NixOS but with a different set of options.
3. Run `nix-build --arg configuration ./path/to/your/configuration.nix`
4. Run `polardroid install` to install and then optionally `polardroid ssh setup` if you want to be able to access the host PC from the device.
5. Follow the printed instructions to enter the shell
6. Use the provided wrapper commands to [perform the backup](#performing-the-backup)

## Getting a root shell

You must have root access on your device in order to use this tool.

There are various ways to acquire root access on a device:

### `adb root`

Root debugging can be enabled in developer settings in `eng` and `usereng` builds. It is not typically possible in regular `user` builds that OEMs ship.

Once that is enabled, you can use `adb root` in order to restart adbd on the device as root; enabling a root shell via `adb shell`.

### Recovery

A recovery shell usually offers root privileges OOTB; enabling usage of this tool. Simply boot into recovery and enable ADB.

Note however that your recovery environment *must* support decrypting the Android userdata. You cannot do any useful backups without having your userdata decrypted. Currently, only TWRP is known to have this functionality but it may not always have support for the newest version of Android.

### Magisk

If you have Magisk installed, you may alternatively be able to reach a root shell at runtime via `su` but this project currently does not support privilege escalation via `su` yet.

## Atomic backup/Read-only state

In order to produce a backup that is integer, no process must be writing to the data while it is being backed up.  
If you are inside of an Android recovery environment, no other process should be writing to userdata OOTB. In a live Android environment however, the apps and system will be active of course.

In order to stop the entire system while retaining a root shell, Android provides the handy command `stop` which does precisely that. The extra paranoid can remount the userdata mount point (`/data`) read-only aswell for additional guarantees.

In order to "boot" into regular Android again, you can simply `adb reboot` or command Android to `start` again.

## Performing the backup

Once you are inside the installed nix environment, you can perform the backup using `borgCmd`. It will back up to the Borg repository that you have configured.

Before doing so, it can be worthwhile to check which data will be backed up. This is facilitated by the `ncduCmd` command. It receives the same set of excludes that are applied to Borg; allowing you to preview what would be backed up. Note that the exclude rule implementations are slightly different between these tools; ncdu rules will match any path with the same suffix for instance.

## Restoring and testing the backup

Backing up a dataset is one half of the process. The other is actually restoring it and ensuring that doing so is possible. A backup that you cannot restore is not a backup.

Restoring a backup has the same environmental requirements as producing one; you must have a root shell and no other processes writing to userdata.

Restoring a backup in full is sadly not possible. It currently not yet known why but it results in a boot loop. You must selectively restore parts of userdata. In this process you can also decide which parts of your backup you actually wish to restore.

### Restore a backup

Before you restore a backup, install your Android ROM onto the device (ideally the same ROM you took the backup on) and do the initial setup to the point where you can get a root shell. (Everything done here will be wiped during the restore.) It is not possible to restore to a blank userdata partition, you must let Android populate it first.

Once that is done, you can bring the device into a root+read-only state, install the nix environment and then use `borg extract` in order to restore certain files or directories:

```
borg extract --progress --numeric-ids ssh://youruser@127.0.0.1:4222/path/to/backup::backup-name /data/app
```

Once all the state you care about is restored, you can `adb reboot` and the device should boot into something that should quite closely resemble what you had before. Next finish restoring [state which this tool cannot back up](#Limitations) aswell as user data you may have backed up through other methods (i.e. Pictures).

### Android files and directories and their functions

This section lists the files and directories that contain certain user-relevant state. Use this as a reference for selecting the paths you wish to restore.

| Path                                               | Function                                                        |
|----------------------------------------------------|-----------------------------------------------------------------|
| `/data/app/`                                       | Installed app executables (APK/dex)                             |
| `/data/data/`                                      | Apps' internal state data                                       |
| `/data/system/package*`                            | App installation metadata (uid mapping etc.)                    |
| `/data/system/netpolicy`                           | Firewall settings                                               |
| `/data/system/users/0/`                            | User settings including Wallpaper, screen DPI, quick settings   |
| `/data/misc_de/0/apexdata/com.android.permission/` | App permission settings                                         |
| `/data/user_de/0/`                                 | Contacts, messages, phone etc.                                  |
| `/data/misc/apexdata/com.android.wifi`             | WiFi settings                                                   |
| `/data/system/notification_policy.xml`             | (App) Notification settings                                     |
| `/data/property/persistent_properties`             | Other more different settings (incl. bluetooth absolute volume) |
| `/data/user_de/0/org.lineageos.lineagesettings`    | LineageOS-specific settings                                     |
| `/data/misc/profiles/`                             | Some app data                                                   |
| `/data/system_ce/`                                 | Internal data and caches of some apps                           |

Restoring app data without also restoring the executables and app metadata will lead android to delete the app upon boot. You must always restore all 3.

Data of a singular apps or components can also be restored individually outside of the context of a full restore in case you accidentally modify or delete something you shouldn't have.

### Testing a backup

Backups can be tested by using another device. You can use an old and/or partially broken device for this purpose or make use of an emulator. (Note that an x86 Android may not be able to run all apps.) It is recommended that you disable internet access and/or not restore WiFi passwords when testing a restore as some apps may attempt to modify external state in a way that'd break using the original state of the app on your actual device again.

## Commands

| Command    | Function                                                                                             |
|------------|------------------------------------------------------------------------------------------------------|
| `install`  | Installs the nix environment onto a connected device                                                 |
| `remove`   | Removes an installed nix environment from a connected device                                         |
| `ssh up`   | Runs an unprivileged ssh daemon that facilitates access to the host machine from the Android device. |
| `ssh down` | Stops the host access provided by `ssh up` again.                                                    |

## Limitations

This tool cannot back up things that are bound to a piece of hardware inside of the device via Android's Keystore. This is typically used for the device unlock PIN but apps can also make use of it to make private key material non-extractable. Some prolific examples include decryption keys of E2EE Messengers such as Signal or Element, password managers and 2FA clients. Other apps with higher needs for security such as banking also frequently make use of this. You must back up those apps separately but fortunately, there aren't too many such cases and they usually provide their own backup mechanisms or do not require backups.

## Etymology

Polardroid heavily relies on Nix (symbolised by a lambda flake ❄️) to take snapshots 📷 of Android devices 🤖; freezing their state in time.

The pronunciation is emphasised like "polaroid".
