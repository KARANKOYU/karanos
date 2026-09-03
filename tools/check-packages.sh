#!/usr/bin/env bash
# Kavis — validate the package lists against the Debian trixie archive
#
# We do not build the ISO locally, but we also do not want to throw away a
# 40-minute CI build because of a typo in a package name.
# This script downloads Debian's package index and checks that every name
# under iso/config/package-lists/ really exists.
#
# Usage:  tools/check-packages.sh
#         KAVIS_ARCH=arm64 tools/check-packages.sh   # for another architecture
#
# `#if ARCHITECTURES <archs>` ... `#endif` blocks in the package lists are
# interpreted as live-build does: lines are skipped if the target
# architecture is not in the block.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST_DIR="$REPO_ROOT/iso/config/package-lists"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/kavis-pkgcheck"
SUITE="trixie"
MIRROR="https://deb.debian.org/debian"
AREAS=(main contrib non-free non-free-firmware)
# Target architecture from the variable; the string "amd64" is not
# hard-coded (multi-arch rule). Same default as auto/config.
ARCH="${KAVIS_ARCH:-amd64}"

mkdir -p "$CACHE_DIR"

echo "==> Debian $SUITE/$ARCH package indexes (cache: $CACHE_DIR)"
INDEX="$CACHE_DIR/packages-$ARCH.txt"

if [[ ! -s "$INDEX" || -n "${REFRESH:-}" ]]; then
	: > "$INDEX"
	for area in "${AREAS[@]}"; do
		url="$MIRROR/dists/$SUITE/$area/binary-$ARCH/Packages.xz"
		echo "    downloading: $area"
		curl -fsSL "$url" | xz -d | grep -E '^(Package|Provides): ' >> "$INDEX"
	done
	# Also extract the virtual packages from the "Provides" lines
	{
		grep '^Package: ' "$INDEX" | cut -d' ' -f2
		grep '^Provides: ' "$INDEX" | cut -d' ' -f2- | tr ',' '\n' \
			| sed 's/(.*)//' | tr -d ' '
	} | sort -u > "$INDEX.tmp"
	mv "$INDEX.tmp" "$INDEX"
fi

echo "    $(wc -l < "$INDEX") package names loaded"
echo

fail=0
total=0

for list in "$LIST_DIR"/*.list.chroot; do
	echo "==> $(basename "$list")"
	# live-build conditional state: 1 = lines apply to the target architecture
	block_active=1
	while IFS= read -r line; do
		# Interpret #if ARCHITECTURES a b ... / #endif blocks like live-build
		if [[ "$line" =~ ^#if[[:space:]]+ARCHITECTURES[[:space:]]+(.+)$ ]]; then
			block_active=0
			for m in ${BASH_REMATCH[1]}; do
				[[ "$m" == "$ARCH" ]] && block_active=1
			done
			continue
		fi
		if [[ "$line" =~ ^#endif ]]; then
			block_active=1
			continue
		fi
		(( block_active )) || continue
		pkg="${line%%#*}"
		pkg="$(echo "$pkg" | tr -d '[:space:]')"
		[[ -z "$pkg" ]] && continue
		total=$((total + 1))
		if grep -qxF "$pkg" "$INDEX"; then
			printf '    \033[32m✓\033[0m %s\n' "$pkg"
		else
			printf '    \033[31m✗ %s — NOT in the trixie/%s archive\033[0m\n' "$pkg" "$ARCH"
			fail=$((fail + 1))
		fi
	done < "$list"
	echo
done

# The Build-Depends and Depends names in packages/*/debian/control come
# from the same archive. A typo there breaks the .deb build in CI; here
# it is caught in a second.
for ctrl in "$REPO_ROOT"/packages/*/debian/control; do
	[[ -f "$ctrl" ]] || continue
	echo "==> $(basename "$(dirname "$(dirname "$ctrl")")")/debian/control"
	# Collect the field bodies, split on commas, drop version/arch constraints.
	# dpkg variables such as "${misc:Depends}" are not looked up.
	awk '
		/^(Build-Depends|Build-Depends-Indep|Depends|Recommends|Pre-Depends):/ { al=1; sub(/^[^:]*:/, ""); }
		/^[ \t]/ { if (al) print; next }
		/^[^ \t]/ { if (al && $0 !~ /^(Build-Depends|Depends|Recommends|Pre-Depends)/) al=0 }
		al { print }
	' "$ctrl" | tr ',|' '\n\n' | sed -e 's/(.*)//' -e 's/\[.*\]//' \
		-e 's/<.*>//' -e 's/[[:space:]]//g' | grep -v '^\${' | grep -v '^$' \
		| sort -u | while IFS= read -r pkg; do
		# Our own packages are not in the Debian archive; they are built
		# under packages/. Looking them up would always say "not found".
		if [[ "$pkg" == kavis-* ]]; then
			if [[ -d "$REPO_ROOT/packages/$pkg" ]]; then
				printf '    \033[32m✓\033[0m %s (our own package)\n' "$pkg"
			else
				printf '    \033[31m✗ %s — no such package under packages/\033[0m\n' "$pkg"
				echo "$pkg" >> "$CACHE_DIR/missing"
			fi
			continue
		fi
		if grep -qxF "$pkg" "$INDEX"; then
			printf '    \033[32m✓\033[0m %s\n' "$pkg"
		else
			printf '    \033[31m✗ %s — NOT in the trixie/%s archive\033[0m\n' "$pkg" "$ARCH"
			echo "$pkg" >> "$CACHE_DIR/missing"
		fi
	done
	echo
done

if [[ -s "$CACHE_DIR/missing" ]]; then
	fail=$((fail + $(wc -l < "$CACHE_DIR/missing")))
	total=$((total + $(wc -l < "$CACHE_DIR/missing")))
	rm -f "$CACHE_DIR/missing"
fi

echo "==================================================="
if (( fail == 0 )); then
	echo "OK: all $total packages exist in the Debian $SUITE archive."
	exit 0
else
	echo "ERROR: $fail of $total packages not found."
	echo "Fix the name or drop the package from the list, then run again."
	exit 1
fi
