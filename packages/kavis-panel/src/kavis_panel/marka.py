"""Product identity: name, version and logo of the running system.

The product name is NEVER hard-coded anywhere in the codebase. The single
source of truth is /etc/os-release (installed by kavis-theme); this module
is the only place that reads it, and everything user-visible goes through
these helpers. If the product is renamed again, only os-release and the
files under assets/logo/ change.

The one allowed constant is the fallback used when os-release is missing
or unreadable (broken live overlay, unit tests on a foreign machine).
"""

import os

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: E402

# The single fallback constant (see module docstring). Everything else
# comes from os-release at runtime.
_VARSAYILAN_AD = "Kavis"

# Logos are installed by kavis-theme. File names match assets/logo/ in
# the repository on purpose: one identity, two renditions. The env
# override exists for tools/panel-screenshot.sh, which unpacks the .deb
# into a temporary root instead of installing it.
_LOGO_DIZINI = os.environ.get("KAVIS_LOGO_DIZIN", "/usr/share/kavis/logo")
_LOGO_KOYU = "koyu-k-logo.svg"
_LOGO_ACIK = "acik-k-logo.svg"

_bilgi_onbellek = None


def _os_release_oku():
    """Parse os-release into a dict.

    Returns: dict of KEY -> value (quotes stripped). Empty dict when no
    os-release file can be read; callers fall back to defaults, and the
    problem is logged once so it is not silently swallowed.
    """
    global _bilgi_onbellek
    if _bilgi_onbellek is not None:
        return _bilgi_onbellek

    bilgi = {}
    for yol in ("/etc/os-release", "/usr/lib/os-release"):
        try:
            with open(yol, encoding="utf-8") as dosya:
                for satir in dosya:
                    satir = satir.strip()
                    if not satir or satir.startswith("#") or "=" not in satir:
                        continue
                    anahtar, deger = satir.split("=", 1)
                    bilgi[anahtar] = deger.strip().strip('"')
            break
        except OSError:
            continue
    if not bilgi:
        print("kavis-panel: os-release okunamadi, varsayilan ad kullaniliyor")

    _bilgi_onbellek = bilgi
    return bilgi


def urun_adi():
    """Product display name (os-release NAME), e.g. shown in menus.

    Returns: str. Falls back to the module constant when unavailable.
    """
    return _os_release_oku().get("NAME", _VARSAYILAN_AD)


def urun_adi_surumlu():
    """Product name with version (os-release PRETTY_NAME).

    Returns: str, e.g. "Kavis 1.0".
    """
    return _os_release_oku().get("PRETTY_NAME", _VARSAYILAN_AD)


def _koyu_tema_mi():
    """Whether the active GTK theme is dark.

    Kavis ships dark-only today, so the answer is normally True; the
    check still reads the live GTK settings so that the light logo is
    picked up automatically if a light theme ever becomes selectable.
    Returns: bool (True when in doubt — dark is the product default).
    """
    ayarlar = Gtk.Settings.get_default()
    if ayarlar is None:
        return True
    try:
        if ayarlar.get_property("gtk-application-prefer-dark-theme"):
            return True
        tema = (ayarlar.get_property("gtk-theme-name") or "").lower()
        # A theme advertising itself as light is the only light signal.
        return "light" not in tema and "acik" not in tema
    except TypeError:
        return True


def logo_yolu():
    """Path of the logo matching the active theme.

    Rule (task item 1): boot splash and GRUB always use the dark logo;
    the start button / about dialogs follow the active theme — which is
    what this helper implements. Returns the dark logo path when the
    theme is dark or unknown, the light one otherwise. The file may be
    missing on broken installs; callers must handle that (see
    logo_resmi).
    """
    dosya = _LOGO_KOYU if _koyu_tema_mi() else _LOGO_ACIK
    return os.path.join(_LOGO_DIZINI, dosya)


def logo_resmi(boyut):
    """Gtk.Image with the theme-appropriate logo at the given pixel size.

    Parameters: boyut — icon edge length in pixels.
    Returns: Gtk.Image. Falls back to the icon-theme lookup ("kavis",
    provided by kavis-theme) when the SVG cannot be loaded, so the panel
    still shows a logo instead of a broken-image placeholder.
    """
    yol = logo_yolu()
    try:
        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import GdkPixbuf
        piksel = GdkPixbuf.Pixbuf.new_from_file_at_size(yol, boyut, boyut)
        return Gtk.Image.new_from_pixbuf(piksel)
    except Exception as hata:  # noqa: BLE001 — GLib.Error türleri çeşitli
        print(f"kavis-panel: logo yuklenemedi ({yol}): {hata}")
        return Gtk.Image.new_from_icon_name("kavis", Gtk.IconSize.LARGE_TOOLBAR)
