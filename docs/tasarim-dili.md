# Kavis — tasarım dili (test8 J; her yeni widget buna uyar)

İlke: **Windows 11 düzeni + macOS yumuşaklığı.** İki şey macOS'tan
alınır: yuvarlaklık ve yumuşak animasyon. Sert geçiş hiçbir yerde
olmaz.

## Köşe yarıçapları (J1)

| Öğe | Yarıçap | Nerede tanımlı |
|---|---|---|
| Popup / panel / menü kutusu | 12px | ilgili dosyanın CSS bloğu (`.kavis-popup`, `.kavis-picker`, `.kavis-snap-menu`, `.kavis-osd`, `.kavis-snip-bar`) |
| Kutucuk (hızlı ayar) | 10px | `.setting-tile` |
| Düğme / hover kutusu | 8px | `.kavis-panel button`, popup/picker düğmeleri |
| Pencere | 8px | picom `corner-radius` (picom-kavis.conf) |

GTK3 CSS'te değişken yok (`@define-color` yalnız renk) — değerlerin
tek kaynağı BU TABLO; koda yeni yarıçap yazarken buradan al, sapma
görürsen düzelt.

X menüleri (Gtk.Menu) picom'un genel 8px'iyle yuvarlanır; menü
kutusuna GTK içinden 12px verilemiyor (kabul edilmiş sınır).

## Animasyonlar (J2)

| Olay | Süre / eğri | Kim yapıyor |
|---|---|---|
| Popup/pencere açılış | 180 ms, appear (ölçek 0.96 + solma) | picom |
| Kapanış | 120 ms, disappear | picom |
| Hover | 140 ms ease | GTK CSS `transition` |
| Kutucuk basış | anlık renk (%14) | GTK CSS `:active` |

Sınırlar (bilinçli kabul):
- "Hafif yukarı kayma" picom v12 preset'lerinde yok; appear'ın
  ölçek+solması en yakın karşılık.
- GTK3 CSS `transform` animasyonu bilmez — basışta 80 ms küçük ölçek
  verilemiyor; karşılık `:active` rengi.
- picom v12 öncesi animasyon bloğunu yok sayar (yalnız yerel test
  ortamını etkiler).

## Boşluklar (J3)

| Ölçü | Değer |
|---|---|
| Popup iç kenar | 16px |
| Öğeler arası | 8px |
| Gruplar arası | 12px (panel sağ bölge grupları: yatay 6 / dikey 8) |

Sıkışıklık yok — kullanıcı ferah hissetmeli. Yeni bir widget bu
değerlerin dışına çıkacaksa sebebi commit mesajında yazılır.

## Başlık çubuğu (v0.4-test1 A kararı, 3 Eyl 2026 — 1B'yi GÜNCELLER)

KARAR: **çift katman.** Kavis'in kendi uygulamaları (Ayarlar, Görev
Yöneticisi, ileride Mağaza/kurucu) GtkHeaderBar ile **CSD** kullanır —
Tilix'in başlık çubuğu referans görünüm. Üçüncü parti/SSD pencereler
(nemo, gparted, firefox...) openbox themerc'nin buna birebir eşlenmiş
sürümünü alır. (Eski 1B "yalnız themerc" kararı bu turda kullanıcı
tarafından değiştirildi: "terminaldeki gibi".)

CSD (kaynaklar: kavis-common/headerbar.vala + kavis-theme gtk-dark.css
ve gtk-light.css `headerbar` blokları — Tilix dahil her CSD pencere
otomatik uyar):

| Öğe | Değer |
|---|---|
| Yerleşim | solda ikon + ad (sola hizalı), sağda – ☐ ✕ |
| Düğme | 46×32 px, köşe 0, tam yükseklik hover |
| Kapat hover / basılı | #C42B1C / #A02316, beyaz ✕ |
| Diğer hover / basılı | koyu: beyaz %10 / %14 — açık: siyah %8 / %12 |
| Çubuk | min 32px, yüzey #17222C (koyu) / #FFFFFF (açık), 1px alt kenarlık |
| Arka planda (backdrop) | zemin bir ton koyulaşır, metin ikincil renk |

SSD / themerc eşleme:

| Öğe | Değer |
|---|---|
| Başlık yüksekliği | ~35px (font 10 + padding.height 11) — CSD ile eşit |
| Düğme sırası | – ☐ ✕ sağda; ikon + başlık solda (NLIMC) |
| Düğme ikonu | 16px xbm, 12px glif — GTK sembolik ikonlarla aynı optik boy |
| Kapat hover / basılı | #C42B1C / #A02316, beyaz ✕ (CSD ile aynı) |
| Diğer hover / basılı | #2E3842 / #374149 |

Kalan openbox sınırları (bilinçli kabul): düğme kutusu kare (46px
genişlik olmaz), 1-2px düğme arası boşluk, hover kutusu tam yükseklik
dolmaz, animasyon yok. Yan yana bakışta fark ayrıntı düzeyinde —
kanıt: v0.4-test2 A ekran görüntüsü (Tilix + Nemo + Ayarlar).

## Güç diyaloğu / Ctrl+Alt+Del (2D hedef tasarımı)

Tek bileşen (iki ayrı kod YOK): kenarlıksız, ekran ortasında, 12px
köşe, zemin #17222C; yan yana 4 büyük ikonlu düğme — Uyku / Yeniden
başlat / Kapat / İptal; Escape kapatır; açılış picom appear 180 ms.
Görev çubuğu ikonu güç simgesi (kendi WM_CLASS + .desktop — 2C).

## Uygulama durumu

2 Eyl 2026 itibarıyla bu kurala çekilenler: PanelPopup tabanlı her
popup (bildirim merkezi, hızlı ayarlar, klavye, güç, USB), birleşik
"Emoji and more" paneli, snap yerleşim menüsü, OSD, yakalama aracı
çubuğu, panel düğmeleri. GTK sağ tık menüleri picom yuvarlamasıyla.
