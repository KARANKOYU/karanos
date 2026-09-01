"""Görev çubuğunun sağ ucundaki göstergeler.

Sistem tepsisi (XEmbed / StatusNotifier) burada YOK — o kendi başına
bir iş ve 10. aşamadaki kavis-tools ile gelecek. Buradakiler
doğrudan sistemden okunuyor, aracı bir daemon'a bağlı değiller.
"""

import glob
import os
import subprocess
import time

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk  # noqa: E402


class Saat(Gtk.Label):
    """Saat ve tarih. Bölüm 8: görev çubuğunun sağ ucunda."""

    def __init__(self):
        super().__init__()
        self.get_style_context().add_class("saat")
        self.set_justify(Gtk.Justification.CENTER)
        self._guncelle()
        # Saniye göstermiyoruz (ayarlarda açılabilecek — appearance.show_seconds),
        # o yüzden dakikada bir yenilemek yeterli. 30 saniyede bir bakıp
        # dakika değiştiyse yazıyoruz: tam dakikayı en fazla yarım saniye
        # kaçırıyoruz, uyandıktan sonra da doğru gösteriyor.
        GLib.timeout_add_seconds(30, self._zamanlayici)

    def _zamanlayici(self):
        self._guncelle()
        return True

    def _guncelle(self):
        simdi = time.localtime()
        saat = time.strftime("%H:%M", simdi)
        tarih = time.strftime("%d.%m.%Y", simdi)
        self.set_markup(f"<small>{saat}\n{tarih}</small>")


class KlavyeGostergesi(Gtk.Label):
    """Etkin klavye düzeni (TR/EN) — bölüm 8'de sistem tepsisinde isteniyor."""

    def __init__(self):
        super().__init__()
        self.get_style_context().add_class("gosterge")
        self._guncelle()
        GLib.timeout_add_seconds(2, self._zamanlayici)

    def _zamanlayici(self):
        self._guncelle()
        return True

    def _guncelle(self):
        self.set_text(self._duzen().upper())

    @staticmethod
    def _duzen():
        try:
            cikti = subprocess.run(
                ["setxkbmap", "-query"],
                capture_output=True, text=True, timeout=2, check=False).stdout
        except (OSError, subprocess.SubprocessError):
            return "tr"
        for satir in cikti.splitlines():
            if satir.startswith("layout:"):
                # Birden çok düzen varsa ilki etkin olan değil, listenin
                # ilki. Etkin grubu okumak XKB çağrısı gerektiriyor;
                # 8. aşamada ayarlar uygulamasıyla birlikte düzeltilecek.
                return satir.split(":", 1)[1].strip().split(",")[0]
        return "tr"


class PilGostergesi(Gtk.Label):
    """Pil yüzdesi. Masaüstü makinede pil yoksa gizli kalıyor."""

    def __init__(self):
        super().__init__()
        self.get_style_context().add_class("gosterge")
        self._yol = self._pil_yolu()
        self._guncelle()
        if self._yol:
            GLib.timeout_add_seconds(30, self._zamanlayici)

    @staticmethod
    def _pil_yolu():
        for yol in sorted(glob.glob("/sys/class/power_supply/BAT*")):
            if os.path.exists(os.path.join(yol, "capacity")):
                return yol
        return None

    def _zamanlayici(self):
        self._guncelle()
        return True

    def _guncelle(self):
        if not self._yol:
            self.hide()
            self.set_no_show_all(True)
            return
        try:
            with open(os.path.join(self._yol, "capacity"), encoding="ascii") as fh:
                yuzde = fh.read().strip()
            with open(os.path.join(self._yol, "status"), encoding="ascii") as fh:
                durum = fh.read().strip()
        except OSError:
            self.hide()
            return
        isaret = "⚡" if durum == "Charging" else ""
        self.set_text(f"{isaret}%{yuzde}")


class MasaustuGostergesi(Gtk.Box):
    """Sanal masaüstü göstergesi (bölüm 8: 4 masaüstü).

    Her masaüstü küçük bir düğme; tıklayınca oraya geçiliyor, etkin olan
    turkuaz şeritle işaretli.
    """

    def __init__(self, ekran):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        self.ekran = ekran
        self._dugmeler = []
        self._ciz()
        ekran.connect("workspace-created", lambda *_: self._ciz())
        ekran.connect("workspace-destroyed", lambda *_: self._ciz())
        ekran.connect("active-workspace-changed", lambda *_: self._isaretle())

    def _ciz(self):
        for cocuk in self.get_children():
            self.remove(cocuk)
        self._dugmeler = []
        for masaustu in self.ekran.get_workspaces():
            dugme = Gtk.Button(label=str(masaustu.get_number() + 1))
            dugme.set_relief(Gtk.ReliefStyle.NONE)
            dugme.set_tooltip_text(masaustu.get_name() or "")
            dugme.connect("clicked", self._gec, masaustu)
            self._dugmeler.append((masaustu.get_number(), dugme))
            self.pack_start(dugme, False, False, 0)
        self.show_all()
        self._isaretle()

    def _gec(self, _dugme, masaustu):
        masaustu.activate(Gtk.get_current_event_time())

    def _isaretle(self):
        etkin = self.ekran.get_active_workspace()
        etkin_no = etkin.get_number() if etkin is not None else -1
        for no, dugme in self._dugmeler:
            baglam = dugme.get_style_context()
            if no == etkin_no:
                baglam.add_class("etkin")
            else:
                baglam.remove_class("etkin")
