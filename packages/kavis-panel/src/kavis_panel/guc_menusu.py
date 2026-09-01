"""Güç menüsü — başlat menüsündeki güç düğmesine basınca açılan kutu.

Windows 11'deki gibi: düğmenin ÜSTÜNDE açılan, köşeleri yuvarlatılmış,
hafif gölgeli küçük bir kutu. İçinde ikonlu satırlar; solda ikon, sağında
metin. Üzerine gelince satır vurgulanıyor, dışına tıklayınca kapanıyor.

Metinler docs/kavis-arayuz-metinleri.md `panel.*` anahtarlarından.
"""

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, Gtk  # noqa: E402

from . import guc
from .metinler import M

GENISLIK = 210
# Gölgenin sığması için pencere kenarında bırakılan şeffaf pay.
# Kompozitör yoksa bu pay ŞEFFAF DEĞİL SİYAH çiziliyor ve kutunun
# etrafında siyah bir çerçeve oluşuyor — Xvfb'de tam olarak bu görüldü.
# O yüzden pay yalnızca bileşikleme varken bırakılıyor.
KENAR_GOLGELI = 10
KENAR_DUZ = 0

# Sıra kullanıcının istediği gibi: Kilitle, Uyku, Kapat, Yeniden başlat.
EYLEMLER = (
    ("panel.lock", "system-lock-screen-symbolic", guc.kilitle),
    ("panel.sleep", "weather-clear-night-symbolic", guc.uyku),
    ("panel.shutdown", "system-shutdown-symbolic", guc.kapat),
    ("panel.restart", "system-reboot-symbolic", guc.yeniden_baslat),
)

CSS = """
/* Kutunun kendisi: yüzey rengi, yuvarlatılmış köşe, ince kenarlık ve
   yumuşak gölge. Gölgeyi pencereye değil iç kutuya veriyoruz; pencere
   şeffaf kalıyor ki gölge kırpılmasın. */
.kavis-guc-kutu {
  background-color: #17222C;
  border: 1px solid #233A45;
  border-radius: 10px;
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
}
/* Kompozitör yokken: gölge ve yuvarlak köşe yerine sade kenarlık. */
.kavis-guc-kutu.duz {
  border-radius: 0;
  box-shadow: none;
}
.kavis-guc-kutu button {
  background-image: none;
  background-color: transparent;
  border: none;
  border-radius: 6px;
  color: #E6EDF3;
  padding: 9px 12px;
}
.kavis-guc-kutu button:hover {
  background-color: #1D2C38;
}
.kavis-guc-kutu button:active {
  background-color: #233A45;
}
"""


class GucMenusu(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.POPUP)
        self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_app_paintable(True)

        # Yuvarlatılmış köşe ve gölge ancak bileşikleme (kompozitör)
        # varken görünüyor. Kavis'te picom autostart'tan başlıyor;
        # yine de yoksa (kurtarma modu, picom çökmüş) kutuyu düz
        # dikdörtgen olarak çiziyoruz — siyah çerçeve göstermektense.
        ekran = self.get_screen()
        gorsel = ekran.get_rgba_visual()
        self.bilesik = bool(gorsel is not None and ekran.is_composited())
        if self.bilesik:
            self.set_visual(gorsel)
        self.kenar = KENAR_GOLGELI if self.bilesik else KENAR_DUZ

        self._css_yukle()
        self._kur()

        self.connect("button-press-event", self._disari_tiklandi)
        self.connect("key-press-event", self._tusa_basildi)

    def _css_yukle(self):
        saglayici = Gtk.CssProvider()
        saglayici.load_from_data(CSS.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), saglayici,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def _kur(self):
        # Dış kutu şeffaf, gölge iç kutuda — böylece gölge pencere
        # sınırında kesilmiyor.
        dis = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        dis.set_border_width(self.kenar)
        self.add(dis)

        self.kutu = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.kutu.get_style_context().add_class("kavis-guc-kutu")
        if not self.bilesik:
            # Gölge ve yuvarlak köşe çizilemiyor; sade kenarlıkla devam.
            self.kutu.get_style_context().add_class("duz")
        self.kutu.set_border_width(6)
        dis.pack_start(self.kutu, True, True, 0)

        for anahtar, simge_adi, eylem in EYLEMLER:
            self.kutu.pack_start(self._satir(anahtar, simge_adi, eylem),
                                 False, False, 0)

    def _satir(self, anahtar, simge_adi, eylem):
        dugme = Gtk.Button()
        dugme.set_relief(Gtk.ReliefStyle.NONE)
        ic = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        ic.pack_start(
            Gtk.Image.new_from_icon_name(simge_adi, Gtk.IconSize.LARGE_TOOLBAR),
            False, False, 0)
        etiket = Gtk.Label(label=M(anahtar), xalign=0)
        ic.pack_start(etiket, True, True, 0)
        dugme.add(ic)
        dugme.connect("clicked", self._secildi, eylem)
        return dugme

    # ---------------------------------------------------------------
    def ac(self, x, y):
        """Verilen noktanın ÜSTÜNDE aç (x, y = güç düğmesinin sol üstü)."""
        self.show_all()
        genislik, yukseklik = self.get_preferred_size()[1].width, \
            self.get_preferred_size()[1].height
        self.move(x - self.kenar, y - yukseklik + self.kenar)

        pencere = self.get_window()
        if pencere is not None:
            koltuk = Gdk.Display.get_default().get_default_seat()
            koltuk.grab(pencere, Gdk.SeatCapabilities.ALL, True,
                        None, None, None, None)
        del genislik

    def kapat(self):
        ekran = Gdk.Display.get_default()
        if ekran is not None:
            ekran.get_default_seat().ungrab()
        self.hide()

    # ---------------------------------------------------------------
    def _secildi(self, _dugme, eylem):
        self.kapat()
        eylem()

    def _disari_tiklandi(self, _pencere, olay):
        tahsis = self.kutu.get_allocation()
        icerde = (tahsis.x <= olay.x <= tahsis.x + tahsis.width
                  and tahsis.y <= olay.y <= tahsis.y + tahsis.height)
        if not icerde:
            self.kapat()
            return True
        return False

    def _tusa_basildi(self, _pencere, olay):
        if olay.keyval == Gdk.KEY_Escape:
            self.kapat()
            return True
        return False
