#!/usr/bin/env bash
# Kavis — do the versioned dependencies of the kavis-* packages hold
# against the real versions in the ISO? (item 72, kararlar.md 9a: DEPS-RANGE-OK)
#
# Usage: tools/check-deps-range.sh <package-list>
#   package-list: live-build's chroot.packages.live file
#   (`dpkg-query -W` format: "name<TAB>version", one package per line).
#
# Versioned Depends entries such as "name (>= x)" / "name (<< y)" are read
# from packages/*/debian/control; each is tested against the version in
# the list with `dpkg --compare-versions`. A package missing from the list
# is an ERROR (the dependency would already break at install; here it
# shows up by name).
# Exit code: 0 = all within range, 1 = at least one out of bounds / missing.
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
LIST=${1:-}
if [ -z "$LIST" ] || [ ! -r "$LIST" ]; then
	echo "usage: $0 <package-list>" >&2
	exit 2
fi

# Read a version from the list (name -> version). The part before the
# colon is taken so that architecture-qualified names (name:amd64) match too.
find_version() {
	awk -v name="$1" -F'\t' '{ split($1, p, ":"); if (p[1] == name) { print $2; exit } }' "$LIST"
}

fail=0
count=0
# Only versioned entries in the Depends block (not Build-Depends) of the
# control files: " openbox (>= 3.6.1)," → openbox / >= / 3.6.1
for control in "$REPO_ROOT"/packages/*/debian/control; do
	pkg=$(basename "$(dirname "$(dirname "$control")")")
	# sed: only the "name (op version)" pattern; fields like ${shlibs:Depends} are skipped
	while IFS='|' read -r name op bound; do
		[ -n "$name" ] || continue
		count=$((count + 1))
		version=$(find_version "$name")
		if [ -z "$version" ]; then
			echo "DEPS-RANGE-FAIL $pkg: $name ($op $bound) — not in the ISO list"
			fail=1
			continue
		fi
		if dpkg --compare-versions "$version" "$op" "$bound"; then
			echo "DEPS-RANGE $pkg: $name $version ($op $bound) ok"
		else
			echo "DEPS-RANGE-FAIL $pkg: $name $version, outside bound ($op $bound)"
			fail=1
		fi
	done < <(awk '/^Depends:/ { inside = 1; next } /^[A-Z]/ { inside = 0 } inside' "$control" \
		| sed -n 's/^ *\([a-z0-9.+-]*\) (\(>=\|<<\|>>\|<=\|=\) \([^)]*\)),\{0,1\}$/\1|\2|\3/p')
done

if [ "$count" -eq 0 ]; then
	echo "DEPS-RANGE-FAIL no versioned dependency found in the control files"
	exit 1
fi
if [ "$fail" -eq 0 ]; then
	echo "DEPS-RANGE-OK $count bounds within range"
	exit 0
fi
exit 1
