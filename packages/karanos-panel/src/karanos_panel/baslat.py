"""Başlat menüsü.

Yerleşim (bölüm 8): üstte arama kutusu, ortada kategorilere ayrılmış
program listesi, altta güç düğmeleri.
"""

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

from . import uygulamalar
from .guc_menusu import GucMenusu
from .metinler import M

GENISLIK = 420
YUKSEKLIK = 560


class BaslatMenusu(Gtk.Window):
    def __init__(self, panel):
        super().__init__(type=Gtk.WindowType.POPUP)
        self.panel = panel
        self.set_size_request(GENISLIK, YUKSEKLIK)
        self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.get_style_context().add_class("karanos-baslat")

        self._uygulamalar = []
        self._kur()

        # Menü dışına tıklayınca kapansın. Openbox'ta POPUP pencereler
        # odak almadığı için "focus-out" güvenilir değil; imleci ve
        # klavyeyi doğrudan yakalıyoruz.
        self.connect("button-press-event", self._disari_tiklandi)
        self.connect("key-press-event", self._tusa_basildi)

    # ---------------------------------------------------------------
    def _kur(self):
        kok = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(kok)

        # --- arama ---
        arama_kutusu = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        arama_kutusu.set_border_width(10)
        self.arama = Gtk.SearchEntry()
        self.arama.set_placeholder_text(M("panel.search_placeholder"))
        self.arama.connect("search-changed", self._arama_degisti)
        self.arama.connect("activate", self._ilkini_calistir)
        arama_kutusu.pack_start(self.arama, True, True, 0)
        kok.pack_start(arama_kutusu, False, False, 0)

        # --- liste ---
        self.kaydirma = Gtk.ScrolledWindow()
        self.kaydirma.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.liste = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.liste.set_border_width(6)
        self.kaydirma.add(self.liste)
        kok.pack_start(self.kaydirma, True, True, 0)

        kok.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL),
                       False, False, 0)

        # --- güç ---
        # Tek düğme; basınca Windows 11'deki gibi üstte küçük bir popup
        # açılıyor (guc_menusu.py). Eylemleri doğrudan buraya dizmek
        # yerine popup kullanmanın sebebi: dört ikon yan yana dizilince
        # hangisinin ne olduğu ancak ipucu metniyle anlaşılıyordu.
        guc_kutusu = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        guc_kutusu.set_border_width(8)
        self.guc_dugmesi = Gtk.Button()
        self.guc_dugmesi.set_relief(Gtk.ReliefStyle.NONE)
        self.guc_dugmesi.set_tooltip_text(M("panel.power"))
        guc_ic = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        guc_ic.pack_start(Gtk.Image.new_from_icon_name(
            "system-shutdown-symbolic", Gtk.IconSize.LARGE_TOOLBAR),
            False, False, 0)
        guc_ic.pack_start(Gtk.Label(label=M("panel.power")), False, False, 0)
        self.guc_dugmesi.add(guc_ic)
        self.guc_dugmesi.connect("clicked", self._guc_menusunu_ac)
        guc_kutusu.pack_start(self.guc_dugmesi, False, False, 0)
        kok.pack_start(guc_kutusu, False, False, 0)

        self.guc_menusu = GucMenusu()

    # ---------------------------------------------------------------
    def ac(self, x, y):
        """Menüyü görev çubuğunun üstünde aç."""
        self._uygulamalar = uygulamalar.hepsi()
        self.arama.set_text("")
        self._listeyi_ciz(self._uygulamalar, kategorili=True)
        self.move(x, y - YUKSEKLIK)
        self.show_all()
        self.arama.grab_focus()

        # POPUP pencereler pencere yöneticisinden odak almıyor; klavye ve
        # fareyi elle yakalamazsak yazdığımız hiçbir şey menüye ulaşmıyor.
        pencere = self.get_window()
        if pencere is not None:
            ekran = Gdk.Display.get_default()
            koltuk = ekran.get_default_seat()
            koltuk.grab(pencere, Gdk.SeatCapabilities.ALL, True,
                        None, None, None, None)

    def kapat(self):
        ekran = Gdk.Display.get_default()
        if ekran is not None:
            ekran.get_default_seat().ungrab()
        self.hide()

    # ---------------------------------------------------------------
    def _listeyi_ciz(self, liste, kategorili):
        for cocuk in self.liste.get_children():
            self.liste.remove(cocuk)

        if not liste:
            bos = Gtk.Label(label=M("panel.no_results"))
            bos.get_style_context().add_class("dim-label")
            bos.set_margin_top(24)
            self.liste.pack_start(bos, False, False, 0)
            self.liste.show_all()
            return

        if kategorili:
            for kategori, uygs in uygulamalar.kategoriye_gore(liste):
                self.liste.pack_start(self._baslik(kategori), False, False, 0)
                for u in uygs:
                    self.liste.pack_start(self._satir(u), False, False, 0)
        else:
            for u in liste:
                self.liste.pack_start(self._satir(u), False, False, 0)
        self.liste.show_all()

    def _baslik(self, kategori):
        ad = uygulamalar.kategori_adi(kategori)
        etiket = Gtk.Label(xalign=0)
        etiket.set_markup(f"<b>{GLib.markup_escape_text(ad)}</b>")
        etiket.get_style_context().add_class("dim-label")
        etiket.set_margin_top(10)
        etiket.set_margin_start(6)
        etiket.set_margin_bottom(2)
        return etiket

    def _satir(self, uygulama):
        dugme = Gtk.Button()
        dugme.set_relief(Gtk.ReliefStyle.NONE)
        kutu = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        simge = Gtk.Image.new_from_gicon(
            uygulama.appinfo.get_icon() or Gtk.IconTheme.get_default().load_icon(
                "application-x-executable", 24, 0),
            Gtk.IconSize.LARGE_TOOLBAR)
        kutu.pack_start(simge, False, False, 0)
        etiket = Gtk.Label(label=uygulama.ad, xalign=0)
        etiket.set_ellipsize(3)  # PANGO_ELLIPSIZE_END
        kutu.pack_start(etiket, True, True, 0)
        dugme.add(kutu)
        dugme.connect("clicked", self._uygulama_secildi, uygulama)
        return dugme

    # ---------------------------------------------------------------
    def _arama_degisti(self, giris):
        sorgu = giris.get_text()
        sonuc = uygulamalar.ara(self._uygulamalar, sorgu)
        self._listeyi_ciz(sonuc, kategorili=not sorgu.strip())

    def _ilkini_calistir(self, _giris):
        sonuc = uygulamalar.ara(self._uygulamalar, self.arama.get_text())
        if sonuc:
            self._uygulama_secildi(None, sonuc[0])

    def _uygulama_secildi(self, _dugme, uygulama):
        self.kapat()
        try:
            uygulama.calistir()
        except GLib.Error as hata:
            print(f"karanos-panel: {uygulama.ad} baslatilamadi: {hata}")

    def _guc_menusunu_ac(self, dugme):
        # Popup'ı güç düğmesinin üstünde aç. Başlat menüsünü kapatmıyoruz:
        # kullanıcı popup'ı kapatınca listeye geri dönmüş oluyor.
        pencere = dugme.get_window()
        if pencere is None:
            return
        _, kok_x, kok_y = pencere.get_origin()
        tahsis = dugme.get_allocation()
        # Klavye/fare yakalaması bizde; popup kendi yakalamasını
        # alabilsin diye önce bırakıyoruz.
        ekran = Gdk.Display.get_default()
        if ekran is not None:
            ekran.get_default_seat().ungrab()
        self.guc_menusu.ac(kok_x + tahsis.x, kok_y + tahsis.y)

    def _disari_tiklandi(self, _pencere, olay):
        genislik = self.get_allocated_width()
        yukseklik = self.get_allocated_height()
        if not (0 <= olay.x <= genislik and 0 <= olay.y <= yukseklik):
            self.kapat()
            return True
        return False

    def _tusa_basildi(self, _pencere, olay):
        if olay.keyval == Gdk.KEY_Escape:
            self.kapat()
            return True
        return False
