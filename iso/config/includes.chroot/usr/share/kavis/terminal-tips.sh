# shellcheck shell=bash
# Kavis terminal conveniences (madde 44). Sourced from /etc/bash.bashrc
# by the 0240 hook, AFTER Debian's own command-not-found block — this
# redefinition wins. English msgids, translations from gettext domain
# "kavis" (tools/gen-pot.sh scans this file too).

_kavis_pkg_translate () {
	# "dnf install x" / "pacman -S x" style commands from other
	# distros: show the apt equivalent and offer to run it.
	local from="$1" sub="" apt_cmd="" suggestion="" answer=""
	shift
	if [ $# -gt 0 ]; then
		sub="$1"
		shift
	fi
	case "$from:$sub" in
	pacman:-S)          apt_cmd="install" ;;
	pacman:-R|pacman:-Rs) apt_cmd="remove" ;;
	pacman:-Ss)         apt_cmd="search" ;;
	pacman:-Syu|pacman:-Su) apt_cmd="upgrade-all" ;;
	*:install)          apt_cmd="install" ;;
	*:remove|*:erase)   apt_cmd="remove" ;;
	*:search)           apt_cmd="search" ;;
	*:update|*:upgrade|*:refresh) apt_cmd="upgrade-all" ;;
	esac
	case "$apt_cmd" in
	install)     suggestion="sudo apt install $*" ;;
	remove)      suggestion="sudo apt remove $*" ;;
	search)      suggestion="apt search $*" ;;
	upgrade-all) suggestion="sudo apt update && sudo apt upgrade" ;;
	*)
		# shellcheck disable=SC2059
		printf "$(gettext 'This system uses apt, not %s. See: man apt')\n" \
			"$from"
		return 127
		;;
	esac
	# shellcheck disable=SC2059
	printf "$(gettext 'This system uses apt — the equivalent is: %s')\n" \
		"$suggestion"
	if [ -t 0 ]; then
		read -r -p "$(gettext 'Run it now? [y/N] ')" answer
		case "$answer" in
		y|Y|e|E) eval "$suggestion" ;;
		esac
	fi
	return 0
}

command_not_found_handle () {
	local cmd="$1" pkgs="" pkg="" answer=""
	shift
	export TEXTDOMAIN=kavis

	case "$cmd" in
	cls)
		clear
		return 0
		;;
	dir)
		# shellcheck disable=SC2059
		printf "$(gettext 'Windows command — the equivalent here is: %s')\n" \
			"ls -l"
		ls -l "$@"
		return $?
		;;
	ipconfig)
		# shellcheck disable=SC2059
		printf "$(gettext 'Windows command — the equivalent here is: %s')\n" \
			"ip addr"
		ip addr
		return $?
		;;
	dnf|yum|zypper|pacman|snap)
		_kavis_pkg_translate "$cmd" "$@"
		return $?
		;;
	esac

	# Paket önerisi: command-not-found'un DERLEMEDE hazırlanan
	# veritabanı (0240 hook). Modül yoksa/değiştiyse klasik araca düş.
	pkgs=$(python3 - "$cmd" 2>/dev/null <<'PYEOF'
import sys
try:
    from CommandNotFound import CommandNotFound
    cnf = CommandNotFound.CommandNotFound()
    for pkg, _comp in cnf.getPackages(sys.argv[1]):
        print(pkg)
except Exception:
    pass
PYEOF
)
	if [ -n "$pkgs" ]; then
		pkg=${pkgs%%$'\n'*}
		# shellcheck disable=SC2059
		printf "$(gettext "'%s' is not installed. It is in the '%s' package.")\n" \
			"$cmd" "$pkg"
		if [ -t 0 ]; then
			read -r -p "$(gettext 'Install it now? [y/N] ')" answer
			case "$answer" in
			y|Y|e|E) sudo apt install "$pkg" ;;
			esac
		fi
		return 127
	fi
	if [ -x /usr/lib/command-not-found ]; then
		/usr/lib/command-not-found -- "$cmd"
		return 127
	fi
	printf 'bash: %s: command not found\n' "$cmd" >&2
	return 127
}
