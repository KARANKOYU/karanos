#!/usr/bin/env python3
"""Örnek GTK penceresi — YALNIZCA GELİŞTİRME ARACI, ISO'ya girmiyor.

Temanın dokunduğu bileşenleri tek karede gösteriyor: düğme, giriş
kutusu, onay kutusu, anahtar, kaydırıcı, ilerleme çubuğu ve pencere
çerçevesi. tools/theme-screenshot.sh ve tools/panel-screenshot.sh
ekran görüntüsü alırken bunu açıyor.

2. ve 3. aşamada bu dosya ISO'ya giriyordu (panel yokken temayı
gösterecek başka bir şey yoktu). 4. aşamada gerçek panel gelince
buraya, geliştirme araçlarının arasına taşındı.

Etiketler eski appearance.* tablosundan alınmış sabitler (tablo po/
düzenine geçince kaldırıldı); `appearance.*`
anahtarlarından alınmıştır; bu pencereye özgü metin uydurulmadı.
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
	head.set_markup('<span size="x-large" weight="bold">Görünüm</span>')
	outer.pack_start(head, False, False, 0)

	# "Tema: Açık / Koyu" seçeneği kasten yok: Kavis tek temalı (koyu).
	# Aynı bileşeni göstermek için yerine duvar kağıdı seçici kondu —
	# eskisi var olmayan bir ayarı gösteriyordu ve ekran görüntüsünde
	# "sistem açık temada" izlenimi veriyordu.
	combo = Gtk.ComboBoxText()
	for text in ("kavis", "kavis-gece", "kavis-duz"):
		combo.append_text(text)
	combo.set_active(0)
	outer.pack_start(row("Duvar kağıdı", combo), False, False, 0)

	entry = Gtk.Entry()
	entry.set_text("Kavis-Cursors")
	outer.pack_start(row("İmleç teması", entry), False, False, 0)

	scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 16, 64, 8)
	scale.set_value(24)
	outer.pack_start(row("İmleç boyutu", scale), False, False, 0)

	switch = Gtk.Switch()
	switch.set_active(True)
	switch.set_halign(Gtk.Align.START)
	outer.pack_start(row("Saniyeleri göster", switch), False, False, 0)

	check = Gtk.CheckButton(label="Kurulan uygulamaları masaüstüne ekle")
	check.set_active(True)
	outer.pack_start(check, False, False, 0)

	bar = Gtk.ProgressBar()
	bar.set_fraction(0.62)
	bar.set_show_text(True)
	outer.pack_start(row("Vurgu rengi", bar), False, False, 0)

	buttons = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
	buttons.set_halign(Gtk.Align.END)
	normal = Gtk.Button(label="Kapat")
	normal.connect("clicked", Gtk.main_quit)
	suggested = Gtk.Button(label="Uygula")
	suggested.get_style_context().add_class("suggested-action")
	buttons.pack_start(normal, False, False, 0)
	buttons.pack_start(suggested, False, False, 0)
	outer.pack_end(buttons, False, False, 0)

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
	build()
	# KAVIS_ORNEK_SAYISI=N: görev çubuğu sıkışma testi için N-1 ek küçük
	# pencere aç (Aşama 2: 30 pencereyle saat hâlâ görünüyor mu).
	import os
	count = int(os.environ.get("KAVIS_ORNEK_SAYISI", "1"))
	extras = [extra_window(i) for i in range(2, count + 1)]  # noqa: F841
	# CI'da kimse kapatmıyor; QEMU testi bitene kadar açık kalması yeterli
	# ama sonsuza kadar açık kalmasın diye üst sınır koyuyoruz.
	GLib.timeout_add_seconds(900, Gtk.main_quit)
	Gtk.main()


if __name__ == "__main__":
	main()
