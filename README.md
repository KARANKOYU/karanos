<p align="center">
  <img src="assets/logo/koyu-k-logo.svg" width="120" alt="Kavis">
</p>

<h1 align="center">Kavis</h1>

<p align="center">
  A personal Debian-based Linux distribution with a Windows-like desktop.<br>
  <i>made by Karan</i>
</p>

---

## What it is

A desktop distribution based on Debian trixie; an amd64 ISO is produced today, the code is written multi-arch (arm64 preparation — see docs/gorev-listesi.md, ARCHITECTURE principle). It has its own boot
splash, login screen, taskbar, settings app and app store. We do not build
our own kernel — we use Debian's signed kernel, so Secure Boot can stay
enabled.

| Topic | Decision |
|---|---|
| Base | Debian stable (trixie), `live-build` |
| Display server / WM | X11 + Openbox |
| Our own software | Vala → C/GObject (GTK3 + libwnck), single binary |
| Root file system | btrfs (`@` + `@users`) |
| Installer | Calamares |
| Target ISO size | under 1.5 GB |
| Idle RAM | 1 GB target, 1.5 GB at most |

## Repository layout

```
kavis/
├── assets/       hand-placed source files (logo, boot image/music)
├── docs/         setup and design notes
├── iso/          live-build configuration
├── packages/     sources of the kavis-* .deb packages
├── installer/    Calamares configuration + pre-check module
├── tools/        development helpers (checks, QEMU test)
└── .github/workflows/   ISO build + package builds
```

## Building

**The ISO is not built locally.** Building and the QEMU test run on GitHub Actions:

GitHub → **Actions** → **"Build and test ISO"** → **Run workflow**

Details: [`iso/README.md`](iso/README.md)

Before pushing:

```bash
tools/check-config.sh      # syntax, permissions, YAML
tools/check-packages.sh    # do the package names exist in the Debian archive
```

Our own packages can be built locally (fast, unlike the ISO):

```bash
tools/build-packages.sh          # packages/* → out/packages/*.deb
tools/theme-screenshot.sh        # render the theme in Xvfb and save a PNG
tools/panel-screenshot.sh        # render the taskbar and save a PNG
```

## Setup (GitHub side)

Repositories, GitHub Pages, GPG key and secrets:
[`docs/github-kurulumu.md`](docs/github-kurulumu.md)

## Hand-placed files

| File | Status |
|---|---|
| `assets/logo/koyu-k-logo.svg` | ✅ ready |
| `assets/logo/acik-k-logo.svg` | ✅ ready |
| `assets/boot/boot-image.png` | ⏳ [specification](assets/boot/README.md) |
| `assets/boot/boot-sound.mp3` | ⏳ [specification](assets/boot/README.md) |

## Development order

Development follows the item list, which proceeds in groups; which
release ships when a group is done is in the roadmap:
[`docs/roadmap.md`](docs/roadmap.md)

Decision log: [`docs/durum.md`](docs/durum.md) ·
Old task definition (Karan OS era): [`docs/kavis-claude-code-prompt.md`](docs/kavis-claude-code-prompt.md) ·
UI translations (gettext): [`po/`](po/) ·
GitHub setup: [`docs/github-kurulumu.md`](docs/github-kurulumu.md)

## Translation status

Source strings are English; target languages are in [`po/LINGUAS`](po/LINGUAS).
To contribute, opening a `<lang>.po` is enough (Weblate will be connected
once the repo is public). CI updates the table on every run.

<!-- translation-status-begin -->
| Language | Status |
|---|---|
| `tr` | ▰▰▰▰▰▰▰▰▰▰ 100% (351/351) |
| _awaiting translation_ | `af` `am` `ar` `az` `be` `bg` `bn` `bs` `ca` `ckb` `cs` `cy` `da` `de` `el` `en_GB` `es` `es_MX` `et` `eu` `fa` `fi` `fr` `ga` `gl` `gu` `he` `hi` `hr` `hu` `hy` `id` `is` `it` `ja` `ka` `kk` `kn` `ko` `ku` `ky` `lt` `lv` `mk` `ml` `mn` `mr` `ms` `nb` `ne` `nl` `pa` `pl` `pt_BR` `pt_PT` `ro` `ru` `si` `sk` `sl` `sq` `sr` `sv` `sw` `ta` `te` `tg` `th` `tk` `tl` `uk` `ur` `uz` `vi` `zh_CN` `zh_TW` `zu` |
<!-- translation-status-end -->
