#!/usr/bin/env python3
"""Sample GTK window — DEVELOPMENT TOOL ONLY, not shipped on the ISO.

Shows the widgets the theme touches in a single frame: button, entry,
check box, switch, slider, progress bar and the window frame.
tools/theme-screenshot.sh and tools/panel-screenshot.sh open it while
taking their screenshots.

In stages 2 and 3 this file was on the ISO (with no panel yet there was
nothing else to show the theme). When the real panel arrived in stage 4
it moved here, among the development tools.

The labels are constants taken from the old appearance.* table (the
table was dropped when the po/ layout arrived); they come from the
`appearance.*` keys — no text was invented for this window.
"""

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk  # noqa: E402


def row(label, widget):
	box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
	lbl = Gtk.Label(label=label, xalign=0)
	lbl.set_size_request(150, -1)
	box.pack_start(lbl, False, False, 0)
	box.pack_start(widget, True, True, 0)
	return box


def build():
	win = Gtk.Window(title="Kavis")
	win.set_default_size(520, 380)
	win.set_position(Gtk.WindowPosition.CENTER)
	win.set_icon_name("kavis")
	win.connect("destroy", Gtk.main_quit)

	outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
	outer.set_border_width(18)
	win.add(outer)

	head = Gtk.Label(xalign=0)
	head.set_markup('<span size="x-large" weight="bold">Appearance</span>')
	outer.pack_start(head, False, False, 0)

	# The "Theme: Light / Dark" option is deliberately absent: Kavis was
	# single-theme (dark). A wallpaper chooser stands in to show the same
	# widget — the old one displayed a setting that did not exist and
	# gave the impression in screenshots that "the system is in the
	# light theme".
	combo = Gtk.ComboBoxText()
	for text in ("kavis", "kavis-night", "kavis-plain"):
		combo.append_text(text)
	combo.set_active(0)
	outer.pack_start(row("Wallpaper", combo), False, False, 0)

	entry = Gtk.Entry()
	entry.set_text("Kavis-Cursors")
	outer.pack_start(row("Cursor theme", entry), False, False, 0)

	scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 16, 64, 8)
	scale.set_value(24)
	outer.pack_start(row("Cursor size", scale), False, False, 0)

	switch = Gtk.Switch()
	switch.set_active(True)
	switch.set_halign(Gtk.Align.START)
	outer.pack_start(row("Show seconds", switch), False, False, 0)

	check = Gtk.CheckButton(label="Add installed apps to the desktop")
	check.set_active(True)
	outer.pack_start(check, False, False, 0)

	bar = Gtk.ProgressBar()
	bar.set_fraction(0.62)
	bar.set_show_text(True)
	outer.pack_start(row("Accent color", bar), False, False, 0)

	buttons = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
	buttons.set_halign(Gtk.Align.END)
	normal = Gtk.Button(label="Close")
	normal.connect("clicked", Gtk.main_quit)
	suggested = Gtk.Button(label="Apply")
	suggested.get_style_context().add_class("suggested-action")
	buttons.pack_start(normal, False, False, 0)
	buttons.pack_start(suggested, False, False, 0)
	outer.pack_end(buttons, False, False, 0)

	win.show_all()
	return win


def csd_window():
	"""A Kavis-style CSD window, next to the SSD one (C2).

	Mirrors packages/kavis-common/headerbar.vala: icon and title on the
	left, :minimize,maximize,close on the right, no centred title. Put
	beside a server-decorated window it makes the two title bars
	comparable in a single screenshot — the C2 claim is that they look
	the same, and that has to be shown, not asserted.
	"""
	win = Gtk.Window(title="Kavis (CSD)")
	win.set_default_size(420, 200)
	bar = Gtk.HeaderBar()
	bar.set_show_close_button(True)
	bar.set_decoration_layout(":minimize,maximize,close")
	row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
	row.pack_start(Gtk.Image.new_from_icon_name("kavis", Gtk.IconSize.MENU),
	               False, False, 0)
	label = Gtk.Label(label="Kavis (CSD)")
	label.get_style_context().add_class("title")
	row.pack_start(label, False, False, 0)
	row.show_all()
	bar.pack_start(row)
	empty = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
	empty.show()
	bar.set_custom_title(empty)
	bar.show()
	win.set_titlebar(bar)
	body = Gtk.Label(label="Client-side decoration")
	body.set_margin_top(24)
	win.add(body)
	win.move(60, 60)
	win.show_all()
	return win


def extra_window(index):
	"""Open one small plain window; used to crowd the taskbar."""
	win = Gtk.Window(title=f"Kavis {index}")
	win.set_default_size(200, 120)
	win.add(Gtk.Label(label=f"{index}"))
	win.show_all()
	return win


def main():
	import os
	build()
	# KAVIS_SAMPLE_CSD=1: also open a client-side-decorated window, so
	# one screenshot carries both title bar kinds (C2).
	csd = csd_window() if os.environ.get("KAVIS_SAMPLE_CSD") else None  # noqa: F841
	# KAVIS_SAMPLE_WINDOWS=N: open N-1 extra small windows for the taskbar
	# crowding test (stage 2: is the clock still visible with 30 windows).
	count = int(os.environ.get("KAVIS_SAMPLE_WINDOWS", "1"))
	extras = [extra_window(i) for i in range(2, count + 1)]  # noqa: F841
	# Nobody closes it in CI; staying open until the QEMU test ends is
	# enough, but an upper bound keeps it from living forever.
	GLib.timeout_add_seconds(900, Gtk.main_quit)
	Gtk.main()


if __name__ == "__main__":
	main()
