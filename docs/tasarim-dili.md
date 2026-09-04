# Kavis — tasarım dili (test8 J; her yeni widget buna uyar)

## Kalite ölçütleri (A5, v0.4-test4) — tek bakışta

v0.4-test4 VM turunun ilk cümlesi "genel izlenim amatör"di. Aşağıdaki
beş satır o turdan çıkan ölçütler; ayrıntıları kendi bölümlerinde.
**Bir widget bunlardan sapıyorsa hatadır**, tasarım tercihi değil.

| Ölçüt | Değer | Denetleyen |
|---|---|---|
| Yazı | Inter 10pt; hinting **slight**, subpixel **rgb**, lcdfilter **default**, antialias açık; Xft.dpi 96 (ölçekle değişir) | `tools/check-visual.sh` (fontconfig'in gerçekte çözdüğü aile + politika) |
| Köşe | pencere/kart 8, popup 12, düğme/giriş 6, kaydırıcı topu tam yuvarlak | `tools/check-visual.sh` (ekran görüntüsünden ölçülen yarıçap) + aşağıdaki tablo |
| Animasyon | `cubic-bezier(0.2, 0.9, 0.25, 1)`, 180 ms (hover 120 ms) | `tools/check-picom.sh` (gerçek picom 12.5 yapılandırmayı kabul ediyor mu) |
| Gölge | picom radius 18 / opacity 0.35; her yüzeyde 1px üst ışık çizgisi | gözle + A4 tablosu |
| Boşluk | popup içi 16, kart içi 12, öğeler arası 8, gruplar arası 12 | gözle + J3 tablosu |

Neden CI'da: "yazı pikselli" ve "bazı köşeler keskin" iki tur boyunca
kimsenin göremediği hatalardı; ikisi de ölçülebilir. `check-visual.sh`
fontconfig'e gerçekten ne çözdüğünü sorar ve compositor'ün çizdiği
köşeyi ekran görüntüsünden ölçer (`tools/corner-radius.py`).


İlke: **Windows 11 düzeni + macOS yumuşaklığı.** İki şey macOS'tan
alınır: yuvarlaklık ve yumuşak animasyon. Sert geçiş hiçbir yerde
olmaz.

## Köşe yarıçapları (J1)

(v0.4-test4 A2 ile güncellendi — VM turunda "bazı yerler keskin"
denmişti; ekranda üç ayrı köşe boyu vardı.)

| Öğe | Yarıçap | Nerede tanımlı |
|---|---|---|
| Popup / panel / menü kutusu / güç diyaloğu | 12px | ilgili dosyanın CSS bloğu (`.kavis-popup`, `.kavis-picker`, `.kavis-snap-menu`, `.kavis-osd`, `.kavis-snip-bar`, `.kavis-power-menu`), tema CSS'inde `popover > contents` |
| Pencere (SSD) | 8px | picom `corner-radius` (picom-kavis.conf) |
| Pencere (CSD) | 8px | tema CSS `decoration` + `window.csd > .titlebar` |
| Kart / çerçeve / kutucuk / ipucu | 8px | `.kavis-card`, `.desktop-card`, `.setting-tile`, tema CSS `frame, .card, tooltip.background` |
| Düğme / hover kutusu / görev çubuğu vurgusu / giriş kutusu | 6px | `.kavis-panel button`, popup/picker düğmeleri, tema CSS `button, entry, spinbutton` |
| Sekme | 6px (üst köşeler) | tema CSS `notebook tab`, `.picker-tab` |
| Kaydırıcı topu | tam yuvarlak | tema CSS `scale slider`, `.kavis-popup scale slider` |
| Yiv / ilerleme çubuğu | tam yuvarlak | tema CSS `scale trough`, `progressbar` |

GTK3 CSS'te değişken yok (`@define-color` yalnız renk) — değerlerin
tek kaynağı BU TABLO; koda yeni yarıçap yazarken buradan al, sapma
görürsen düzelt.

İç içe kutularda iç yarıçap = dış yarıçap − kenarlık (kutucuk 8, içindeki
düğme 7): eşit verilirse dolgu köşede kenarlığın dışına taşar.

X menüleri (Gtk.Menu) picom'un genel 8px'iyle yuvarlanır; menü
kutusuna GTK içinden 12px verilemiyor (kabul edilmiş sınır).

## Animasyonlar (J2 — v0.4-test4 A3 ile güncellendi)

**Tek eğri: `cubic-bezier(0.2, 0.9, 0.25, 1)`, tek süre: 180 ms.**
Hızlı çıkıp yavaş oturur. VM turunda "animasyonlar sert" denmesinin
sebeplerinden biri kapanışın açılıştan hızlı olmasıydı (180/120) —
göz bunu kesme olarak okuyor; ikisi de 180 ms.

| Olay | Süre / eğri | Nasıl |
|---|---|---|
| Pencere açılış | 180 ms, ölçek 0.96 → 1 + solma | picom `open` betiği |
| Pencere kapanış | 180 ms, ölçek 1 → 0.96 + solma | picom `close` |
| Küçült (görev çubuğuna) | 180 ms, ölçek 1 → 0.82 + solma | picom `hide` |
| Geri getir | 180 ms, ölçek 0.82 → 1 + solma | picom `show` |
| Panel popup'ı | 180 ms, 12 px kayma + solma | picom kural bloğu (yön görev çubuğu kenarına göre) |
| Hover | 120 ms, aynı eğri | GTK CSS `transition` |
| Kutucuk basış | anlık renk (%14) | GTK CSS `:active` |

Gölge (`shadow-*`) pencereyle birlikte ölçeklenir ve solar; yoksa
küçülen pencerenin çevresinde tam boy gölge kalır.

**picom preset'i kullanılmıyor:** preset'ler yalnız `duration`,
`scale`, `direction` alıyor (12.5 man sayfasında doğrulandı), eğri
verilemiyor. Bu yüzden dört tetikleyici de elle yazılmış betik.
`tools/check-picom.sh` yapılandırmayı gerçek picom 12.5 ile açıp
doğruluyor (Ayarlar'ın ürettiği 17 varyant dahil) — reddedilen
yapılandırma masaüstünü compositor'süz bırakır.

Sınırlar (bilinçli kabul):
- GTK3 CSS `transform` animasyonu bilmez — basışta 80 ms küçük ölçek
  verilemiyor; karşılık `:active` rengi.
- picom v12 öncesi animasyon bloğunu yok sayar (yalnız yerel test
  ortamını etkiler).

## Boşluklar (J3)

| Ölçü | Değer |
|---|---|
| Popup iç kenar | 16px |
| Kart iç dolgu | 12px (A4) |
| Öğeler arası / kartlar arası | 8px |
| Gruplar arası | 12px (panel sağ bölge grupları: yatay 6 / dikey 8) |

Sıkışıklık yok — kullanıcı ferah hissetmeli. Yeni bir widget bu
değerlerin dışına çıkacaksa sebebi commit mesajında yazılır.

## Kenarlık ve gölge (A4, v0.4-test4)

| Öğe | Değer | Nerede |
|---|---|---|
| Üst kenar çizgisi | 1px `@kavis_top_edge` (koyu: beyaz %6, açık: siyah %5) | her yüzeyde `box-shadow: inset 0 1px 0` — panel, popup, kart, kutucuk, headerbar, çerçeve, ipucu, menü |
| Pencere gölgesi | picom `shadow-radius 18`, `shadow-opacity 0.35`, y+6 | picom-kavis.conf |
| GTK gölgesi (popup) | `0 8px 24px rgba(0,0,0,0.35)` | bileşen CSS'i — picom'un değerlerine eşlenir |

Üst çizgi **kenarlık değil gölge** olarak veriliyor: kenarlık widget'ın
boyutunu değiştirir, oturmuş her yerleşim kayar.

Gölge dar ve koyu olursa pencere çıkartma gibi durur; geniş ve açık
olunca derinlik okunur — A4'ten önce 14/0.45'ti.

## Açık tema paleti (B2, 3 Eyl 2026)

Tek kaynak `packages/kavis-common/theme.vala` (@kavis_* adları; her
bileşen CSS'i bu adları kullanır, hex yazılmaz). GTK uygulamaları için
aynı değerler `gtk-light.css`'te, openbox için `Kavis-Light/themerc`
(rules'ta themerc'den sed ile türetilir). Geçiş canlı: kavis.conf
`[appearance] theme` değişince palet sağlayıcısı yerinde yenilenir.

| Rol | Koyu | Açık |
|---|---|---|
| Zemin (masaüstü/arka plan) | #0D141B | #F3F5F7 |
| Panel / görev çubuğu | #121C26 | #E9EDF1 |
| Yüzey (pencere, menü) | #17222C | #FFFFFF |
| Kart (ayar grubu) | #1C2833 | #FFFFFF |
| Yüzey hover | #1D2C38 | #EEF1F4 |
| Kenarlık | #233A45 | #D5DBE1 |
| Ana metin | #E6EDF3 | #1A2430 |
| İkincil metin | #8B9BA8 | #5C6B78 |
| Soluk metin (takvim dış günler) | #4A5A66 | #A0ACB8 |
| Vurgu | #2DD4BF (aynı) | #2DD4BF (aynı) |
| Vurgu üstü metin | #0D141B | #0D141B |
| Hover / basılı örtüsü | beyaz %9 / %14 | siyah %6 / %10 |
| Kart kenarlığı | beyaz %8 | siyah %10 |
| Panel akriliği | rgba(18,28,38,.85) | rgba(233,237,241,.85) |
| Karartma (genel bakış, Ctrl+Alt+Del) | rgba(13,20,27,.92) | rgba(243,245,247,.92) |

Başarı/uyarı/hata renkleri iki temada aynı. Kapat düğmesi hover'ı
(#C42B1C) iki temada aynı.

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
| Başlık yüksekliği | 46px her yerde (test2 E2): openbox Inter 10 + padding.height 14 + 1px kenarlık (A1 ile ölçüldü); CSD headerbar min-height 46px; Tilix'in çubuğu referans |
| Düğme sırası | – ☐ ✕ sağda; ikon + başlık solda (NLIMC) |
| Düğme ikonu | 16px xbm, 12px glif — GTK sembolik ikonlarla aynı optik boy |
| Kapat hover / basılı | #C42B1C / #A02316, beyaz ✕ (CSD ile aynı) |
| Diğer hover / basılı | #2E3842 / #374149 |

### C2 (v0.4-test4): eşleşme artık denetleniyor

Bu madde iki tur atlandığı için sayılar gözle değil `check-visual.sh`
ile karşılaştırılıyor: themerc'nin başlık zemini / etkin metin rengi /
kapat hover-basılı renkleri ile gtk-dark.css'in headerbar değerleri
birebir aynı olmak zorunda, headerbar 46px ve düğmeleri 46×32 olmak
zorunda, ve openbox'ın hover rengi (rgba bilmediği için elle
hesaplanmış) başlık zemini + %10 beyaz ile ±1 kanal içinde uyuşmak
zorunda. Sapan bir değer push öncesi kırmızı yanar.

Bu turda kapanan iki fark:
- CSD başlık metni GTK'nın `.title` sınıfı yüzünden **kalın**dı,
  openbox başlığı normal. İkisi yan yanayken göze çarpan tek şey buydu;
  headerbar'ın başlığı da normale çekildi.
- Firefox kendi başlık çubuğunu çiziyordu (sekmeler başlıkta).
  `browser.tabs.inTitlebar = 0` (policies.json, "default" — kullanıcı
  geri açabilir) ile artık sistem başlık çubuğunu alıyor.

Kanıt: `docs/gorseller/baslik-cubugu-c2.png` — üstte CSD, altta openbox
çerçevesi, aynı yükseklik ve aynı renkler.
(`CSD=1 tools/theme-screenshot.sh` ile yeniden üretilir.)

Kalan openbox sınırları (bilinçli kabul): düğme kutusu kare (46px
genişlik olmaz — openbox düğme boyutunu başlık yüksekliğinden türetir,
themerc'de genişlik seçeneği yok), 1-2px düğme arası boşluk, hover
kutusu tam yükseklik dolmaz, animasyon yok. Bunlar tema dosyasıyla
değil ancak openbox'ı yamalamakla çözülür; imzalı Debian paketini
yamalamak kapsam dışı.

## Fare imleci (C3, v0.4-test4)

Varsayılan **Breeze Light**, boyut **24**. Beyaz gövde + koyu kontur:
koyu masaüstünde okunan, Windows 11'in imlecine en yakın hazır tema.
Kendi ürettiğimiz Kavis-Cursors 109 ad kapsıyor ama gerisi için
Adwaita'ya düşüyordu ve VM turunda görülen o düşüşlerdi; artık hem
düşüş Breeze Light'a hem varsayılan Breeze Light'a.

Kavis-Cursors silinmedi — `update-alternatives --config x-cursor-theme`
ile seçilebilir (öncelik 100, varsayılan 150).

Bibata-Modern-Classic da adaydı; kurulu boyutu 178 MB (ISO bütçesinin
%10'u), Breeze 30 MB.

Ad dört yerde geçiyor ve `tools/check-visual.sh` dördünün de aynı
olmasını şart koşuyor: `55kavis-cursor` (XCURSOR_THEME — Qt, Firefox),
`settings.ini` (GTK), `/etc/X11/Xresources/kavis` (Xcursor kaynak
veritabanı), `index.theme` (metatema) + update-alternatives varsayılanı.
Biri sapınca imleç pencereden pencereye şekil değiştirir.

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
