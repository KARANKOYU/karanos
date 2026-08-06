"""Kurulu uygulamaların listesi ve aranması.

Kaynak: XDG masaüstü girdileri (`Gio.AppInfo`). Kendi .desktop
ayrıştırıcımızı yazmıyoruz — Gio zaten dil, NoDisplay, OnlyShowIn ve
TryExec kurallarını doğru uyguluyor.
"""

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gio  # noqa: E402

# Başlat menüsündeki kategori sırası. Anahtarlar XDG ana kategorileri.
# Sıra Windows'un "Tüm uygulamalar" listesindeki gibi değil, kullanım
# sıklığına göre: günlük kullanılanlar üstte, sistem araçları altta.
KATEGORI_SIRASI = [
    "Network",
    "Office",
    "AudioVideo",
    "Graphics",
    "Development",
    "Game",
    "Utility",
    "System",
    "Settings",
]

# Kategori adları docs/karanos-arayuz-metinleri.md'de yok (mağaza
# kategorileri ayrı bir liste). XDG'nin kendi adlarını gösteriyoruz;
# 9. aşamada mağaza kategorileriyle birleştirilecek.
KATEGORI_ADI = {
    "Network": ("İnternet", "Internet"),
    "Office": ("Ofis", "Office"),
    "AudioVideo": ("Ses ve Video", "Sound & Video"),
    "Graphics": ("Grafik", "Graphics"),
    "Development": ("Geliştirme", "Development"),
    "Game": ("Oyun", "Games"),
    "Utility": ("Araçlar", "Accessories"),
    "System": ("Sistem", "System"),
    "Settings": ("Ayarlar", "Settings"),
    "Diger": ("Diğer", "Other"),
}


class Uygulama:
    __slots__ = ("appinfo", "ad", "aciklama", "kategori", "_arama_metni")

    def __init__(self, appinfo):
        self.appinfo = appinfo
        self.ad = appinfo.get_display_name() or appinfo.get_name() or ""
        self.aciklama = appinfo.get_description() or ""
        self.kategori = _kategori_sec(appinfo)
        anahtar_kelime = " ".join(appinfo.get_keywords() or ())
        self._arama_metni = " ".join(
            (self.ad, self.aciklama, anahtar_kelime, appinfo.get_id() or "")
        ).lower()

    def eslesir_mi(self, sorgu):
        return sorgu in self._arama_metni

    def calistir(self):
        self.appinfo.launch(None, None)


def _kategori_sec(appinfo):
    ham = appinfo.get_categories() or ""
    kategoriler = {p for p in ham.split(";") if p}
    for k in KATEGORI_SIRASI:
        if k in kategoriler:
            return k
    return "Diger"


def hepsi():
    """Menüde gösterilecek uygulamalar, ada göre sıralı.

    `should_show()` NoDisplay ve OnlyShowIn kurallarını uyguluyor;
    kendi filtremizi yazsak masaüstü ortamına özel girdileri yanlışlıkla
    gösterirdik.
    """
    liste = [Uygulama(a) for a in Gio.AppInfo.get_all() if a.should_show()]
    liste.sort(key=lambda u: u.ad.lower())
    return liste


def ara(uygulamalar, sorgu):
    sorgu = (sorgu or "").strip().lower()
    if not sorgu:
        return uygulamalar
    # Adı sorguyla başlayanlar önce: "fi" yazınca Firefox, adında "fi"
    # geçen rastgele bir araçtan önce gelmeli.
    bas = [u for u in uygulamalar if u.ad.lower().startswith(sorgu)]
    ic = [u for u in uygulamalar if u not in bas and u.eslesir_mi(sorgu)]
    return bas + ic


def kategoriye_gore(uygulamalar):
    """{kategori: [uygulama, ...]} — KATEGORI_SIRASI düzeninde."""
    kovalar = {}
    for u in uygulamalar:
        kovalar.setdefault(u.kategori, []).append(u)
    sirali = []
    for k in KATEGORI_SIRASI + ["Diger"]:
        if k in kovalar:
            sirali.append((k, kovalar[k]))
    return sirali
