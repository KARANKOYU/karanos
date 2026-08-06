"""Arayüz metinleri.

BURAYA ELLE METİN EKLENMEZ. Her satır
`docs/karanos-arayuz-metinleri.md` içindeki tablodan birebir alınmıştır;
anahtarlar da oradaki anahtarlar. Tabloda karşılığı olmayan bir metne
ihtiyaç duyulursa önce o dosyaya eklenir.

Dil seçimi: sistem yerelinden. Türkçe varsayılan, `tr` ile başlamayan
her yerelde İngilizce kullanılıyor.
"""

import locale

METINLER = {
    # panel.* — docs/karanos-arayuz-metinleri.md, "Görev çubuğu ve başlat menüsü"
    "panel.start": ("Başlat", "Start"),
    "panel.search_placeholder": ("Uygulama veya dosya ara", "Search apps and files"),
    "panel.all_apps": ("Tüm uygulamalar", "All apps"),
    "panel.pinned": ("Sabitlenenler", "Pinned"),
    "panel.recent": ("Son kullanılanlar", "Recent"),
    "panel.pin": ("Görev çubuğuna sabitle", "Pin to taskbar"),
    "panel.unpin": ("Sabitlemeyi kaldır", "Unpin"),
    "panel.power": ("Güç", "Power"),
    "panel.shutdown": ("Kapat", "Shut down"),
    "panel.restart": ("Yeniden başlat", "Restart"),
    "panel.logout": ("Oturumu kapat", "Sign out"),
    "panel.lock": ("Kilitle", "Lock"),
    "panel.sleep": ("Uyku", "Sleep"),
    "panel.show_desktop": ("Masaüstünü göster", "Show desktop"),
    "panel.task_manager": ("Görev Yöneticisi", "Task Manager"),
    "panel.taskbar_settings": ("Görev çubuğu ayarları", "Taskbar settings"),
    "panel.no_results": ("Sonuç bulunamadı", "No results found"),
}


def _turkce_mi():
    try:
        kod = locale.getlocale()[0] or locale.getdefaultlocale()[0] or ""
    except (ValueError, TypeError):
        kod = ""
    return not kod or kod.lower().startswith("tr")


_TR = _turkce_mi()


def M(anahtar):
    """Anahtarın karşılığını döndürür.

    Anahtar tabloda yoksa anahtarın kendisi dönüyor — arayüzde
    `panel.foo` gibi bir şey görünürse eksik olan hemen belli olsun,
    sessizce yanlış bir metin gösterilmesin.
    """
    ciftler = METINLER.get(anahtar)
    if ciftler is None:
        return anahtar
    return ciftler[0] if _TR else ciftler[1]
