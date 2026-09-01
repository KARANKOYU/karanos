# flameshot — referans incelemesi

İlgili Kavis maddesi: 29 (ekran görüntüsü/kaydı). İnceleme tarihi: 2026-09-01,
depo HEAD'i `c886a35` (2026-08-30).

## Kimlik

- Depo: flameshot-org/flameshot. Lisans GPL-3.0-or-later. C++ / Qt.
- HEAD sürümü 14.0.0, Qt6 ile derleniyor. Debian trixie paketi ise
  **12.1.0+ds-2** (Qt5 ile derlenmiş); trixie-backports'ta 13.3.0 var
  (sources.debian.org'dan doğrulandı).
- Köken: başlık yorumlarına göre seçim ekranı Lightscreen'in alan
  diyaloğu ile KDE KSnapshot'ın bölge yakalayıcısından evrilmiş.
- Çekirdek: ~2100 satırlık `CaptureWidget` (tam ekran editör) +
  `ScreenGrabber` (görüntü alma) + araç sınıfları. Tek örneklik
  KDSingleApplication ile; Linux'ta kalıcı bir daemon süreci ve D-Bus
  arayüzü (`org.flameshot.Flameshot`) var.

## Donmuş kare ve seçim arayüzü nasıl çalışıyor

Akış iki adım: **önce ekran görüntüsü alınır, sonra bu görüntü tam ekran
bir pencereye basılır.** "Donma" bir yanılsama — `CaptureWidget`
çerçevesiz, her zaman üstte, tam ekran bir pencere açar ve `paintEvent`
içinde alınan pixmap'i (0,0)'a çizer; kullanıcı donmuş kareyi görür.

- **X11'de görüntü alma** (`ScreenGrabber`): iki yol var. Varsayılan yol
  xdg-desktop-portal'ın Screenshot D-Bus çağrısı (15 sn zaman aşımı,
  dönen URI'den dosya okunup silinir). Portal yoksa — i3/XMonad gibi
  bağımsız WM'lerde olağan durum — otomatik olarak "legacy X11" yoluna
  düşer: kök pencereden doğrudan grab. **Kavis openbox'ta portal
  bulunmayacağı için geçerli yol doğrudan X11 grab'idir; portal
  katmanına hiç gerek yok.**
- **Çoklu monitör:** tüm ekranlar mantıksal geometriyle tek pixmap'te
  birleştirilir; monitöre kırpma DPR (piksel yoğunluğu) ölçeklemesiyle
  yapılır ve kodun en çetrefil kısmı bu matematik. Güncel sürümde
  davranış değişmiş: birden çok monitör varsa önce küçük önizleme
  kartlarıyla bir "monitör seç" ekranı çıkıyor (ok tuşları / 1-9 / Esc,
  yerel bir olay döngüsüyle beklenir), editör yalnız seçilen monitörde
  açılıyor. Eski "tüm masaüstüne yayılan tek pencere" modeli terk
  edilmiş.
- **Pencere bayrakları:** X11'de her-zaman-üstte + çerçevesiz + araç
  penceresi bileşimi; WM'yi tamamen atlama bayrağı X11'de GNOME
  çökmesine yol açtığı için kaldırılmış (Wayland'da hâlâ kullanılıyor).
  Odak kaybolursa ekrana "kısayollar çalışmaz" uyarısı çiziliyor —
  X11'de odak kapmanın güvenilmez olduğunun itirafı.
- **Karartma:** `paintEvent` sonunda seçim dikdörtgeni dışında kalan
  bölge, clip bölgesi (QRegion farkı) ile yarı saydam siyah boyanır;
  opaklık ayardan geliyor.
- **Seçim:** `SelectionWidget` ayrı bir alt widget; 8 tutamaç (4 köşe +
  4 kenar ortası), hangi kenarın sürüklendiği bir enum'la izlenir;
  taşıma, klavyeyle ince ayar, seçim geometrisi (x,y,w,h) göstergesi ve
  isteğe bağlı yapışma ızgarası var.
- **Büyüteç:** `MagnifierWidget` — imleç çevresindeki 17×17 piksellik
  alanı ~10 kat büyütüp gösterir (yuvarlak/kare seçenekli, ayardan
  açılır). Piksel hassas seçim için birebir; Kavis'te de olmalı.

## Düzenleme araçları mimarisi

- Her araç `CaptureTool` soyut sınıfından türer; kimlik bir `Type`
  enum'u, üretim `ToolFactory` içindeki switch. Gerçek bir
  eklenti/plugin sistemi yok — derleme zamanı kayıt. Enum değerleri
  kullanıcı yapılandırmasında saklandığı için sıraları asla
  değiştirilemiyor (kaynakta büyük harfli uyarı var) — kendi aracımızda
  kimlikleri en baştan metin anahtarı yapmak bu tuzağı önler.
- Üç soyut ara sınıf işi kolaylaştırıyor: iki-nokta araçları (ok, çizgi,
  dikdörtgen, daire, pixelate), serbest çizim araçları (kalem, marker)
  ve çizmeyen buton eylemleri (kaydet, kopyala, geri al…).
- Çizimler pixmap'e hemen yakılmıyor: her araç örneği bir **nesne
  listesinde** (`CaptureToolObjects`) tutulur ve her `paintEvent`'te
  sırayla yeniden çizilir. Böylece nesne seçme, taşıma, katman sırası
  değiştirme ve `QUndoStack` ile geri al/yinele mümkün; dışa aktarırken
  liste pixmap'e basılır. Kavis'in kendi aracı için de doğru model bu.
- Araç butonları `ButtonHandler` ile seçimin kenarına dizilir; seçim çok
  küçükse butonlar seçimin içine taşıyor (bilinen şikâyet, aşağıda).
- Araç seti: kalem, çizgi, ok, dikdörtgen, daire, marker, **pixelate**
  (bulanıklaştırma karşılığı), metin, daire-sayaç, pin (ekrana
  iğneleme), renk tersleme, taşıma, kaydet/kopyala/çık. Madde 29'un
  istediği ok/kutu/yazı/bulanıklaştırma dördü de mevcut.

## Eksikler (bizim isteklere göre)

- **Pencere seçici yok.** En çok yorum alan açık isteklerden biri
  (#49, "Selecting a window in GUI mode", 49 yorum). Seçim yalnız
  serbest dikdörtgen; pencere sınırına otomatik oturma yok. Not:
  Kavis'in "seçilen pencerenin üstünden başka pencere geçse bile o
  pencere" isteği, donmuş-kare modelinde kendiliğinden çözülür — kare
  donuk olduğu için üstünden bir şey geçemez. Sorun yalnız *canlı*
  yakalamada (ör. gecikmeli çekim) doğar; orada kapatılmış pencere
  içeriğine X11'de ancak kompozitör (picom) açıkken XComposite pencere
  pixmap'iyle erişilebilir — kompozitörsüz erişilemez (doğrulanmadı,
  kaynak kodda buna dair hiçbir şey yok).
- **Video kaydı yok**, kapsam dışı; depoda hiçbir kayıt altyapısı yok.
- **Global kısayol yakalama yalnız Windows'ta** (yerel olay filtresi).
  Linux'ta kısayolu masaüstü ortamı bağlar; bu bizim için sorun değil —
  openbox `rc.xml`'e Print için bir keybind yazılır, komut olarak
  yakalama aracı çağrılır. `Ctrl+Print` gibi ikinci bir bileşim de aynı
  dosyada ayrı bir keybind olur; araç tarafında iş çıkarmaz. flameshot
  kullanılırsa ikinci süreç görüntü işini kendi içinde yapar, sonucu
  D-Bus'la kalıcı daemona devreder — yani `flameshot gui` doğrudan
  openbox komutu olarak bağlanabilir.

## Tuzaklar (tekrar eden issue şikâyetleri)

En çok yorumlu açık issue'lardan (gh api ile alındı, yorum sayısına göre):

- **Pano kopyalama çalışmıyor** — açık ara en tekrarlayan tema (53, 35,
  34, 31, 29… yorumlu en az 6 ayrı issue). Kök neden çoğunlukla X11
  pano modelidir: panonun sahibi süreçtir, süreç kapanınca içerik uçar.
  flameshot'ın çözümü ders niteliğinde: kısa ömürlü GUI süreci görüntüyü
  D-Bus üzerinden **kalıcı daemon sürecine devreder**, panoyu daemon
  tutar. Kavis'in kendi aracı da ya kalıcı bir süreçte pano tutmalı ya
  da bir pano yöneticisine güvenmeli.
- **GNOME/Wayland kısayol sorunları** (184 ve 82 yorum): kısayoldan
  tetiklenince yakalayamama, dbus'a hiç ulaşmama. Neredeyse tamamı
  Wayland/portal kaynaklı → Kavis X11 + openbox'ta geçersiz.
- **"Unable to capture the screen"** (60, 34 yorum): portal zinciri
  kırılınca çıkan genel hata. X11 legacy yoluna sabitlenince görülmüyor.
- **Düzenleme butonları küçük seçimde görüntünün içine biniyor** (42
  yorum) — kendi arayüzümüzde buton şeridini seçim dışına, ekran
  kenarına sabitleyerek kaçınılabilir.
- **Esc'nin arayüzü kapatmaması** (36 yorum), **imlecin görüntüye dahil
  edilememesi** (43 yorum), **var olan resmi açıp düzenleme isteği**
  (35 yorum) — küçük ama kullanıcıyı çok bulan pürüzler.
- Tepsi simgesi **zorunlu değil**: daemon QSystemTrayIcon kullanıyor ama
  ayarla tamamen kapatılabiliyor; tepsisiz de çalışıyor.

## Kavis için çıkarımlar

Madde 29F kararına girdi:

1. **flameshot görüntü tarafını büyük oranda karşılıyor** (donmuş kare,
   karartma, seçim, büyüteç, ok/kutu/yazı/pixelate, pano+bildirim), ama
   üç isteği karşılamıyor: pencere seçici yok, video yok, arayüz Qt.
2. **Qt maliyeti:** trixie paketi Qt5 ile derli; gereken Qt5 çekirdek
   kütüphaneleri toplam ~30 MB kurulu boyut + flameshot ~3 MB (paket
   üstverisinden; squashfs sıkıştırmasıyla ISO'ya kabaca 10–15 MB
   biner — yaklaşık değer, doğrulanmadı). 1.5 GB hedefini bozmaz ama
   GTK ağırlıklı sisteme ikinci bir toolkit sokar; ana/kontrast rengi
   ayardan turkuaza çekilebilse de GTK temasına tam uymaz. Trixie
   sürümünün 12.1.0 (eski) olduğu da not edilmeli.
3. **Video sekmesi için her durumda ayrı araç gerek.** Öneri: **ffmpeg
   x11grab** (trixie'de var, ek bağımlılık neredeyse sıfır — ffmpeg
   zaten çoğu medya yığınında geliyor). Aynı seçim arayüzünden bölge
   alınır, x11grab'a geometri olarak verilir; durdurma kısayol veya
   tepsi üzerinden SIGINT ile olur, ses PulseAudio girişinden eklenir.
   wf-recorder Wayland'a özgüdür, X11'de çalışmaz. Alternatifler
   (SimpleScreenRecorder: yine Qt; GStreamer ximagesrc: daha çok
   bağımlılık) daha pahalı.
4. **Kendi GTK aracı yazılacaksa** öğrenilecek desen net ve GTK'ya
   birebir taşınabilir: (a) tek birleşik kök-pencere grab'i al, (b)
   çerçevesiz/üstte tam ekran pencerede donmuş kareyi çiz, (c) seçim
   dışını clip bölgesiyle karart, (d) düzenlemeleri vektörel nesne
   listesinde tut, dışa aktarırken bas (geri al/yinele bedavaya gelir),
   (e) panoyu kalıcı bir sürece devret, (f) çoklu monitörde DPR
   matematiğine en baştan bütçe ayır — flameshot'ta hataların en yoğun
   olduğu yer burası. Pencere sekmesi için pencere geometrileri EWMH
   yığın listesinden okunup seçim dikdörtgeni pencereye oturtulabilir;
   donmuş kare üstünde çalıştığı için "üstünden pencere geçme" derdi
   kalmaz.
5. **Özet karar önerisi:** en ucuz yol trixie'den flameshot + ffmpeg
   tabanlı basit kaydediciyi ayrı ayrı gemiye almak; ama madde 29'un
   "tek uygulama, görüntü/video sekmeli, pencere seçicili" tarifini
   ancak flameshot desenlerini örnek alan kendi GTK aracımız tam
   karşılar. Ara yol: ilk sürümde flameshot'u kullanıp kendi aracı
   sonraki aşamaya bırakmak.
