# iso/ — ISO configuration

`live-build` configuration for the Debian trixie based Kavis ISO.

## ⚠️ Do NOT build locally in this folder

The ISO is built on **GitHub Actions**. Building in the Codespace has two problems:

1. 2 cores — debootstrap + squashfs compression takes 40+ minutes
2. Disk — chroot + squashfs + ISO need ~15 GB at once; we have 20 GB free

Instead: **build + QEMU test on Actions**; the result comes back as a serial
console log and screenshots. When you want to try the ISO in VirtualBox or
on a USB stick, download it from the `kavis-iso` artifact (about 10 minutes
at ~1 MB/s).

## Starting a build

GitHub → **Actions** tab → **"ISO derle ve test et"** → **Run workflow**
→ (optionally enter a version) → **Run workflow**

It also runs automatically whenever something under `iso/` is pushed to `main`.

Result:
- ISO size and sha256 in the **Summary** section
- `kavis-iso` under **Artifacts** (kept for 14 days)
- `serial-bios`, `serial-uefi`, `serial-secureboot` logs, one per boot mode

## Local checks to run before pushing

```bash
# Do the package names really exist in the Debian trixie archive? (~2 seconds)
tools/check-packages.sh

# Script syntax
tools/check-config.sh
```

Do not push until both pass — the CI build takes 40 minutes; not worth waiting for a typo.

## Layout

```
iso/
├── auto/
│   ├── config          ← ALL lb config parameters live here (never pass lb config by hand)
│   ├── build
│   └── clean
└── config/
    ├── package-lists/
    │   ├── 01-base.list.chroot       kernel, init, network, file systems, bootloader
    │   ├── 02-x11.list.chroot        X11 + Openbox + terminal + Python/GTK
    │   └── 03-firmware.list.chroot   Wi-Fi/audio/graphics firmware (prompt 16)
    ├── includes.chroot/              files copied into the ISO as-is
    │   ├── etc/lightdm/lightdm.conf.d/60-kavis-live.conf   live autologin (temporary)
    │   ├── etc/xdg/openbox/autostart                          session startup
    │   ├── etc/systemd/system/kavis-boot-check.service      CI smoke test
    │   └── usr/lib/kavis/boot-check                         the "did I boot?" script
    └── hooks/normal/
        ├── 0100-kavis-services.hook.chroot   enable services
        ├── 9990-apt-recommends.hook.chroot     re-enable Recommends on the installed system
        └── 9995-cleanup.hook.chroot            size cleanup
```

## Deliberate decisions

| Decision | Why |
|---|---|
| `--apt-recommends false` | Lightness (prompt 20). The price: every needed package must be listed explicitly. Re-enabled on the installed system by the `9990` hook. |
| `--firmware-chroot false` + manual list | We do not want live-build to add every `firmware-*` package indiscriminately; the list from prompt 16 is given under control. |
| `--uefi-secure-boot enable` | Uses Debian's signed `shim` + `grub`. We do not build our own kernel, so Secure Boot can stay on (prompt 2, 18). |
| `--debian-installer none` | Installation is done with Calamares (prompt 14). Debian Installer is not embedded in the ISO. |
| `console=ttyS0` on the boot line | So the QEMU test in CI can read the boot log. No effect on real hardware without a serial port. |
| `quiet splash` **off** | We want to see the boot messages in stage 1. Turned on in stage 3 (Plymouth). |
| `set timeout=10` added to GRUB by hand | **live-build does not put it there.** With timeout undefined the GRUB menu waits for a key forever; all three QEMU tests got stuck on this in the first CI run. `hooks/normal/9500-grub-timeout.hook.binary` adds it. |
| GRUB also writes to the serial console | live-build says `terminal_output gfxterm`, i.e. GRUB output goes only to the screen. Without the serial console a bootloader error never shows up in the CI log. |
| lightdm autologin | Temporary. Goes away when `kavis-greeter` arrives in stage 5; on the installed system Calamares deletes this file. |

## What changes in the next stages

- **Stage 2:** the `kavis-theme` package enters the list, `/etc/os-release` changes
- **Stage 3:** `plymouth` + `kavis-boot` enter, `quiet splash` is added to the boot line
- **Stage 4:** `kavis-panel` is added to `openbox/autostart`
- **Stage 5:** `kavis-greeter` replaces `lightdm`, `60-kavis-live.conf` is deleted
