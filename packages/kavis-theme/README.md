# kavis-theme

Kavis'in görünümü: GTK teması, simgeler, imleçler, duvar kağıtları ve
dağıtım kimliği.

## Ne üretiyor

| Yol | İçerik |
|---|---|
| `/usr/share/themes/Kavis/gtk-3.0/` | `gtk.css` (açık), `gtk-dark.css` (koyu) |
| `/usr/share/themes/Kavis/gtk-2.0/gtkrc` | eski GTK2 uygulamaları için renk uyumu |
| `/usr/share/themes/Kavis/openbox-3/themerc` | pencere çerçevesi ve başlık çubuğu |
| `/usr/share/icons/Kavis/` | K logosundan türetilen simgeler, Adwaita'yı miras alır |
| `/usr/share/icons/Kavis-Cursors/` | 16 şekil, 106 ad, ikisi animasyonlu |
| `/usr/share/backgrounds/kavis/` | `karan`, `karan-koyu`, `kavis-duz` (SVG + PNG + önizleme) |
| `/etc/gtk-3.0/settings.ini` | sistem geneli varsayılan tema/imleç/yazı tipi |
| `/etc/os-release` | `PRETTY_NAME="Kavis 1.0"` |

## Depoda ikili dosya yok

Simgeler, imleçler ve duvar kağıtları depoda PNG olarak durmuyor; hepsi
`assets/logo/k-logo.svg` ve `tools/` altındaki iki üreteçten derleme
sırasında üretiliyor:

- `tools/gen-cursors.py` — SVG şekilleri → `rsvg-convert` → `xcursorgen`
- `tools/gen-wallpapers.py` — SVG degradeler → `rsvg-convert`

Renk değiştirmek istersen üreteçlerin başındaki sabitleri düzeltip yeniden
derlemen yeterli.

## Derleme

```bash
tools/build-packages.sh kavis-theme     # depo kökünden
```

Çıktı `out/packages/kavis-theme_1.0_all.deb`. Script `assets/logo/`
altındaki logoyu `src/logo/` içine kopyalar (o kopya `.gitignore`'da —
logo tek yerde dursun diye).

## Nasıl göründüğüne bakma

```bash
tools/theme-screenshot.sh out/tema.png
```

Xvfb + Openbox başlatır, duvar kağıdını ve tema önizleme penceresini
çizip PNG'ye alır. ISO derlemeden ~10 saniyede sonuç verir.

## Bilinen tuzaklar

- **`window.*.label.bg` yazılmazsa** Openbox etiket kutusunu siyaha
  boyuyor ve başlık çubuğunun ortasında siyah bir şerit çıkıyor.
  `parentrelative` şart.
- **Openbox'ın teması `rc.xml`'den geliyor**, GTK temasından değil.
  `iso/config/hooks/normal/0200-openbox-theme.hook.chroot` Debian'ın
  dosyasındaki tek bir alanı değiştiriyor — dosyayı komple değiştirirsek
  `<mouse>` bölümü gider ve pencereler fareyle tutulamaz hâle gelir.
- **`/etc/os-release` `base-files`'a ait.** Üstüne yazmak yerine
  `dpkg-divert` kullanılıyor (`debian/preinst`), paket kaldırılınca aslı
  geri geliyor.
