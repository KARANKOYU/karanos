# kavis-panel

Görev çubuğu ve başlat menüsü. **Vala** ile yazılmıştır ve tek bir yerel
ikiliye derlenir (madde 3: Python sürümü 117 MB RAM yiyordu; Vala aynı
GTK/Wnck C API'sine derlenir — aynı görünüm ve davranış, RAM yalnızca
GTK'nın kendi maliyeti).

## Dosya yapısı (iş mantığı / arayüz ayrımı — madde 3 şartı)

| Dosya | Ne yapar |
|---|---|
| `src/main.vala` | Giriş noktası; `--metin-denetimi` kipiyle ekransız tablo denetimi (CI kullanıyor) |
| `src/logic/strings.vala` | TR/EN metin tablosu (`docs/kavis-arayuz-metinleri.md`'den birebir), dil seçimi |
| `src/logic/brand.vala` | Ürün kimliği: os-release'ten ad, temaya göre logo yolu (madde 1) |
| `src/logic/apps.vala` | Uygulama listesi/arama/kategoriler (GLib.AppInfo — kendi .desktop ayrıştırıcımız yok) |
| `src/logic/power.vala` | Güç eylemleri (systemctl/loginctl, polkit üzerinden; sudo yok) |
| `src/ui/panel.vala` | Görev çubuğu penceresi, pencere listesi, strut (doğrudan libX11) |
| `src/ui/start_menu.vala` | Başlat menüsü: arama + kategorili liste + güç düğmesi |
| `src/ui/power_menu.vala` | Güç popup'ı (Kilitle/Uyku/Kapat/Yeniden başlat) |
| `src/ui/indicators.vala` | Saat, klavye düzeni, pil, sanal masaüstü göstergeleri |

Kod tanımlayıcıları İngilizce, kullanıcı metinleri TR+EN (proje kuralı).

## Derleme

```bash
tools/build-packages.sh kavis-panel     # depo kökünden; .deb üretir
```

Elle: `debian/rules` içindeki `valac` çağrısı (paketler: gtk+-3.0,
libwnck-3.0, gdk-x11-3.0, x11, gio-unix-2.0;
`-DWNCK_I_KNOW_THIS_IS_UNSTABLE` şart).

## Test

```bash
tools/panel-screenshot.sh out/panel.png   # Xvfb'de çiz, PNG al
MENU=1 tools/panel-screenshot.sh          # başlat menüsü açık
GUC=1  tools/panel-screenshot.sh          # güç popup'ı açık
BUYUT=1 tools/panel-screenshot.sh         # strut doğrulaması
out/packages/... --metin-denetimi         # metin tablosu tutarlılığı
```

## Verilen kararlar

- **Strut doğrudan libX11** (`XChangeProperty`): Python'daki python3-xlib
  bağımlılığının sebebi PyGObject'in `Gdk.property_change`'i
  vermemesiydi; Vala'da böyle bir engel yok.
- **`setxkbmap` bağımlılığı düzeltildi**: ikili `x11-xkb-utils`
  paketinde; eski pakette bildirilmiyordu ve klavye göstergesi sessizce
  "TR"ye düşüyordu.
- **`librsvg2-common` açık bağımlılık**: logo SVG'sini gdk-pixbuf'un
  SVG yükleyicisi açıyor; shlibs bu dinamik yükleyiciyi göremez.
- Sistem tepsisi bilerek yok — bildirim altyapısıyla (madde 37) gelecek.
