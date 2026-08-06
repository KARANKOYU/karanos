"""Görev çubuğu.

Yerleşim (bölüm 8): solda K logolu başlat düğmesi, ortada açık
pencereler, sağda sanal masaüstü göstergesi, klavye dili, saat ve
masaüstünü gösterme düğmesi.

Sistem tepsisi (ağ, ses, pil simgeleri) burada YOK — XEmbed/StatusNotifier
tepsisi kendi başına bir iş ve 10. aşamadaki karanos-tools ile birlikte
gelecek. Panelin sağ ucundaki göstergeler şimdilik doğrudan sistemden
okunuyor.
"""

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Wnck", "3.0")
from gi.repository import Gdk, GLib, Gtk, Wnck  # noqa: E402

from . import gosterge
from .baslat import BaslatMenusu
from .metinler import M

YUKSEKLIK = 44
DUGME_AZAMI_GENISLIK = 190

# Türkçe yorumlar yüzünden bytes değil str; GTK'ya verirken kodluyoruz.
CSS = """
.karanos-panel {
  background-color: #121C26;
  border-top: 1px solid #233A45;
}
.karanos-panel button {
  border: none;
  border-radius: 0;
  background-image: none;
  background-color: transparent;
  color: #E6EDF3;
  padding: 0 10px;
}
.karanos-panel button:hover {
  background-color: #1D2C38;
}
/* Etkin pencere: altında turkuaz şerit — Windows'taki gibi hangi
   pencerede olduğun bir bakışta belli olsun. */
.karanos-panel button.etkin {
  background-color: #1D2C38;
  box-shadow: inset 0 -3px #2DD4BF;
}
.karanos-panel button.baslat {
  padding: 0 14px;
}
.karanos-panel button.baslat:hover {
  background-color: #17222C;
}
.karanos-panel label.saat {
  color: #E6EDF3;
  padding: 0 12px;
}
.karanos-panel label.gosterge {
  color: #8B9BA8;
  padding: 0 8px;
}
.karanos-baslat {
  background-color: #17222C;
  border: 1px solid #233A45;
}
""".encode("utf-8")


class Panel(Gtk.Window):
    def __init__(self):
        super().__init__(title="karanos-panel")
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_keep_above(True)
        self.stick()
        self.get_style_context().add_class("karanos-panel")

        self._css_yukle()

        self.ekran = Wnck.Screen.get_default()
        self.ekran.force_update()
        self.menu = BaslatMenusu(self)
        self._pencere_dugmeleri = {}

        self._kur()
        self._yerlestir()

        self.ekran.connect("window-opened", self._pencereler_degisti)
        self.ekran.connect("window-closed", self._pencereler_degisti)
        self.ekran.connect("active-window-changed", self._etkin_degisti)
        self.ekran.connect("active-workspace-changed", self._pencereler_degisti)

        self.connect("destroy", Gtk.main_quit)
        # Ekran çözünürlüğü değişince panel yanlış yerde kalıyordu.
        Gdk.Screen.get_default().connect("size-changed", lambda *_: self._yerlestir())

    # ---------------------------------------------------------------
    def _css_yukle(self):
        saglayici = Gtk.CssProvider()
        saglayici.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), saglayici,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def _kur(self):
        kutu = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.add(kutu)

        # --- başlat ---
        self.baslat_dugmesi = Gtk.Button()
        self.baslat_dugmesi.get_style_context().add_class("baslat")
        self.baslat_dugmesi.set_relief(Gtk.ReliefStyle.NONE)
        ic = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        ic.pack_start(Gtk.Image.new_from_icon_name("karanos", Gtk.IconSize.LARGE_TOOLBAR),
                      False, False, 0)
        ic.pack_start(Gtk.Label(label=M("panel.start")), False, False, 0)
        self.baslat_dugmesi.add(ic)
        self.baslat_dugmesi.connect("clicked", self._baslat_tiklandi)
        kutu.pack_start(self.baslat_dugmesi, False, False, 0)

        # --- pencere listesi ---
        self.pencere_kutusu = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        kutu.pack_start(self.pencere_kutusu, True, True, 6)

        # --- sağ uç ---
        sag = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.masaustu_gostergesi = gosterge.MasaustuGostergesi(self.ekran)
        sag.pack_start(self.masaustu_gostergesi, False, False, 0)
        sag.pack_start(gosterge.KlavyeGostergesi(), False, False, 0)
        sag.pack_start(gosterge.PilGostergesi(), False, False, 0)
        sag.pack_start(gosterge.Saat(), False, False, 0)

        masaustu = Gtk.Button()
        masaustu.set_relief(Gtk.ReliefStyle.NONE)
        masaustu.set_tooltip_text(M("panel.show_desktop"))
        masaustu.set_size_request(8, -1)
        masaustu.connect("clicked", self._masaustunu_goster)
        sag.pack_start(masaustu, False, False, 0)

        kutu.pack_end(sag, False, False, 0)

    def _yerlestir(self):
        ekran = Gdk.Screen.get_default()
        monitor = Gdk.Display.get_default().get_primary_monitor()
        if monitor is None:
            monitor = Gdk.Display.get_default().get_monitor(0)
        alan = monitor.get_geometry()
        self.set_size_request(alan.width, YUKSEKLIK)
        self.resize(alan.width, YUKSEKLIK)
        self.move(alan.x, alan.y + alan.height - YUKSEKLIK)
        GLib.idle_add(self._strut_ayarla, alan)
        del ekran

    def _strut_ayarla(self, alan):
        """Pencereler panelin altına girmesin diye alan ayır.

        _NET_WM_STRUT_PARTIAL olmadan tam ekran pencereler panelin
        üstünü kaplıyor. Gdk bu özelliği doğrudan sunmuyor, ham özellik
        olarak yazıyoruz.
        """
        pencere = self.get_window()
        if pencere is None:
            return False
        ekran_yuksekligi = Gdk.Screen.get_default().get_height()
        alt = ekran_yuksekligi - (alan.y + alan.height) + YUKSEKLIK
        degerler = [0, 0, 0, alt, 0, 0, 0, 0, 0, 0, alan.x, alan.x + alan.width - 1]
        for ad in ("_NET_WM_STRUT_PARTIAL", "_NET_WM_STRUT"):
            veri = degerler if ad == "_NET_WM_STRUT_PARTIAL" else degerler[:4]
            Gdk.property_change(
                pencere,
                Gdk.Atom.intern(ad, False),
                Gdk.Atom.intern("CARDINAL", False),
                32, Gdk.PropMode.REPLACE, veri, len(veri))
        return False

    # ---------------------------------------------------------------
    def _baslat_tiklandi(self, dugme):
        if self.menu.get_visible():
            self.menu.kapat()
            return
        _, kok_x, kok_y = dugme.get_window().get_origin()
        tahsis = dugme.get_allocation()
        self.menu.ac(kok_x + tahsis.x, kok_y + tahsis.y)

    def _masaustunu_goster(self, _dugme):
        gosterilsin = not self.ekran.get_showing_desktop()
        self.ekran.toggle_showing_desktop(gosterilsin)

    # ---------------------------------------------------------------
    def _pencereler_degisti(self, *_):
        for cocuk in self.pencere_kutusu.get_children():
            self.pencere_kutusu.remove(cocuk)
        self._pencere_dugmeleri.clear()

        etkin_masaustu = self.ekran.get_active_workspace()
        etkin_pencere = self.ekran.get_active_window()

        for pencere in self.ekran.get_windows():
            if pencere.is_skip_tasklist():
                continue
            # Yalnızca o anki sanal masaüstünün pencereleri (bölüm 8)
            if etkin_masaustu is not None and not pencere.is_on_workspace(etkin_masaustu):
                continue
            dugme = self._pencere_dugmesi(pencere, pencere is etkin_pencere)
            self._pencere_dugmeleri[pencere.get_xid()] = dugme
            self.pencere_kutusu.pack_start(dugme, False, False, 0)
        self.pencere_kutusu.show_all()

    def _pencere_dugmesi(self, pencere, etkin):
        dugme = Gtk.Button()
        dugme.set_relief(Gtk.ReliefStyle.NONE)
        if etkin:
            dugme.get_style_context().add_class("etkin")
        kutu = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        simge = pencere.get_mini_icon()
        if simge is not None:
            kutu.pack_start(Gtk.Image.new_from_pixbuf(simge), False, False, 0)
        etiket = Gtk.Label(label=pencere.get_name() or "", xalign=0)
        etiket.set_ellipsize(3)
        etiket.set_max_width_chars(20)
        kutu.pack_start(etiket, True, True, 0)
        dugme.add(kutu)
        dugme.set_size_request(-1, -1)
        dugme.set_tooltip_text(pencere.get_name() or "")
        dugme.connect("clicked", self._pencereye_gec, pencere)
        dugme.set_property("width-request", min(DUGME_AZAMI_GENISLIK, 190))
        return dugme

    def _pencereye_gec(self, _dugme, pencere):
        zaman = Gtk.get_current_event_time()
        # Etkin pencereye tekrar tıklamak küçültür — Windows davranışı.
        if pencere is self.ekran.get_active_window() and not pencere.is_minimized():
            pencere.minimize()
        else:
            pencere.unminimize(zaman)
            pencere.activate(zaman)

    def _etkin_degisti(self, *_):
        etkin = self.ekran.get_active_window()
        for xid, dugme in self._pencere_dugmeleri.items():
            baglam = dugme.get_style_context()
            if etkin is not None and xid == etkin.get_xid():
                baglam.add_class("etkin")
            else:
                baglam.remove_class("etkin")


def main():
    panel = Panel()
    panel.show_all()
    panel._pencereler_degisti()
    Gtk.main()
