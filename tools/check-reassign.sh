#!/usr/bin/env bash
# Kavis — a reassigned shortcut actually works (item 74).
#
# WHY THIS EXISTS. Settings can write a perfectly correct
# ~/.config/openbox/rc.xml and the new key can still do nothing, which
# is what the v0.5-test5 and v0.5-test6 ISO runs both showed: the file
# had the new binding, the old one was gone, and forty seconds of
# pressing the key opened nothing.
#
# `openbox --reconfigure` re-reads the config file openbox resolved AT
# STARTUP, and openbox resolves it once. A session that began with no
# user rc.xml resolved the system one, so writing a user copy afterwards
# and asking for a reconfigure re-reads the system file — the FIRST
# reassignment anybody makes is the one that silently fails.
#
# Kavis' answer is that the user copy ALWAYS exists: seeded before the
# session (0031-kavis-dirs) and regenerated from the system file at
# every login (openbox autostart), so it is always openbox's own path
# and always current. This check mirrors that: openbox is started with
# NO --config-file, the "system" rc lives in an XDG_CONFIG_DIRS
# directory, and the user copy is in place before openbox starts —
# exactly the ISO's arrangement.
#
# Usage: tools/check-reassign.sh
# Exit: 0 = REASSIGN-OK
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

DISPLAY_NO=${DISPLAY_NO:-79}
HOOK=iso/config/hooks/normal/0210-openbox-keybinds.hook.chroot
CATALOG=iso/config/includes.chroot/usr/share/kavis/shortcuts.list
SET_SHORTCUTS=packages/kavis-settings/scripts/set-shortcuts

missing=""
for tool in Xvfb openbox xdotool xprop xterm; do
	command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
[ -z "$missing" ] || { echo "ERROR: missing tools:$missing" >&2; exit 2; }

T=$(mktemp -d)
LOG="$T/calls.log"
trap 'kill ${OB_PID:-} ${XV_PID:-} 2>/dev/null; rm -rf "$T"' EXIT

# The system rc, built the way the ISO builds it.
mkdir -p "$T/xdg/openbox" "$T/config/kavis" "$T/bin"
cp /etc/xdg/openbox/rc.xml "$T/xdg/openbox/rc.xml"
sed -e "s|^RC=/etc/xdg/openbox/rc.xml|RC=$T/xdg/openbox/rc.xml|" \
    -e "s|^CATALOG=/usr/share/kavis/shortcuts.list|CATALOG=$CATALOG|" \
    -e '/--- Host guard/,/^fi$/d' "$HOOK" > "$T/hook.sh"
sh "$T/hook.sh" >/dev/null || { echo "ERROR: the 0210 hook failed" >&2; exit 2; }

# nemo is what Win+E runs; the stub records that it was called.
cat > "$T/bin/nemo" <<EOS
#!/bin/sh
echo "nemo \$*" >> "$LOG"
EOS
chmod +x "$T/bin/nemo"

# The user copy, seeded the way 0031-kavis-dirs seeds it — BEFORE
# openbox starts, which is the whole point.
mkdir -p "$T/config/openbox"
cp "$T/xdg/openbox/rc.xml" "$T/config/openbox/rc.xml"

export DISPLAY=":$DISPLAY_NO"
export XDG_CONFIG_HOME="$T/config"
export XDG_CONFIG_DIRS="$T/xdg"
export PATH="$T/bin:$PATH"
export HOME="$T"

Xvfb "$DISPLAY" -screen 0 1280x800x24 >/dev/null 2>&1 &
XV_PID=$!
for _ in $(seq 1 20); do [ -S "/tmp/.X11-unix/X$DISPLAY_NO" ] && break; sleep 0.5; done

# NO --config-file, and started through --startup the way
# openbox-session does on the ISO: openbox has to resolve the path the
# way it does in a real session, and it re-execs its ORIGINAL argv on a
# restart, so how it was started is part of what is being tested.
openbox --startup /bin/true >/dev/null 2>&1 &
OB_PID=$!
for _ in $(seq 1 20); do
	xprop -root _OB_VERSION 2>/dev/null | grep -q "3\." && break; sleep 0.5
done
xprop -root _OB_VERSION 2>/dev/null | grep -q "3\." || {
	echo "ERROR: openbox did not start" >&2; exit 2; }

fail=0
press() { xdotool key --clearmodifiers "$1"; sleep 1.5; }
called() { grep -q "^nemo" "$LOG" 2>/dev/null; }
expect() { # expect <what> <yes|no>
	local want="$2" got=no
	called && got=yes
	if [ "$got" = "$want" ]; then
		printf '  \033[32m✓\033[0m %s\n' "$1"
	else
		printf '  \033[31m✗\033[0m %s — expected %s, got %s\n' "$1" "$want" "$got"
		fail=1
	fi
	: > "$LOG"
}

: > "$LOG"
press super+e
expect "the shipped default (Win+E) opens Files" yes
press super+y
expect "Win+Y does nothing yet" no

# What Settings writes when somebody moves the shortcut.
printf '[shortcuts]\nfiles=W-y\n' > "$T/config/kavis/kavis.conf"
KAVIS_SHORTCUT_CATALOG="$PWD/$CATALOG" \
KAVIS_SYSTEM_RC="$T/xdg/openbox/rc.xml" \
KAVIS_CONF="$T/config/kavis/kavis.conf" \
KAVIS_USER_RC="$T/config/openbox/rc.xml" \
	sh "$SET_SHORTCUTS" >/dev/null 2>&1
sleep 2

grep -q 'key="W-y"' "$T/config/openbox/rc.xml" || {
	echo "  ✗ set-shortcuts did not write the new key" >&2; fail=1; }

: > "$LOG"
press super+y
expect "THE POINT: the reassigned key (Win+Y) opens Files" yes
press super+e
expect "and the old key no longer does" no

# And removing the last override has to come back the same way. The
# user copy is not deleted — it becomes the system file verbatim,
# because a session that loses the file it resolved at startup keeps
# reading a file that is gone.
printf '[shortcuts]\n' > "$T/config/kavis/kavis.conf"
KAVIS_SHORTCUT_CATALOG="$PWD/$CATALOG" \
KAVIS_SYSTEM_RC="$T/xdg/openbox/rc.xml" \
KAVIS_CONF="$T/config/kavis/kavis.conf" \
KAVIS_USER_RC="$T/config/openbox/rc.xml" \
	sh "$SET_SHORTCUTS" >/dev/null 2>&1
sleep 2
: > "$LOG"
press super+e
expect "removing the override brings Win+E back" yes
[ -e "$T/config/openbox/rc.xml" ] || {
	echo "  ✗ the user copy was deleted — openbox would keep reading a file that is gone" >&2
	fail=1
}

[ "$fail" -eq 0 ] || { echo "REASSIGN-FAIL"; exit 1; }
echo "REASSIGN-OK: a moved shortcut works, and moving it back works too"
