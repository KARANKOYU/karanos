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

## Pencere başlık düğmeleri (1B kararı, 3 Eyl 2026)

KARAR: **Seçenek A — Openbox themerc** (kullanıcı seçimi; CSD demosu
gösterildi, reddedildi). Gerekçe/koşul: SSD her pencerede tutarlı
(nemo/kate/tilix dahil), CSD yalnız kavis-* uygulamalarını süsleyip
karma görünüm yaratıyordu.

| Öğe | Değer |
|---|---|
| Başlık yüksekliği | ~32px (font 10-11 + padding.height 8) |
| Düğme sırası | – ☐ ✕ sağda; ikon + başlık solda (NLIMC) |
| Düğme ikonu | 14px xbm (daha büyüğü openbox kutusunda kırpılır) |
| Kapat hover / basılı | #C42B1C / #A02316, beyaz ✕ |
| Diğer hover / basılı | beyaz %10 (#2E3842) / %14 (#374149) |

Openbox sınırları (bilinçli kabul — themerc başındaki not asıl
kaynak): düğme kutusu KARE ve başlık yüksekliğine bağlı (W11'in
46×32'si olmaz), düğmeler arasında 1-2px boşluk kalır, hover kutusu
tam yükseklik dolmaz, geçiş animasyonu yok.

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
