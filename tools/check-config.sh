#!/usr/bin/env bash
# Kavis — quick checks to run before pushing
#
# The ISO build takes 40 minutes in CI. So that a typo does not burn that
# time, syntax and file integrity are checked here first.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

fail=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗ %s\033[0m\n' "$*"; fail=1; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

# Which interpreter to check with is decided from the file's own shebang.
# includes.chroot holds both sh and Python scripts; trying `sh -n` on all
# of them produced false errors on the Python files.
check_syntax() {
	local f="$1" line
	line=$(head -1 "$f")
	case "$line" in
	*python*) python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$f" 2>/dev/null ;;
	*bash*) bash -n "$f" 2>/dev/null ;;
	*) sh -n "$f" 2>/dev/null ;;
	esac
}

echo "==> Script syntax"
for f in iso/auto/config iso/auto/build iso/auto/clean \
         iso/config/hooks/normal/*.hook.* \
         iso/config/includes.chroot/usr/lib/kavis/* \
         packages/*/tools/*.py \
         packages/*/debian/pre* packages/*/debian/post* \
         tools/*.sh; do
	[[ -f "$f" ]] || continue
	if check_syntax "$f"; then ok "$f"; else bad "$f — syntax error"; fi
done

echo
echo "==> Execute permissions"
for f in iso/auto/config iso/auto/build iso/auto/clean \
         iso/config/hooks/normal/*.hook.* \
         iso/config/includes.chroot/usr/lib/kavis/* \
         packages/*/debian/rules packages/*/tools/*.py \
         tools/*.sh; do
	[[ -f "$f" ]] || continue
	if [[ -x "$f" ]]; then ok "$f"; else bad "$f — not executable (chmod +x)"; fi
done

echo
echo "==> GitHub Actions YAML"
for f in .github/workflows/*.yml; do
	if python3 -c "import yaml,sys; yaml.safe_load(open('$f'))" 2>/dev/null; then
		ok "$f"
	else
		bad "$f — invalid YAML"
	fi
done

echo
echo "==> Host guard in the chroot hooks (4 Sep 2026 incident)"
# A hook without the guard can wreck a developer machine: these scripts
# rewrite /home, /etc, the initramfs and systemd state of whatever system
# they run on. The marker file only exists inside the build chroot.
for f in iso/config/hooks/normal/*.hook.chroot; do
	if grep -q '/usr/share/kavis/build-marker' "$f"; then
		ok "$(basename "$f") — host guard present"
	else
		bad "$(basename "$f") — host guard MISSING"
	fi
done
# The root helpers are the other thing that must never run on a
# workstation; set-power writes /sys and /etc/systemd.
for helper in packages/kavis-settings/scripts/set-power \
	packages/kavis-settings/scripts/set-dns \
	packages/kavis-settings/scripts/hw-report; do
	if grep -q '/run/systemd/system' "$helper" \
		&& grep -q '/usr/share/kavis/build-marker' "$helper"; then
		ok "$(basename "$helper") — host guard present"
	else
		bad "$(basename "$helper") — host guard MISSING (it writes /sys and /etc)"
	fi
done
[[ -f iso/config/includes.chroot/usr/share/kavis/build-marker ]] \
	&& ok "build-marker ships in includes.chroot" \
	|| bad "includes.chroot/usr/share/kavis/build-marker missing — every hook would refuse to run"

echo
echo "==> Build dependencies reach CI"
# A Build-Depends the CI container does not install fails the run at
# dpkg-checkbuilddeps, minutes in, with a message nobody sees until they
# open the log. libpam0g-dev did exactly that. Every name in every
# package's Build-Depends must also be in the workflow's install step.
CI_WORKFLOW=.github/workflows/build-packages.yml
missing_deps=""
for control in packages/*/debian/control; do
	# The Build-Depends block: from that line to the next field.
	deps=$(sed -n '/^Build-Depends:/,/^[A-Z][A-Za-z-]*:/p' "$control" \
		| sed '1d;$d' | tr -d ' ' | tr ',' '\n' | sed 's/(.*)//' | grep -v '^$')
	for dep in $deps; do
		# debhelper-compat is a virtual build-profile thing; the
		# container has it through debhelper itself.
		case "$dep" in debhelper-compat) continue ;; esac
		grep -q -- "$dep" "$CI_WORKFLOW" || missing_deps="$missing_deps $dep"
	done
done
if [[ -z "$missing_deps" ]]; then
	ok "every Build-Depends appears in $CI_WORKFLOW"
else
	bad "not installed by CI:$missing_deps"
fi

echo
echo "==> Application names (D1)"
# The title bar is rewritten from this map, the menu comes from the
# .desktop overrides. A name in one and not the other means the same
# program is called two things on the same screen.
TITLE_MAP=iso/config/includes.chroot/etc/kavis/window-title-map.conf
APP_DIR=iso/config/includes.chroot/etc/kavis/applications
if [[ -f "$TITLE_MAP" ]]; then
	while IFS='=' read -r vendor kavis; do
		vendor="${vendor%"${vendor##*[![:space:]]}"}"
		kavis="${kavis#"${kavis%%[![:space:]]*}"}"
		[[ -z "$vendor" || "$vendor" == \#* ]] && continue
		if grep -qh "^Name=.*\b${kavis}\b" "$APP_DIR"/*.desktop; then
			ok "title map $vendor → $kavis matches a .desktop override"
		else
			bad "title map renames $vendor to '$kavis', but no .desktop override uses that name"
		fi
	done < "$TITLE_MAP"
else
	bad "$TITLE_MAP missing — title bars would keep the vendor names"
fi

echo
echo "==> Settings index and shortcut catalogue (item 74)"
# Two declarative tables that are only useful while they still agree
# with the code beside them; the drift they guard against had already
# happened once (the Settings shortcut list said Ctrl+Win+arrows while
# the openbox hook bound Ctrl+Alt+arrows).
if out=$(tools/check-settings-index.py 2>&1); then
	ok "$out"
else
	printf '%s\n' "$out"
	bad "the Settings index or the shortcut catalogue has drifted"
fi

echo
echo "==> Shared sources: the canonical file, not the copy"
# packages/kavis-common/*.vala are the originals; build-packages.sh
# copies them into each package's src/logic and .gitignore hides the
# copies. Editing a copy therefore looks like it worked — the build
# passes, the running binary has the change — and then the next build
# overwrites it and the commit never carried it. That happened to the
# light-theme palette in this very round, and it is invisible in
# `git status` by design.
shared_drift=0
for canonical in packages/kavis-common/*.vala; do
	name=$(basename "$canonical")
	for copy in packages/*/src/logic/"$name"; do
		[[ -f "$copy" ]] || continue
		if ! diff -q "$canonical" "$copy" >/dev/null 2>&1; then
			bad "$copy differs from $canonical — the edit belongs in the canonical file"
			shared_drift=1
		fi
	done
done
[[ "$shared_drift" -eq 0 ]] && ok "every shared source matches its canonical copy"

echo
echo "==> Text contrast in both themes (feedback C)"
# The light theme shipped with Kavis' own accents left at their dark
# values, so everything the panel painted itself was 1.7:1 on white.
# Measured now, in both palettes, against WCAG 4.5:1.
if out=$(tools/check-contrast.py 2>&1); then
	while IFS= read -r line; do
		[[ -n "$line" ]] && ok "${line# }"
	done <<< "$out"
else
	printf '%s\n' "$out"
	bad "text and background are too close in one of the palettes"
fi

echo
echo "==> Hand-placed asset files"
[[ -f assets/logo/koyu-k-logo.svg ]] && ok "assets/logo/koyu-k-logo.svg" \
	|| bad "assets/logo/koyu-k-logo.svg missing"
[[ -f assets/logo/acik-k-logo.svg ]] && ok "assets/logo/acik-k-logo.svg" \
	|| bad "assets/logo/acik-k-logo.svg missing"
[[ -f assets/boot/boot-image.png ]] && ok "assets/boot/boot-image.png" \
	|| warn "assets/boot/boot-image.png not placed yet (needed in stage 3)"
[[ -f assets/boot/boot-sound.mp3 ]] && ok "assets/boot/boot-sound.mp3" \
	|| warn "assets/boot/boot-sound.mp3 not placed yet (needed in stage 3)"

echo
echo "==================================================="
if (( fail == 0 )); then
	echo "OK — safe to push."
	echo "To verify package names as well: tools/check-packages.sh"
	exit 0
else
	echo "ERROR — fix the ✗ lines above."
	exit 1
fi
