#!/usr/bin/env bash
# Kavis — Codespace / dev container provisioning (postCreateCommand).
#
# The 4 Sep 2026 container rebuild cost an afternoon because the toolchain
# was installed by hand and nothing recorded it. Everything the repo needs
# to build and test locally is listed here, once.
#
# NOT installed on purpose: qemu-system-x86 (the smoke test runs in CI; a
# local VM is a deliberate, occasional `apt-get install`), and anything
# that touches users, /home or systemd — see the host rule in CLAUDE.md.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

packages=(
	# Vala/GTK build (Build-Depends of the kavis-* packages)
	valac libgtk-3-dev libwnck-3-dev libgstreamer1.0-dev
	meson ninja-build
	# Debian packaging
	debhelper devscripts dpkg-dev fakeroot
	# Assets generated at build time
	ffmpeg librsvg2-bin python3-gi gir1.2-gtk-3.0 python3-pil
	# ISO tooling (lb build itself only runs in CI, the config is linted here)
	live-build xorriso
	# Headless UI tests: check-keybinds.sh, check-snap.sh, panel-screenshot.sh
	xvfb openbox xdotool x11-utils x11-apps xterm xfonts-base xwallpaper picom
	# Emoji picker screenshots need the same font the ISO ships
	fonts-noto-color-emoji
	# Translations and linting
	gettext shellcheck
	# Large binary assets
	git-lfs
)

sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends "${packages[@]}"

git lfs install --skip-repo

# Claude Code itself, so a rebuilt container comes back ready to work.
npm install -g @anthropic-ai/claude-code

echo "Kavis dev container ready: $(valac --version 2>/dev/null || echo 'valac missing')"
