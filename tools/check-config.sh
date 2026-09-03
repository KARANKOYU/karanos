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
