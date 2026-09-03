# kavis-boot

Boot splash: the Plymouth theme, the boot music and the systemd
mechanism that holds the splash until the music ends.

## Behavior (madde 30)

1. Plain dark background (#0D141B) — no wallpaper/photo. The **dark
   logo** in the center (rule: always koyu-k-logo at boot) appears at
   **15% opacity**, rises to 100% in ~1.5 seconds and gets a slight
   glow (which breathes slowly afterwards)
2. The product name below the logo (generated at build time **from
   os-release NAME**, with Turkish upper-case rules — "KAVİS"), the
   italic **made by Karan** below it, and two hint lines at the bottom:
   "F3 — Advanced menu" and "Press space to skip"
3. The boot music plays at the same time
4. The splash closes **0.5 seconds** after the music ends; it waits even
   when the system is ready earlier, the music is never cut short. The
   image and the sound fade out together before closing. **The single
   exception is the space key**: when pressed the music stops and the
   boot continues at once (the boot-sound script listens with
   `plymouth watch-keystroke`)
5. If there is no audio device or playback hangs, at most **10
   seconds** are waited and the boot continues. The music plays once,
   never loops
6. The behavior can be changed through `/etc/kavis/boot.conf`
   (Settings will manage it in madde 38): `PLAY_MUSIC=0` never plays the
   music, `WAIT_FOR_MUSIC=0` plays it in the background, the splash does
   not wait

The F3 advanced menu is on the GRUB side: `iso/config/hooks/normal/`
`9601-grub-advanced.hook.binary` writes it (safe mode, verbose logs,
memtest86+ on amd64 only, UEFI settings).

## What holds the splash until the music ends

`kavis-boot-sound.service` is `Type=oneshot`. It counts as "starting"
until the music has played and the short fade-out has passed. The
drop-ins placed for `plymouth-quit.service` and
`plymouth-quit-wait.service` make them wait for this service:

```
plymouth-quit.service.d/kavis.conf → After=kavis-boot-sound.service
```

Even if the sound service fails it still terminates, so the boot never
locks up. The service's `TimeoutStartSec=30` is a safety net above the
script's own wait+play limits (8+10 s).

## Decisions taken

**The italic text is embedded as PNG.** Plymouth uses bitmap fonts with
no italic support. Drawing the text with our own framebuffer program
would mean writing Plymouth a second time. `src/made-by-karan.svg` is
converted to PNG with `rsvg-convert` at package build — no font
dependency at boot and the result is identical on every machine.

**The music is embedded as WAV, not mp3.** Two reasons: most mp3
players have no fade-out and section 5 says "image and sound fade out
softly together"; also no mp3 decoder is needed at boot, `aplay` is
enough. The conversion happens with `ffmpeg` at package build, adding a
0.4-second fade at the end. The cost is ~1 MB of ISO space.

**The theme enters the initramfs through a separate hook.**
`plymouth-set-default-theme -R` would do it in one step, but generating
the initramfs on every package install adds minutes to the build in the
live-build chroot. `postinst` only selects the theme;
`iso/config/hooks/normal/0300-plymouth.hook.chroot` generates the
initramfs once and **verifies the theme really made it in** — if not,
the build stops, because otherwise a black screen appears at boot and
the cause cannot be found without booting the ISO.

**Single copy of the image.** The original lives in the theme directory
(`logo.png`); the `/usr/share/kavis/boot/boot-image.png` that section 5
asks for is a link to it. The other way around, the link would break
when the theme directory is copied into the initramfs.

## Build

```bash
tools/build-packages.sh kavis-boot
```

The sources are copied from `assets/boot/` into `src/boot/` (the copy
is in `.gitignore`). `ffmpeg`, `librsvg2-bin` and `fonts-dejavu-core`
are build dependencies.

## How to see it

The splash is on screen only during boot and `plymouth-x11` does not
exist in Debian, so it cannot be rendered locally. That is why the
smoke test takes a separate frame 10 seconds after the kernel starts:
**`screen-<mode>-acilis.png`** in the `tani-<mode>` artifact.

## VirtualBox note — vmwgfx error

With VirtualBox's **VMSVGA** display controller the kernel reports:

```
vmwgfx: [drm] *ERROR* vmwgfx seems to be running on an unsupported hypervisor
```

The cause is VirtualBox not emulating VMware completely; the `vmwgfx`
driver binds but does not work. The result can be KMS being disabled,
and Plymouth falls back to text mode instead of DRM — no splash.

What is done on the Kavis side:
- `simpledrm` is in the initramfs; even if vmwgfx fails, a DRM device
  remains on top of the UEFI framebuffer.
- `boot-check` reports the contents of `/dev/dri` and which renderer
  Plymouth picked on every boot in its `DRM-DEVICES` line.

What can be done on the VirtualBox side: set **Display → Graphics
Controller** to `VBoxSVGA` in the machine settings. Then the
`vboxvideo` driver takes over (it is in the initramfs) and the error
disappears.

**Verified:** switching to VBoxSVGA removed both the `vmwgfx` error and
the console text after the splash.
