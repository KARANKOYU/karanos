# Kavis — durum ve karar günlüğü

Bu dosya "ne yapıldı" listesi değil, **neden öyle yapıldı** kaydı.
Kod okununca anlaşılmayan kararlar, denenip vazgeçilen yollar ve bir kez
ısırmış tuzaklar burada. En yeni en üstte.

NOT: 2026-09-01 öncesi kayıtlar "Karan OS" adını ve `karanos-*` paket
adlarını kullanır — tarihsel doğruluk için değiştirilmedi.

---

# OTURUM DURUMU — 2 Eylül 2026 (devir teslim kaydı)

Bu bölüm bağlam sıfırlanmadan önce yazıldı. Yeni oturum YALNIZ bu
dosyayı ve CLAUDE.md'yi okuyarak hiçbir şey kaybetmeden devam
edebilmeli. Aşağıdaki alt kayıtlar (eski girdiler) aynen duruyor;
buradaki özet onların üstüne günün TAMAMINI toplar.

## 1. BUGÜN YAPILAN HER ŞEY (commit sırasıyla)

### 1a. Açılış deneyimi düzeltmeleri (İş 1-2-3, "Grup D öncesi" istegi)

**İş 1 — konsol çıktısı gizlendi (`0d54bfa`).**
- `iso/auto/config` BOOTAPPEND: `loglevel=3 vt.global_cursor_default=0
  rd.udev.log_level=3` eklendi (quiet+splash zaten vardı). loglevel=3
  KERN_ERR'i de saklar → VirtualBox VMSVGA'daki vmwgfx "unsupported
  hypervisor" satırları konsola düşmez; journald tam günlüğü tutar.
- `iso/config/includes.chroot/etc/initramfs-tools/modules`: i915,
  amdgpu, nouveau açıkça eklendi (splash erken başlasın);
  `0300-plymouth.hook.chroot` gerekli-listesine bu üçü de girdi
  (uyarı düzeyinde raporlanır, arm64'te i915 yok → hata değil).
- `docs/referans/virtualbox.md` (yeni): VMSVGA çalışıyor (vmwgfx →
  simpledrm düşüşü zararsız), uyarısız istenirse VBoxSVGA önerisi
  (henüz elle DOĞRULANMADI — belgeye öyle yazıldı).

**İş 2 — splash'i lightdm devralıyor (`37579aa`).** İki katmanlı kök
sebep bulundu:
1. Debian lightdm.service `Conflicts=plymouth-quit.service` taşıyor →
   bizim `--retain-splash` drop-in'imiz normal açılışta HİÇ çalışmıyor
   (SPLASH-TIMING quit=0.0s'nin açıklaması buydu). Splash'i lightdm
   kapatıyor.
2. lightdm splash'i yalnız Plymouth'un VT'si `minimum-vt`den küçük
   DEĞİLSE devralıyor; Plymouth VT1'de, varsayılan minimum-vt=7 →
   "not replacing it" deyip retain'siz öldürüp X'i VT7'de açıyordu
   (siyah ekran + VT değişimi buydu).
Düzeltme dosyaları:
- `iso/config/includes.chroot/etc/lightdm/lightdm.conf.d/50-kavis-splash-devir.conf`:
  `[LightDM] minimum-vt=1` + `[Seat:*] xserver-command=X -background
  none` (ikincisi `f9d0813`'te eklendi — X kökü siyaha boyamasın,
  framebuffer'daki retain karesi masaüstü çizilene kadar kalsın).
- `iso/config/includes.chroot/etc/systemd/system/lightdm.service.d/kavis.conf`:
  `After=kavis-boot-sound.service` (müzik bekletme artık işleyen
  yerde) + `Conflicts=getty@tty1.service` + `After=getty@tty1.service`
  (GDM'in aynı çözümü; X tty1'de).
- `packages/kavis-boot/src/plymouth-quit-dropin.conf`: başına "bu
  drop-in normal açılışta ÇALIŞMAZ, yalnız güvenlik ağı" notu.
- boot-check: quit artık `plymouth-quit-wait.service`
  ActiveEnterTimestampMonotonic'ten okunuyor (`plymouth --wait`
  plymouthd gerçekten çıktığı anda döner — kapanışı kim yaparsa yapsın
  doğru an); quit=0 artık sira_hatasi'na giriyor.

**İş 3 — GRUB geri sayımı (`f7f1280`).**
- live-build temasının gri `progress_bar { id="__timeout__" }` kutusu
  (İngilizce metinli) kaldırıldı; GRUB'da bu id'yi taşıyan HERHANGİ
  bileşen varsayılan kutuyu kapatır → `9600-grub-marka.hook.binary`
  artık temaya ortalanmış #8B9BA8 bir `label` basıyor, metin
  `%d saniye içinde otomatik başlıyor` (önce tabloya eklendi:
  `boot.autoboot_countdown`). Yazı tipi Unifont (TR glifleri menü
  girdilerinde zaten kanıtlı). sed `/^#progress bar$/,$d` + heredoc;
  gerçek live-build theme.txt üzerinde yerelde doğrulandı.

### 1b. SPLASH-HANDOFF denetiminin üç hâli (ders!)

1. **İlk hâl** (İş 2 içinde): |quit − X proses başlangıcı| mutlak
   farkı, eşik 5 sn. **v0.3-test2'de 5/5 profil bundan düştü** —
   çünkü retain akışında X, Plymouth'tan ÖNCE başlar; TCG'de X
   açılışı 13+ sn ve bu örtüşme İYİ durumdur (splash X'i örtüyor).
2. **Yönlü hâl** (`5a953f1`, v0.3-test3): quit X'ten sonraysa geç,
   öncesi >5 sn ise düş. Doğruydu ama görsel boşluğu ölçmüyordu.
3. **Şimdiki hâl** (`f9d0813`, v0.3-test4): SPLASH-HANDOFF = quit →
   openbox proses başlangıcı (masaüstünün ilk çizen süreci; /proc
   stat 22. alan, CLK_TCK ile µs). Eşik 3 sn. Artı ikinci kanıt
   katmanı: `/var/log/lightdm/lightdm.log`'da "retaining splash" →
   SPLASH-RETAIN-OK; "not replacing it"/"no displays replace" →
   SPLASH-RETAIN-FAIL (ölümcül). Retain kanıtlıysa 3 sn aşımı yalnız
   UYARI (ekranı retain karesi örtüyor — `-background none` sayesinde
   siyah yok); retain kanıtı yoksa/belirsizse aşım testi düşürür.
   openbox başlangıcı `proc_basla()` yardımcıyla okunur (boot-check).

**Etiket/koşu geçmişi bugün:**
- v0.3-test2 (`f7f1280`): 5/5 KIRMIZI (yalnız SPLASH-HANDOFF-FAIL;
  diğer her şey yeşildi — quit=139.8s İLK KEZ gerçek değer).
- v0.3-test3 (`5a953f1`): 4/5 yeşil; tek kırmızı uefi-genis'te GRUB
  menüsünde takılma (900 sn) — TEK SEFERLİK çıktı, aynı GRUB test4 ve
  test5'te sorunsuz. İptal edilemedi (gh run cancel → HTTP 403, token
  yetkisi yok).
- v0.3-test4 (`f9d0813`): **5/5 YEŞİL.** Kanıtlar: 5 profilde
  SPLASH-RETAIN-OK, handoff 2.6-3.7s (retain örtüyor, uyarı), quit
  131-169s gerçek değerler. Açılış sırası VM testi için hazır ISO:
  `kavis-0.3-test4-amd64.iso`.
- v0.3-test5 (`59a8a13`): Grup D ISO'su — **koşu 33616072408 bu oturum
  kapanırken ÇALIŞIYORDU, sonucu alınamadı.** Yeni oturum ilk iş
  `gh run view 33616072408` ile bakmalı (aşağıda 2. bölüm).

### 1c. Plan güncellemesi: maddeler 60-69 (`bdcae97`)

`docs/gorev-listesi.md` numaralama 59'dan devam etti:
- **60** (A/B/C): popup dış-tıklama kuralı — Grup C hotfix.
- **61** GTK ortak başlangıç → Grup D. **62** hypervisor uyarı
  listesi → Grup D (tanım) / F (kullanım).
- **63** USB güvenli kullanım, **64** USB onarımı → Grup E.
- **65** CachyOS incelemesi → Grup G (H'nin girdisi).
- **66** sıcaklık izleme, **67** kritik uyarı, **68** soğutma katmanı
  → **YENİ GRUP H2** (H doluydu; A2 emsali; roadmap'te sürüm 0.8).
- **69** yeniden kurulum "dosyalarımı koru" → Grup I (tasarım:
  docs/yeniden-kurulum-tasarimi.md; madde 16 işareti 69'a çevrildi).
Grup sırası satırları ve roadmap.md güncellendi. Ayrıca `7f45a03`:
docs/bilinen-sorunlar.md + docs/yeniden-kurulum-tasarimi.md doğdu.

### 1d. Grup C hotfix — madde 60 (`f303048`)

Üç hata iki kök sebepten:
1. `on_outside_click` event.x/y'yi popup'a göre sanıyordu; alt
   widget'lardan (takvim hücresi) kabaran olayların koordinatı ALT
   pencereye göredir → içerisi "dışarısı" okunuyordu. Çözüm:
   `PanelPopup.press_outside()` — x_root/y_root vs pencere
   origin+boyut. Üç pencere de (PanelPopup, StartMenu, PowerMenu)
   bunu kullanıyor.
2. Uygulama içi tıklamalar (panel, güç düğmesi) popup'a hiç
   ulaşmıyordu (owner_events normal teslimat). Çözüm: GTK menü
   tekniği `Gtk.grab_add(this)` — uygulama içi olaylar popup'a
   yönlenir, basış tüketilir → güç düğmesi toggle'ı (60B)
   kendiliğinden çözüldü, panel tıklaması menüyü kapatıyor (60C).
3. Ek bulgu: show_all sonrası seat grab NOT_VIEWABLE ile sessizce
   başarısız olabiliyor → `PanelPopup.seat_grab()` durum denetimi +
   50 ms aralıkla 10 deneme. Güç menüsü kapanınca `closed` sinyaliyle
   seat grab başlat menüsüne geri veriliyor (GTK grab'ları kendi
   yığınıyla hallediyor).
Doğrulama: Xvfb senaryo betiği (scratchpad) — takvim içi tıklama açık
bırakır, dışarısı kapatır, güç toggle, masaüstü tıklaması menüyü
kapatır; ekran görüntüleriyle teyit.

### 1e. Grup D — dokuz madde (madde 59 taraması: `dade6e3`)

Tarama `docs/referans/grup-d-taramasi.md`: openbox snap kusurları
(unsnap yok, monitör önbelleği, tek monitör), dunst kronikleri (ad
çakışması, bellek şişmesi, birlikte kapanma, ekran aç/kapa konumu),
X11 pano yarışları (sahip ölünce pano boşalır; PRIMARY alınmaz; şifre
ipucu), flameshot (delay önizlemeyi geciktirir; monitör-bazlı çekim).
Hepsi tasarım kuralına dönüştü.

**Madde 61 (`3071b4f`) — GDK_GL ortak başlangıç: ÇÖZÜLDÜ.**
`packages/kavis-common/appinit.vala` kanonik; `tools/build-packages.sh
prepare_sources` her GTK paketinin src ağacına kopyalar (kopyalar
.gitignore'da: `packages/*/src/logic/appinit.vala`,
`packages/*/src/appinit.vala`). `Kavis.AppInit.init()` Gtk.init'ten
önce çağrılır; GDK_GL=disable (override=false — GDK_GL=always ile
geri açılabilir). Panel, kavis-snap, kavis-tools kullanıyor; bizim
olmayan nemo-desktop autostart'ta env ile alıyor.

**Madde 62 (`2a245a4`).** `/usr/share/kavis/log-ignore.d/` (README +
hypervisor.list): satır başına grep -E deseni, her desenin zararsızlık
gerekçesi şart. İlk üyeler vmwgfx desenleri. Grup F'nin sağlık aracı
bu dizini okuyacak.

**Madde 4 (`94562b6`) — W11 yerleşimi.** panel.vala: Başlat+pencere
listesi ORTALANMIŞ küme (iki genişleyen boşluk; window_scroll
`propagate_natural_width` — doğal genişliği ister, sıkışınca çöker);
sağ bölge pack_end sabit. Düğme genişliği hesabı artık panel
geometrisinden (`panel − right_box − start_button − 16`) — scroll
tahsisinden okumak kendini besliyordu (32'de başlayan 32'de kalırdı).
Başlat yalnız logo (metin tooltip'te). Akrilik: rgba görsel +
`.kavis-panel.acrylic { rgba(18,28,38,0.85) }`, composited-changed
dinlenir (picom sonra başlayabilir). BLUR BİLEREK YOK (Grup B:
xrender'da çalışmıyor; madde 38 GPU'yla). Hover kutuları 6px yuvarlak,
düğmeler tam yükseklik (Fitts — alt piksel tıklaması ölmesin);
masaüstünü-göster şeridi `.edge` sınıfıyla köşeli. 30 pencere
sıkışması testi geçti (ikonlar 24→16, sağ bölge sağlam).

**Madde 5 (`9f5dae1`) — sağ tık menüsü.** Yeni
`src/logic/panel_config.vala`: ~/.config/kavis/panel.conf ([panel]
position/size/monitor/autohide; KeyFile). Konum alt/üst/sol/sağ —
dikeyde TÜM eksen döner (window_box/cluster/right_box dikey, scroll
policy (NEVER,AUTOMATIC)+propagate_natural_height, WorkspaceIndicator
axis parametresi aldı, strut 4 kenar için ayrı, show_desktop (-1,8)).
Boyut 36/44/52 px. Konum/boyut değişimi `restart_self()`:
`Posix.execv("/proc/self/exe", {"kavis-panel"})` — panel durumsuz, en
hafif sağlam yol (X fd CLOEXEC). Monitör seçimi model adıyla; kaybolan
monitör birincile düşer. Otomatik gizle: strut sıfırlanır, 600 ms
sonra 2 px şeride kayar (`slide_away`), enter/leave INFERIOR filtreli;
popup/menü açıkken saklanmaz (`PanelPopup.any_open()`).
POPUP KONUMLANDIRMASI panel konumuna duyarlı oldu: PanelPopup'ta
`static panel_position`; popup panelin KARŞI yanına açılır (üstteyken
aşağı vb.), başlat menüsü `open(x,y)` artık MUTLAK sol-üst köşe alır
(panel hesaplar, monitöre kıstırır). Menü öğeleri: Konum/Boyut/Ekran
(yalnız >1 monitör)/Otomatik gizle/Ekran ayarları/Görev yöneticisi —
son ikisi `launcher_item()` ile hedef ikili PATH'te yoksa soluk
(kavis-settings Grup F'de gelecek; kavis-tools artık var).
Yeni metinler: panel.menu_position, panel.position_bottom/top/left/
right, panel.menu_size, panel.size_thin/medium/thick,
panel.menu_monitor, panel.monitor_primary, panel.menu_autohide,
panel.display_settings (önce tabloya).

**Madde 37 (`b2e4e50`) — bildirim altyapısı + saat paneli + hızlı
ayarlar.** Yeni dosyalar:
- `src/logic/notifications.vala`: org.freedesktop.Notifications'ı
  PANEL sahiplenir (dunst kurulmadı). NotificationServer DBus sınıfı
  (notify/close_notification/get_capabilities/get_server_information +
  notification_closed/action_invoked sinyalleri; iç sinyaller
  toast_requested, history_changed [DBus (visible=false)]). Geçmiş 50
  kayıtla SINIRLI; kritik (urgency=2) DND'de bile gösterilir ve
  timeout=0 (elle kapatılır); ad alınamazsa YÜKSEK sesle warning.
  replaces_id eski kaydı düşürür.
- `src/ui/toast.vala`: ToastManager + Toast — her toast KENDİ
  penceresi; birincil monitörün WORKAREA sağ-alt köşesinden yukarı
  yığılır (workarea strut'ı düştüğü için panel konumu bedava hesaba
  girer); en çok 4; tıkla kapat.
- Saat popup'ı (CalendarPopup, indicator_popups.vala) büyüdü: takvim +
  bildirim merkezi (uygulama bazlı grup — ilk görülme sırası; grup
  başına "Temizle" [common.clear tabloya eklendi] + "Tümünü temizle")
  + hızlı ayarlar FlowBox'ı + parlaklık kaydırıcısı (yalnız backlight
  varsa).
- `src/logic/quick.vala` arkayüzleri: Wi-Fi nmcli, Bluetooth rfkill,
  gece modu **xsct** (DİKKAT: `sct` trixie arşivinde YOK —
  check-packages yakaladı), Oyun Modu = ~/.config/kavis/gamemode
  durum dosyası (gerçek iş Grup H), parlaklık sysfs/brightnessctl.
  Her arkayüz aracını yoklar; olmayanın kutucuğu HİÇ görünmez.
- ISO listesine: rfkill, xsct, brightnessctl (çalışma anı araçları —
  derleme bağımlılığı değiller, workflow kurulum adımı gerekmez).
- QuickTile widget'ı: `.quick-tile.on` turkuaz vurgusu (CSS popup.vala
  içinde).

**Madde 6 (`75edbdb`) — pencere yönetimi.**
- `0210-openbox-kisayollar.hook.chroot` (yeni): Debian rc.xml'e
  `</keyboard>` öncesi "Kavis kisayollari" bloğu enjekte (idempotent,
  grep guard; python3 varsa XML doğrulaması — chroot'ta python yok,
  atlanır; yerelde doğrulandı). W-Left/Right yarım (Unmaximize +
  MoveResizeTo %50), W-Up Maximize, W-Down If-maximized→Unmaximize
  else Iconify. Alt+Tab ve C-A-ok Debian varsayılanında zaten var.
- `src/snap.vala` → **kavis-snap** ikilisi (kavis-panel paketi, rules
  ikinci valac hedefi + appinit). 80 ms XQueryPointer anketi;
  sürükleme = "tuş basılıyken ETKİN pencerenin geometrisi değişti"
  (panel tıklaması/masaüstü seçimi asla tetikleyemez). Kenarlar yarım,
  köşeler (180 px) çeyrek, üst büyüt; turkuaz yarı saydam önizleme
  (kompozitörsüz atlanır). UNSNAP: yapıştırma öncesi geometri saklı;
  pencere çekilince boyut anında geri (press_geometry o boyuta
  güncellenir — 59a8a13 düzeltmesi: yapışıkken tekrar yapıştırmada
  eski boyut kaybolmasın). Monitör düzeni HER olayda taze okunur.
- nemo ISO listesine; autostart'a `GDK_GL=disable nemo-desktop` ve
  `kavis-snap`. Masaüstü simgeleri nemo-desktop'tan (nemo zaten madde
  39 kararı — E'ye çift iş değil).

**Madde 55 (`dfaf1f7`) — genel bakış + odaklanma.**
- `src/logic/panel_service.vala`: org.kavis.Panel DBus servisi —
  openbox kısayolları çalışan panele `gdbus call` ile seslenir
  (libglib2.0-bin ISO'ya girdi; Recommends kapalıyken gelmiyordu).
  Metotlar: ShowOverview, ShowClipboard, VolumeUp/Down/Mute.
- `src/ui/overview.vala`: Win+Tab — her masaüstü bir kart (etkin
  turkuaz çerçeve), pencere satırı tıkla→git, satırı karta sürükle→
  taşı (GTK DnD, hedef "application/x-kavis-window", yük XID +
  NUL sonlandırmalı), kart başlığı→masaüstüne geç. Canlı küçük
  görüntü BİLEREK yok (XComposite mekanizması kozmetik kazanca
  değmez). Karartma sınıfı İÇ kutuda (app_paintable pencere CSS
  arka planı ÇİZMEZ — PanelPopup deseni; Xvfb'de görülüp düzeltildi),
  padding CSS'te (border_width kenarda parlak şerit bırakıyordu).
- Masaüstü geçiş animasyonu picom show/hide tetikleyicilerinden
  bedava (map/unmap 150 ms).
- `src/logic/focus.vala`: Odaklanma = süreli DND (30 dk vars.);
  bitince focus.finished bildirimi. Uygulama engelleme listesi
  BİLEREK Grup F'ye (Ayarlar yüzeyi ister). Hızlı ayarlara kutucuk.
- DND kapanınca bastırılanların özeti tek toast (notif.missed) —
  set_dnd içinde suppressed sayacı.
- 0210'a W-Tab ve W-v keybind'leri eklendi.

**Madde 7 (`76fc16d`) — pano + OSD + kavis-tools.**
- `src/logic/clipboard.vala`: owner-change → hedefler arasında
  x-kde-passwordManagerHint varsa ALMA → request_text → geçmişe
  (madde 59 kuralları). Yalnız CLIPBOARD; kendi set ettiğimiz
  (last_set) geri yakalanmaz; aynı içerik üste taşınır; sınır
  panel.conf [clipboard] limit (vars. 25, 5-100). Sabitlenenler
  ~/.config/kavis/clipboard-pinned (KeyFile, 0600). Aktif olarak
  panoyu YENİDEN SAHİPLENMİYORUZ (agresif varyant; yarış riski) —
  geçmiş kendi kopyamızdan yaşıyor.
- `src/ui/clipboard_popup.vala`: Win+V — birincil monitör ortası,
  sabitliler üstte, satır tıkla → panoya koy + kapan + 200 ms sonra
  `xdotool key ctrl+v` (POPUP odak almadığından odak hedefte kaldı);
  xdotool yoksa yalnız panoya. xdotool ISO'ya girdi.
- `src/ui/osd.vala`: ses OSD'si — alt-orta hap; ikon + LevelBar +
  yüzde; 1.2 sn. XF86Audio{Raise,Lower}Volume/Mute → 0210 keybind →
  gdbus → PanelService.adjust → 120 ms sonra gerçek durumu okuyup
  volume_changed sinyali → OSD.
- **kavis-common/strings.vala**: metin tablosu kavis-panel'den buraya
  TAŞINDI (git mv; %75 benzerlik korunur) — kavis-panel VE kavis-tools
  AYNI tabloyu derler (birleşim tablo; kullanılmayan anahtar
  zararsız). prepare_sources iki pakete de appinit+strings kopyalar;
  .gitignore'da kopya yolları. `--metin-denetimi` iki ikilide de
  çalışır (şu an 88 anahtar, 0 hata).
- **packages/kavis-tools** (YENİ paket; 25 KB deb; tek ikili):
  - `tasks`: /proc'tan işlem listesi — CPU% (utime+stime deltası /
    /proc/stat jiffy deltası × çekirdek sayısı), RAM (VmRSS), disk
    (io read+write deltası; okunamayan '-'), arama filtresi,
    TreeModelSort CPU azalan, Sonlandır (SIGTERM; uid==0 →
    tm.critical_warning onayı).
  - `calc`: kendi shunting-yard çözümleyicisi (+ − × ÷ %, parantez,
    birli eksi, ×÷−, virgül→nokta). 12*(3+4)-5=79 doğrulandı.
  - `emoji`: 7 kategori sekmesi, FlowBox; seçim panoya + xdotool
    Ctrl+V; pencere açık kalır. Tam Unicode ad veritabanı (ARAMA)
    bilerek v1-dışı.
  - `.desktop` üçlüsü (tasks/calc/emoji; adlar tablodan TR+EN).
  - Bluetooth ayar arayüzü BİLEREK YOK: blueman Python yığınını geri
    getirirdi (madde 3 kararına aykırı); aç/kapa panelde, tam arayüz
    Grup F Ayarlar Bluetooth bölümü (metinleri tabloda zaten orada).

**Madde 29 (`14d6296`) — ekran görüntüsü/kaydı.**
- `packages/kavis-tools/src/capture.vala`:
  - `kavis-tools capture --quick` (Ctrl+PrtScr → 0210 "C-Print"):
    SORMADAN; mod ~/.config/kavis/capture.conf [capture]
    mode=window|monitor|all (vars. all; Ayarlar Grup F'de düzenler).
    Yakalama HARİCİ ARAÇSIZ: Gdk kök pencere pixbuf'ı (pencere modu
    wnck etkin pencere geometrisi; monitör modu işaretçinin
    monitörü). Kayıt yeri save_dir ya da vars. pictures/screenshots;
    ad %Y-%m-%d_%H-%M-%S.png. Panoya set_image + süreç 60 sn yaşar
    (X panosu sahibiyle ölür). Bildirim gdbus Notify ile (libnotify
    bağımlılığı yok).
  - `kavis-tools capture` (PrtScr): iki düğmeli menü — [📷 Görsel] →
    `flameshot gui --path <dizin>` (29F: donma/karartma/seçici/
    düzenleme flameshot'un işi); [🔴 Video] → slop bölge seçimi
    (turkuaz çerçeve) → ffmpeg x11grab (libx264 ultrafast, çift
    boyuta yuvarlanır, framerate conf'tan vars. 30) → sağ üstte
    hep-üstte RecorderBar (sayaç + Durdur); SIGINT ile düzgün kapanış
    (moov atomu) → bildirim. DURAKLAT v1-DIŞI (SIGSTOP zaman
    damgalarını bozuyor; metinler tabloda hazır).
- ISO listesine: flameshot, slop, ffmpeg.
- Doğrulama: mode=all ve mode=window yakalamaları (pencere modu
  yalnız etkin pencereyi tam kadraj aldı), menü görünümü.

**Kapanış (`59a8a13`)** — öz gözden geçirme 3 düzeltme (DnD NUL,
Idle rebuild, snap eski-boyut) + kavis-panel changelog 1.1→1.2
(ertelenmiş iş kapandı). Docs (`b3058e9`, skip ci).

**RAM ölçümü (kural: taze Xvfb, panel İLK GTK istemcisi):**
panel 1.2 RSS 34 MB / PSS 15 MB (D'nin tüm eklerine rağmen D öncesiyle
aynı); kavis-snap ikinci istemci RSS 20 MB (çoğu paylaşımlı GTK).

### 1f. Vala 0.56 sınırlamaları (bu oturumda ısıranlar — TEKRAR DÜŞME)

- `+=` ref/out DİZİ parametrelerinde YASAK ("Array concatenation not
  supported..."). Dolanma: yerel dizi kur sonra ata; ya da
  `resize(n-1); dizi[n-1] = deger;` (calc.vala reduce örneği).
- `Gtk.grab_add` Widget metodu DEĞİL, statik: `Gtk.grab_add (this)` /
  `Gtk.grab_remove (this)`.
- x11.vapi'de `Button1Mask` sabiti yok → `(mask & (1 << 8))` literal
  (yorumla).
- `Math.fmod` kullanınca `-X -lm` şart (linker: fmod undefined).
- Alan adı gölgeleme uyarıları: `label` (Gtk.Button.label), `margin`
  (Gtk.Widget.margin), `screen` (Gtk.Window.screen) — yeni ad ver
  (text_label, shadow_margin). Panel.screen ve PowerMenu.margin
  uyarıları bilerek bırakıldı (eski koddan).
- public metodun default değeri private sabite bakamaz ("default value
  is less accessible") → sabiti public yap.
- String literal içinde gerçek satır sonu YASAK — uzun mesajı tek
  satırda yaz.
- Döngü değişkenini closure'a verirken kopya al (`var chosen = plan;`).
- app_paintable(true) pencerede GTK pencerenin CSS arka planını
  ÇİZMEZ — arka plan sınıfını İÇ kutuya ver (PanelPopup/Overview
  deseni).
- namespace-düzeyi `private` = dosya-içi görünürlük; aynı dosyadaki
  başka sınıf erişebilir (capture.vala bunu kullanır).

### 1g. ISO içerik değişimi (boyut etkisi test5'te ölçülecek)

Bugün ISO listesine girenler: rfkill, xsct, brightnessctl,
libglib2.0-bin, nemo (masaüstü simgeleri; bağımlılıklarıyla),
xdotool, **fonts-noto-color-emoji** (~11 MB deb — emoji seçici
kutucukları kutu değil emoji çizsin), flameshot, slop, **ffmpeg**
(en büyüğü; bağımlılıklarla ~100 MB kurulu). v0.3-test4 ISO'su 645
MB'tı; test5 belirgin büyüyecek — 1.5 GB sınırına bak (CI zaten
denetliyor). Şişme sorun olursa ilk aday ffmpeg'i tembel kuruluma
almak (indirme yöneticisi madde 23 gelince).

## 2. SIRADA BEKLEYEN İŞLER (sırayla)

> **GÜNCELLEME (2 Eyl, öğleden sonra):** Aşağıdaki 1-5 kayıtları
> tarihli hâliyle duruyor; GERÇEK durum şu:
> - v0.3-test5 sonrası VM geri bildirim turu (6 madde) BİTTİ:
>   ab4c858 (hizalama+opaklık), 4583e5d (2a bildirim merkezi),
>   6deba0d (2b hızlı ayarlar), 7539fb2 (2c klavye popup),
>   e9ab382 (3 tepsi araçları), 1d701f4 (4 emoji arama),
>   0d08ff3 (5 donmuş kare yakalama), aca3c91 (6 splash boşluk).
> - Üç sıralı iş BİTTİ: boot-sound 0702dce, varsayılan dil EN
>   43e84ca, gettext geçişi 0967d46 (Strings + metin tablosu kalktı,
>   tek kaynak po/). Etiket v0.3-test6 → 0967d46 (push token
>   sorunundan bekçiyle gidiyor; main push'landı).
> - sonraki-isler.md 6 BÖLÜMÜN TAMAMI BİTTİ (2 Eyl öğleden sonra):
>   1 df7f548, 2 0f62132, 3 2d67189, 4 a96acc7, 5a-b b437008,
>   5c 37e77b6, 6a-6g dört commit + debug turu (menü sızıntısı,
>   tembel glif sayfaları; panel 37.2 MB RSS). sonraki-isler.md
>   silindi (kendi kuralı); kararlar bu dosyada.
> - test8 VM geri bildirimi (TAM LİSTE, 2 Eyl akşam) İŞLENDİ — sıra
>   I→H→B→C→D→A→G→E→J, alan başına commit; F yalnız roadmap Grup E
>   satırına not. Öne çıkanlar: Debian rc.xml bağ çakışmaları (çift
>   A-F4/Print/scrot, tekerlek masaüstü değiştirme) 0210 temizleme
>   geçidiyle; GRUB gfxmenu Kavis teması (ikonlu, seçili girdi turkuaz
>   kutu); splash fade'i tamamen kalktı + gfxpayload=keep; hızlı
>   ayarlar B4 görünümü + Battery plan alt paneli; 14px başlık
>   düğmeleri + cyan çerçeve kalktı; yakalamada Elips/pencere LİSTESİ/
>   ok imleci/tıklanabilir toast; dikey panel düzeni; picker sürükleme
>   + konum hatırlama; sudo pwfeedback + /home→/users + TR locale;
>   docs/tasarim-dili.md (12/10/8 köşe, 180/120ms, 16/8/12 boşluk).
>   Panel RSS 36.7 MB. KALAN: yeni etiket CI + VirtualBox el testi →
>   DUR, Grup E'ye GEÇİLMEZ.
> - Dil listesi + çeviri yüzdesi altyapısı BİTTİ (2 Eyl gece, tek
>   commit): po/LINGUAS (78 dil, bölge grupları; kullanıcı listesine
>   ca/gl/eu eklendi), tools/i18n-stats.sh →
>   /usr/share/kavis/i18n-stats.json (kavis-panel rules; msgmerge ile
>   pot kesişimi — yoksa tr %101 çıkıyordu), Grup F dil seçici
>   kuralları docs/referans/dil-secici.md, README "Çeviri durumu"
>   tablosu tools/gen-ceviri-tablosu.py + lint.yml adımı (yalnız
>   main push, [skip ci] commit). tr.po'daki 3 kullanılmayan girdi
>   temizlendi (commit 9fb045a). Etiket v0.3-test9 bu commit'e
>   taşındı (önce 4adeaf0'daydı; push edilmemişti — edildiyse
>   kullanıcının etiketi zorla itmesi gerekir). Push KULLANICIDA.
> - GRUP F 1. ADIM / 1A BİTTİ (3 Eyl): kavis-settings paketi 4
>   commit'te — 6256fed iskelet (W11 yerleşim, tembel sayfalar),
>   fae84fb kavis.conf tek dosya (panel.conf [panel]→[taskbar] içe
>   alma; canlı yayılım FileMonitor/inotify — D-Bus'a tercih sebebi:
>   herkes GLib bağlıyor, yazan için kimse ayakta olmak zorunda
>   değil), 9a3f03c 8 bölüm gerçek ayarlarla (xsettingsd + Kavis-Light
>   CANLI tema; xrandr 15 sn geri sayım; PowerPlan 4 mod
>   kavis-common'a; dil seçici dil-secici.md kurallarıyla), 350b989
>   arama + RSS + boot-check SETTINGS-OK. RSS yerel 35MB ama boş GTK
>   penceresi aynı ortamda 23.9MB — gerçek ölçüm ISO'da (SETTINGS-OK
>   satırı loglar). Kapak/uyku süreleri logind (root) istediğinden
>   ERTELENDİ (aşağıda ONAY BEKLEYEN). Sıra: 1B başlık düğmeleri.
> - GRUP E KOD TAMAM (2 Eyl gece, 8 ayrı commit + tarama):
>   ec443fe tarama, 6889fa4 nemo (39), 98ff539 önizleme (36),
>   3bb552d tilix/mousepad/kate (40), 9a79688 disk/USB+automount
>   (42), 066a3f5 yazıcı/tarayıcı (43), a1a7918 terminal
>   kolaylıkları (44), 57252dc USB güvenli kullanım (63),
>   a83b4aa onarım+lxpolkit (64). Etiket v0.3-test10 → a83b4aa.
>   GRUP SONU KURALI: DUR — CI + VirtualBox testi ve "devam"
>   onayı gelmeden Grup F'ye GEÇİLMEZ.

1. **v0.3-test5 SONUÇLANDI: 5/5 YEŞİL** (koşu 33616072408, tag
   `v0.3-test5` → `59a8a13`; oturum kapanmadan yetişti). Kanıtlar:
   RESULT=OK tüm profillerde; SPLASH-RETAIN-OK; SPLASH-HANDOFF
   3.5-4.8s (retain örtüyor, yalnız uyarı); **PANEL-RSS=4-9 MB**
   (panel 1.2 — daha da düştü); MEM-USED 334-442 MB (nemo-desktop
   vb. ile ~+40 MB, 1 GB hedefin çok altında); ISO yapıtı
   `kavis-iso` 776.869.820 bayt ≈ **741 MB**
   (**kavis-0.3-test5-amd64.iso**; 645→741, ffmpeg/nemo/emoji fontu —
   1.5 GB sınırına hâlâ bol pay). Kullanıcıya bildirildi; sıradaki
   bekleyiş VirtualBox el testi + "devam".
2. **v0.3-test3 hakkında**: bitti (4/5; tek kırmızı uefi-genis GRUB
   takılması, tek seferlik). BEKLENEN BİR ŞEY YOK; kayıt yukarıda.
   v0.3-test4 de bitti (5/5 yeşil).
3. **Grup D kalanları**: kod tamam (9 madde). Bekleyenler: (a) test5
   yeşili, (b) kullanıcının VirtualBox el testi — özellikle
   kavis-snap GERÇEK FARE ile (Xvfb+openbox XTEST sürüklemesini
   işletmedi, test windowmove taklidiyle yapıldı), açılış sırası
   (GRUB→splash→masaüstü), popup kuralları, Win+V/W-Tab/PrtScr.
   Grup kapanış onayı ("devam") gelmeden Grup E'ye GEÇME.
4. **/btw ile sıraya alınan üç iş** (kullanıcı istedi; Grup D onayı
   sonrası, E'den önce ya da kullanıcının dediği sıraya göre):
   a. **boot-sound.mp3 değişimi**: yeni ses dosyası; boot-check'e
      `-s` (dosya boş değil) kontrolü; MP3→WAV dönüşüm doğrulaması
      (derlemede üretilen WAV'ın süresi/örnek oranı denetlensin);
      eski ses dosyasına işaret eden referansların temizliği.
   b. **Varsayılan dil EN + klavye TR**: canlı oturumun locale'i
      İngilizce'ye, klavye TR kalacak — iso/auto/config bootappend
      (locales=, keyboard-layouts=) + Strings varsayılanının gözden
      geçirilmesi (şu an boş locale=TR sayılıyor — davranış EN
      varsayılana çevrilecekse Strings.select_language ve tablo
      varsayılanı birlikte değişmeli; ARAYÜZ METİNLERİ kuralı bozulmaz).
   c. **gettext .po geçişi** (tam kapsam): domain adı (kavis),
      .pot çıkarımı, tr.po + xx.po (sahte dil — eksik çeviri
      yakalamak için), debian/rules'a msgfmt adımı, Strings sınıfı
      KALKIYOR (yerine gettext), CI denetimleri (msgfmt --check,
      eksik anahtar taraması, --metin-denetimi'nin yeni karşılığı).
      NOT: Meson'a geçilmedi; karar AÇIK (aşağıda 3. bölüm).
5. **Grup E** (onaydan sonra): 39, 36, 40, 42, 43, 44, 63, 64 —
   başında madde 59 taraması (nemo.md zaten var, üstüne).

## 3. AÇIK KARARLAR VE KURALLAR (yeni oturum uymalı)

- **DÜZELTME (2 Eyl, devir sonrası — kullanıcı):** Tema planı İKİ
  tema — koyu varsayılan, açık ikinci seçenek; geçiş Ayarlar > Görünüm
  (Grup F). Aşağıdaki eski "Tek tema: yalnızca KOYU" kaydı GEÇERSİZ
  (işaretlendi). Kodda şimdilik yalnız koyu var; `gtk-light.css` +
  `acik-k-logo.svg` kaynak olarak hazır.
- **DÜZELTME (aynı gün):** Proje tanımı "kişisel dağıtım" DEĞİL —
  tek geliştiricili, açık kaynak olacak dağıtım. Ad Karan OS → Kavis
  tam da global paylaşım için değişti; r/linux'ta duyuruldu, çeviri/
  test/kod katkıcısı aranıyor; depo Vala taşıması bitince public.
- Kodda Türkçe identifier YOK (bayraklar/CLI yüzeyi hariç —
  `--metin-denetimi` bilinçli TR).
- logic/–ui/ ayrımı: sistem erişimi/iş mantığı src/logic/, widget
  kodu src/ui/ (kavis-tools'ta düz src/ ama sınıflar ayrı dosyada).
- Her madde AYRI commit; commit mesajı "neyi neden"; Co-Authored-By
  YOK; doc-only commit'e [skip ci]; **etiket HEP kod commit'ine**
  ([skip ci] commit'ine konan etiket koşu tetiklemez — yaşandı).
- En hafif çözüm kuralı; hazır araç varsa kur-ayarla; kod kopyalama
  yasak (yaklaşım öğren, sıfırdan yaz).
- RAM ölçüm kuralı: TAZE X sunucusunda İLK GTK istemcisi olarak ölç
  (ikinci istemci llvmpipe sayfalarına dokunmaz, düşük çıkar).
- Splash kuralı (BİLİNÇLİ KARAR, kullanıcı onaylı): retain — müzik
  bitince değil, X/masaüstü hazır olana kadar kalır; lightdm devralır
  (minimum-vt=1 + -background none); boot-check SPLASH-RETAIN +
  SPLASH-HANDOFF (quit→openbox, 3 sn; retain kanıtlıysa yalnız uyarı).
- Blur: xrender'da yok; madde 38 GPU tespitiyle değerlendirecek.
  Akrilik = rgba saydamlık.
- ~~**AÇIK KARAR — gettext derleme yolu**~~ KAPANDI (2 Eyl, kullanıcı
  kararı): Meson GETİRİLMEDİ; debian/rules içinde msgfmt adımı (en
  hafif çözüm). Uygulandı — po/ kökte, kavis.mo'yu kavis-panel taşır,
  kavis-tools ona bağımlı; denetim tools/check-i18n.sh.
- **Yerelleştirme kuralı**: UI'da sabit piksel genişliği verme (EN/TR
  metin uzunlukları farklı); yer darsa metin yerine ikon tercih et
  (araç ipucuyla). Mevcut kodda genişlik istekleri var (ör. StartMenu
  WIDTH/HEIGHT, OSD bar 180px, pano 380px) — bunlar pencere boyutu,
  metin kutusu değil; yeni metin taşıyan widget'larda kurala uy.
- Popup/pencere kapanma kuralı (madde 60): pencere alanı İÇİ her
  tıklama içeride; yalnız DIŞARISI kapatır; kök koordinat testi +
  Gtk.grab_add + yeniden denemeli seat grab deseni kullan.
- Kısayolların TEK yeri: rc.xml'deki "Kavis kisayollari" bloğu (0210
  hook'u); çalışan panele org.kavis.Panel üzerinden seslen.
- ~~Metin tablosunun TEK yeri: packages/kavis-common/strings.vala~~
  GEÇERSİZ (2 Eyl, gettext geçişi): Strings sınıfı ve
  kavis-arayuz-metinleri.md KALKTI; tek kaynak po/ + koddaki İngilizce
  msgid'ler. Yeni metin akışı CLAUDE.md'de (gen-pot → tr.po →
  gen-xx-po → check-i18n). Ortak kaynak deseni (prepare_sources +
  .gitignore) appinit ve po/ için sürüyor.

## 4. BİLİNEN SORUNLAR / TEKNİK BORÇ

docs/bilinen-sorunlar.md güncel (1: vmwgfx→madde 62 ÇÖZÜLDÜ-tanım;
2: CI QEMU ↔ VirtualBox kapsam boşluğu; 3: GDK_GL→madde 61 ÇÖZÜLDÜ;
4: Guest Additions↔Secure Boot kararı F/G; 5: picom use-damage CPU —
gerçek donanımda; 6: Xorg ~110 MB VM RSS; 7: actions/cache@v5;
8: Reddit RAM rakamı — Enes). Bu oturumda EKLENENLER (dosyaya da
işlendi): 9: kavis-snap XTEST/Xvfb sınırı — gerçek fare VM doğrulaması
bekliyor; 10: hızlı yakalamanın pano kopyası 60 sn süreç ömrüyle
sınırlı; 11: ISO boyut artışı (ffmpeg/nemo/emoji fontu) test5'te
ölçülecek, gerekirse ffmpeg tembel kuruluma; 12: emoji seçicide arama
yok (Unicode ad veritabanı gerek).

## 5. KALDIĞIM YER

- Kod tarafında yarım değişiklik yok; her şey commit'li (push token
  yenilenince bekçi gönderiyor).
- boot-sound.mp3 uyarısı KALKTI: yeni müzik 0702dce ile işlendi
  (boot-check -s + WAV süre/örnek oranı denetimleri dahil).
- v0.3-test5 5/5 yeşil çıktı ve kullanıcı VM turunu yaptı (geri
  bildirim maddeleri yukarıda, hepsi işlendi).

## 6. SAHİPSİZ ÇALIŞMA KURALLARI (kullanıcı yokken)

- Karar gerekirse SORMA: en hafif seçeneği uygula ve aşağıdaki
  "ONAY BEKLEYEN KARARLAR" listesine yaz.
- Bir şey kırılırsa 3 deneme; olmuyorsa atla ve "ATLANDI: <sebep>"
  diye kaydet, kuyruğa devam et.
- Bağlam ~200k'ya gelince durum.md'yi güncelle — ama DURMA
  (kullanıcı sözlü ekledi: "durma, ben sana dur derim"); "BAĞLAM
  DOLDU" notunu düş, çalışmaya devam et.
- İSTİSNA — GTK CSD kararı (sonraki-isler 3): Openbox themerc'in
  neyi verip vermediğini YAZ, CSD'ye kendi başına GEÇME; karar
  kullanıcının.
- Not: masaüstünü-göster şeridi (.edge) ZATEN VAR ve KALIYOR;
  sonraki-isler'deki "Masaüstünü göster köşe şeridi: YOK" satırı
  "zaten var, yenisi gerekmez" diye okunur.

### ONAY BEKLEYEN KARARLAR

- KARAR VERİLDİ (1B, 3 Eyl): başlık düğmeleri Openbox themerc'te
  KALIYOR (Seçenek A) — CSD demosu (46×32 W11 düğmeleri) gösterildi,
  kullanıcı A'yı seçti. Sınırlar tasarim-dili.md'ye işlendi; GTK CSD
  istisna kaydı kapandı.

- Karar (1A, madde 51): kapak kapatma / otomatik uyku süreleri
  logind (HandleLidSwitch, IdleAction) yani root yapılandırması
  ister; Ayarlar oturum düzeyinde kalsın diye ertelendi — Güç
  sayfasında ekran kapatma (DPMS) gerçek, uyku/kapak Grup F içinde
  ayrı işle (pkexec'li tek seferlik yazım) gelecek.
- Karar (1A, madde 38): "Sistemle uyumlu" tema şimdilik koyuya düşer
  — sistemde açık/koyu sinyali üreten bir kaynak (portal) yok.

- ATLANDI-kısmen (madde 36, ofis önizleme): doc/docx/odt/xls hızlı
  önizlemesi bilgi kartına düşüyor — güvenilir görsel çevrim ancak
  LibreOffice'le olur (ISO'da yok, "tam uygulama açılmaz" kuralına da
  aykırı); catdoc/odt2txt metin dökümü tablolarda çorba çıkarıyor.
  Ofis paketi kurulunca (mağaza) yeniden değerlendirilir. Kalan her
  tür (resim/gif/video/ses/pdf/metin/kod/arşiv) gerçek önizleme.

- Karar/sınırlar (madde 39, nemo): (a) kenar çubuğundaki "File
  System" satırı KOŞULSUZ kodda — gsettings'le gizlenemiyor, F notu
  "varsayılan kapalı" ancak nemo yamasıyla olur, yama yapılmadı
  (hızlı erişim zaten üstte); (b) Ctrl+tekerlek görünüm modları
  arasında (büyük→liste→ayrıntı) GEÇMİYOR — yalnız etkin görünümün 7
  zoom seviyesini gezer, mod geçişi de yama ister; (c) Ctrl+Z tek
  adım geri alır (nemo'nun undo yığını yok); (d) toplu yeniden
  adlandırma trixie'de bulky olmadığından gprename'e delege. Hepsi
  docs/referans/nemo.md'de gerekçeli.

- Karar (dil altyapısı): i18n-stats.json "kavis-common paketinde"
  istendi ama kavis-common bir .deb değil, paketlerin paylaştığı
  kaynak dizini — JSON, .mo dosyalarının sahibi olan kavis-panel'e
  kondu (/usr/share/kavis/i18n-stats.json). Ayrı paket açmaktan
  hafif; ayrı "kavis-common" .deb'i istenirse taşınır.
- Karar (test8 E3): /home → /users bağı chroot hook'uyla (0230);
  /home boş değilse bağ atlanır, içerik korunur. Kurulu sistemde de
  aynı hook mantığı Calamares'e taşınacak (Grup I notu).
- Karar (test8 G2): .desktop Actions fiil kalıbı EN 'Open %s', TR
  '%s aç' — Türkçe ek uyumu (Çöpü aç) genel kalıpla verilemiyor;
  daha iyi TR istenirse eyleme özel çeviri tablosu gerekir.
- Karar (test8 E2): locales=en_US,tr_TR birlikte üretiliyor — dil
  geçişi (Grup F) locale üretimi beklemeden çalışsın; kendi
  araçlarımızın kullanıcıya dönük terminal metinleri (usage) po'ya
  taşındı, günlük/warning satırları bilinçli olarak İngilizce-ASCII
  kaldı (journal logları çeviri yüzeyi değil).

- ATLANDI (6c, kısmen): nemo'nun KENDİ 'bilinmeyen tür' diyaloğu
  değiştirilemedi (nemo yaması gerekir); Kavis penceresi nemo sağ tık
  aksiyonu + `kavis-tools open-with` olarak var. Çift-tık varsayılanı
  'her zaman bununla aç' işaretlendikçe bizim pencereden yazılıyor.
- Karar (5, pin kipi): pinliyken arama kutusuna yazılamıyor — POPUP
  pencere odak alamaz; klavye grab'ı hedef uygulamayı aç bırakırdı.
  Tıklamalar çalışır. Gerekirse Grup F'de yeniden bakılır.

- ATLANDI (sonraki-isler 2, "Win+/ listesine ekle"): Win+/ kısayol
  listesi diye bir özellik depoda henüz YOK (0210'da bağ yok, panelde
  pencere yok) — eklenecek liste bulunamadı. Kısayol listesi özelliği
  istenirse ayrı iş olarak tanımlanmalı.
- Karar (sonraki-isler 2, IPC): D-Bus seçildi (socket değil) —
  org.kavis.Panel zaten var, ActivateSlot metodu eklendi; ayrı socket
  altyapısı kurmaktan hafif.
- Karar (sonraki-isler 2, çok pencereli yuva sağ tık): tek pencerede
  "Pencereyi kapat", birden çokta "Tüm pencereleri kapat" (W11
  davranışı; iki ayrı msgid).
- ATLANDI (sonraki-isler 4, tetik 2): büyüt düğmesinde 600ms hover —
  openbox başlık çubuğu hover olayını dışarı vermiyor, teknik olarak
  imkânsız ("mümkünse" şartlıydı); Win+Z tek tetik.
- Karar (sonraki-isler 4): yerleştirme kavis-snap daemon'una IPC
  yerine panel içinde Wnck set_geometry ile (aynı kesirler; daemon'a
  IPC eklemek hiçbir şey kazandırmadan altyapı isterdi).
- **GTK CSD KARARI BEKLİYOR (sonraki-isler 3):** themerc sonucu —
  ÇIKANLAR: ~32px koyu başlık (etkin #17222C / pasif #121C26),
  degrade kalktı, ikon solda + başlık sola hizalı, ince — ☐ ✕ xbm
  ikonları, düğme hover/pressed renkleri DÜĞME BAŞINA (kapat hover'ı
  W11 kırmızısı #C42B1C beyaz ikonla, pasifte de), pasif soluk →
  hover'da canlanma. ÇIKMAYANLAR: 120-150ms yumuşak geçiş (openbox
  animasyonsuz, renk anlık değişir), ~46px geniş düğme (kare kalır,
  aralarında 1-2px boşluk), tam yükseklik hover dolgusu. CSD'ye
  GEÇİLMEDİ; ekran görüntüleri Xvfb'de doğrulandı. Karar: bu kadarı
  yeter mi, yoksa CSD mi?
- Kullanıcıya söz verilenler: test5 sonucu + `kavis-0.3-test5-amd64.iso`
  adı bildirilecek; Grup D özeti verildi; VirtualBox testi + "devam"
  bekleniyor (grup kapısı).

---

## Grup D kod tamam: masaüstü deneyimi (maddeler 4, 5, 6, 7, 29, 37, 55, 61, 62)

2026-09-02, tek oturum; her madde ayrı commit, hepsi Xvfb'de ekran
görüntüsü/senaryo testiyle doğrulandı. Kayda değer kararlar:

- **61**: GDK_GL ortak başlangıcı 'paylaşılan kaynak dosya' olarak
  (packages/kavis-common, assets/logo kopyalama düzeniyle) — wrapper
  süreci ya da .so yerine; sonra metin tablosu da aynı düzene taşındı
  (kavis-panel + kavis-tools tek tabloyu derliyor).
- **4**: blur bilerek yok — Grup B'nin 'xrender'da blur çalışmaz'
  kararı geçerli; akrilik = rgba saydamlık, blur madde 38'de GPU ile.
  Başlat düğmesi W11 gibi yalnız logo (metin araç ipucunda).
- **5**: konum/boyut değişimi paneli /proc/self/exe ile yeniden
  başlatıyor — her widget'ı canlı döndürmek yerine (panel durumsuz).
- **37**: bildirim daemon'u panelin İÇİNDE (dunst kurulmadı) — madde
  59'daki dunst şikâyetleri tasarım kuralı oldu. Gece modu xsct
  (sct trixie'de yok). Oyun Modu kutucuğu şimdilik durum dosyası
  (~/.config/kavis/gamemode) — gerçek iş Grup H.
- **6**: openbox yamalanmadı (imzalı paket); kenara yapıştırma ayrı
  kavis-snap ikilisi — opensnap'in üç bilinen kusuru (unsnap yok,
  monitör önbelleği, tek monitör) baştan kapalı. Masaüstü simgeleri
  nemo-desktop (nemo zaten madde 39 kararı). XTEST sürüklemesi
  Xvfb+openbox'ta işlemiyor — test windowmove taklidiyle yapıldı,
  gerçek fare VM'de doğrulanacak.
- **55**: genel bakışta canlı küçük görüntü bilerek yok (XComposite
  mekanizması kozmetik kazanca değmez); ikon+başlık. Masaüstü geçiş
  animasyonu picom show/hide tetikleyicilerinden bedava.
- **7**: Bluetooth arayüzü bilerek yok — blueman Python yığınını geri
  getirirdi; Ayarlar'ın Bluetooth bölümü (Grup F) yapacak. Pano
  W-v tıkla-yapıştır xdotool ile (ISO'ya girdi).
- **29**: hızlı yakalama harici araçsız (Gdk kök pixbuf); etkileşimli
  düzenleyici flameshot (29F 'temel' kararı); video slop+ffmpeg,
  duraklat v1-dışı (SIGSTOP zaman damgalarını bozuyor).
- Kısayolların TEK yeri rc.xml'deki Kavis bloğu (0210 hook) +
  org.kavis.Panel DBus köprüsü — çalışan panele gdbus'la sesleniliyor.
- RAM (taze X, ilk istemci): panel 1.2 RSS 34 MB / PSS 15 MB — D'nin
  tüm eklerine rağmen değişmedi; kavis-snap RSS 20 MB (paylaşımlı).

---

## BİLİNÇLİ KARAR: splash artık müzik bitince değil, masaüstü gelene kadar kalıyor

v0.3-test2 ölçümü (2026-09-02, kullanıcı onayı): retain devriyle
birlikte bölüm 5'in "müzik bittikten hemen sonra kapan" kuralı fiilen
"X/masaüstü hazır olana kadar kal" oldu — müzik bitse de splash, lightdm
X'i ayağa kaldırıp oturumu başlatana kadar ekranda duruyor (TCG'de 60+
sn, gerçek donanımda birkaç sn). Bu KABUL edildi: siyah ekran/konsol
görmektense splash'in beklemesi doğru davranış.

İkinci parça: lightdm X'i `-background none` ile başlatıyor
(lightdm.conf.d/50-kavis-splash-devir.conf). Bu olmadan X başladığı
anda kök pencereyi siyaha boyuyor ve openbox ilk kareyi çizene kadar
(v0.3-test2'de ~4 sn, gerçek donanımda 1-2 sn) siyahlık kalıyordu;
`-background none` framebuffer'daki son splash karesini korur → GRUB →
splash → masaüstü, arada hiçbir şey yok.

Denetimin üç biçimi (ders): (1) mutlak |quit−X| farkı — yanlış, doğru
davranışı cezalandırdı (v0.3-test2 beş profilde bundan düştü);
(2) yönlü fark — X'in önce başlamasını affeder ama görsel boşluğu
ölçmez; (3) şimdiki: quit → openbox başlangıcı (masaüstünün ilk çizen
süreci) + lightdm.log'dan "retaining splash" kanıtı. Eşik 3 sn; retain
kanıtlıysa aşım yalnız uyarı (ekranı retain karesi örtüyor).

---

## Açılış deneyimi: konsol flaşlarının kök sebebi lightdm'deymiş

VirtualBox el testi (v0.3-test1, EFI+VMSVGA) GRUB→masaüstü arasında iki
kez siyah ekran + kırmızı vmwgfx satırları gösterdi. Üç iş (2026-09-02,
kullanıcı talimatı), üç ayrı commit:

**İş 1 — konsol sustu (0d54bfa):** `loglevel=3` KERN_ERR'i de saklıyor
(vmwgfx "unsupported hypervisor" satırları — zararsız, sürücü simpledrm'e
düşüyor; ayrıntı docs/referans/virtualbox.md). `vt.global_cursor_default=0`
imleci, `rd.udev.log_level=3` initramfs udevd'sini kısıyor. Günlükler
journald'de tam duruyor; CI tanısı seri konsoldan KAVIS-CHECK okuduğu
için etkilenmiyor (boot-check systemd üzerinden yazıyor, printk değil).
i915/amdgpu/nouveau initramfs modül listesine açıkça girdi.

**İş 2 — quit=0.0s gizemi (37579aa):** Debian lightdm.service
`Conflicts=plymouth-quit.service` taşıyor: plymouth-quit (ve bizim
--retain-splash drop-in'imiz) normal açılışta HİÇ çalışmıyor; splash'i
lightdm kapatıyor. Üstelik Plymouth VT1'de, lightdm varsayılanı
minimum-vt=7 olduğundan lightdm "not replacing it" deyip düz quit
çalıştırıyor ve X'i VT7'de açıyordu — ikinci siyah ekran + konsol buydu.
Çözüm: minimum-vt=1 (X splash'in VT'sinde başlar, lightdm kendi
`quit --retain-splash`'ini kullanır) + lightdm'e `After=kavis-boot-sound`
(müzik bekleme artık lightdm üstünde; plymouth-quit drop-in'i yalnız
güvenlik ağı) + `Conflicts=getty@tty1` (GDM'in aynı çözümü). boot-check
quit'i artık plymouth-quit-wait'in bitişinden ölçüyor ve yeni
SPLASH-HANDOFF satırı splash↔X arasını denetliyor (>5 sn = FAIL; eşik
TCG yavaşlığı payı, gerçek beklenti 1-2 sn). Ders: bir drop-in yazınca
onu ezen Conflicts var mı diye ana birime bakılmalı.

**İş 3 — GRUB geri sayımı (f7f1280):** live-build'in gri progress_bar
kutusu (İngilizce metinli) `id=__timeout__` etiketiyle değiştirildi —
GRUB'da bu id'yi taşıyan bileşen varsayılan kutuyu kapatır, `text`
içindeki %d kalan saniyeyle basılır. Metin önce tabloya eklendi
(boot.autoboot_countdown), renk #8B9BA8, yazı tipi Unifont (Türkçe
glifler menü girdilerinde zaten doğrulanmış).

Ayrıca: ileride sorun çıkaracak dört konu docs/bilinen-sorunlar.md'ye,
"yeniden kur — dosyalarımı koru" tasarımı (Grup I / Calamares)
docs/yeniden-kurulum-tasarimi.md'ye yazıldı; görev listesi madde 16'ya
işaret kondu.

---

## Grup C tamam: görev çubuğu aşamaları + "88 MB" gizemi çözüldü

Dört aşama (2026-09-01, kullanıcı talimatı): picom hayalet pencere
düzeltmesi (ayrı kayıt, aşağıda değil — commit 1ae8fba), panel
yerleşimi, pencere düğmesi görünümü, gösterge popup'ları.

**Yerleşim (Aşama 2):** sağ bölge (göstergeler+saat) artık ASLA
ezilmiyor. Kök sebep: her pencere düğmesi sabit 190 px isteyince
panelin en küçük genişliği ekranı aşıyordu. Pencere listesi
ScrolledWindow'a alındı (en küçük genişliği çöker), düğmeler kalan
alana eşit bölünüp daralıyor, sığmayınca kaydırma. 30 pencereyle
Xvfb'de doğrulandı (saat bölgesi denetimi: 447 parlak piksel).

**Görünüm (Aşama 3):** Windows 11 tarzı — yalnız ikon (başlık araç
ipucunda, name_changed ile güncel), etkin pencere ortalanmış 16x3
turkuaz çizgi (tam genişlik şerit değil; "açık renkli" için marka
vurgusu turkuaz seçildi — palet dışına çıkılmadı), 180 ms geçişler.
Düğme 48 px; 40 altında ikonlar 24→16 küçülür, sonra kaydırma.

**Popup'lar (Aşama 4):** PanelPopup ortak temeli (tek popup kuralı,
dışarı tıkla/Escape/tekrar tıkla kapanır; animasyon picom'dan bedava).
Takvim=Gtk.Calendar (hazır ay okları; ISO'da gün adları TR yerelinden).
Pil popup'ındaki güç planı seçimi ~/.config/kavis/power.conf'a yazılır,
powerprofilesctl VARSA anında uygulanır — ISO'da yok, tam yaptırım
madde 51'e (Grup F) bırakıldı; popup kendi daemon'unu büyütmesin diye.
Ses arkayüzü amixer/ALSA (PipeWire'lı-sız fark etmez, daemon bağlantısı
yok); alsa-utils panel Depends'ine eklendi. Gözden geçirmede bulunan
açık: başlat menüsü ile popup'lar birbirinden habersizdi — karşılıklı
kapatma eklendi.

**88 MB gizemi:** kullanıcı VM'de 88 MB ölçtü ve "hâlâ Python" diye
yorumladı. Python paneli 596c15b'den beri yok; gerçek suçlu GTK3'ün ilk
pencerede GLX yoklaması: GPU'suz ortamda Mesa llvmpipe → ~50 MB libLLVM
RSS'e biner. Önceki "33 MB" ölçümümüz İKİNCİ GTK istemcisi olduğu için
llvmpipe sayfalarına dokunmamıştı — VM'in gerçeği ilk istemcidir.
Çözüm: panel GL kullanmadığından main()'de GDK_GL=disable (override
edilebilir). Taze X sunucusunda ilk istemci: RSS 85.2→34.3 MB,
PSS 57.5→24.8 MB. boot-check artık PANEL-EXE + PANEL-RSS yazıyor;
sonraki koşular bunu ISO içinden kanıtlayacak. DERS: RAM ölçümü
"kaçıncı GTK istemcisisin"e duyarlı — hep taze sunucuda ilk istemci
ölçülmeli.

---

## v0.2-test3 YEŞİL: Grup B + C ISO'da doğrulandı

Üç test etiketi turu: test1 GRUB hook hatasını, test2 doğrulama
adımındaki yol hatasını yakaladı; test3 (koşu 33507673200) tamamen
yeşil. Beş QEMU profili de RESULT=OK:

- PANEL-OK (Vala panel ISO'da çalışıyor; masaüstü karesinde Başlat +
  TR göstergesi + saat görünüyor — x11-xkb-utils düzeltmesi işledi)
- USERS-OK ev=/users/karan + 6 klasör; SYSCTL-OK (4 değer);
  EARLYOOM-OK; PICOM-OK; SPLASH-OK, SPLASH-COUNT=1
- SOUND-DELAY 1.5–3.3 sn (yalnız dusuk/tek çekirdek profili 3.3 sn ile
  uyarı eşiğinde — kabul edilebilir)
- MEM-USED 298–388 MB (canlı overlay dahil) — 1 GB hedefinin çok altı
- Derleme süresi apt önbelleğiyle ~9 dk'ya indi (eski 25-40 dk)

Kalan pürüz: "acilis" ekran karesi splash aralığına denk gelmedi (tek
kare, zamanlama şansa kalıyordu) — qemu-smoke-test artık 3 kare alıyor
(acilis-1/2/3). Splash görsel onayı kullanıcının VirtualBox testinde.

---

## v0.2-test1 kırmızı: GRUB hook'ları yanlış dosyayı hedefliyordu

İlk test etiketi koşusu (33505209926) "Gelişmiş menü (F3) YOK" hatasıyla
düştü — doğrulama adımı tam görevini yaptı. Kök sebep: live-build'in
gerçek yerleşiminde menü GİRDİLERİ `grub.cfg` ve `loopback.cfg` içinde;
`config.cfg`'de yalnız ayarlar var. 9600/9601 hook'ları (ve benim sahte
test ağacım) config.cfg'yi hedefliyordu — bu yüzden 9600'ün girdi
yeniden adlandırması da ASLINDA HİÇ ÇALIŞMAMIŞTI ("marka girdisi
sayisi: 0" günlükte duruyordu; kozmetik hook sessizce geçiyordu).

İkinci bulgu: 9600, splash.png'yi "Debian kalıntısı" diye siliyordu ama
theme.cfg gfxmenu temasını "splash.png varsa" koşuluna bağlıyor — yani
hook, live-build'in görsel temasını istemeden kapatıp menüyü düz metne
düşürüyordu.

Düzeltme (iki hook yeniden yazıldı):
- Girdi adlandırma artık grub.cfg + loopback.cfg'de; "çekirdek sürümlü"
  girdi biçimi de kapsandı.
- splash.png SİLİNMİYOR, üzerine kavis grub-arkaplan.png yazılıyor —
  gfxmenu teması etkin kalıyor; live-theme/theme.txt başlığı ürün
  adına, renkleri palete çevriliyor (madde 30'un "çirkin metin menüsü
  olmasın" isteği asıl burada karşılanıyor).
- live-build'in İngilizce "Utilities..." alt menüsü kaldırılıp içeriği
  (fwsetup + ortam doğrulama) Türkçe olarak F3 menüsüne taşındı; yeni
  `boot.verify_media` satırı metin tablosuna eklendi.
- CI doğrulaması artık grub.cfg'yi de çıkarıp sözdizimi + markalı girdi
  sayısı + F3 varlığını orada denetliyor.
- Yerel sahte-ağaç testi gerçek live-build şablonlarından (sources.d.o)
  kuruldu ve zincir + tüm CI kontrolleri yerelde geçti.

Ders (durum.md'ye özellikle): kozmetik diye durdurmayan hook'lara CI
tarafında zorunlu doğrulama eşlik etmeli — 9600 aylardır sessizce boşa
çalışıyormuş, bunu ancak 9601'in zorunlu kontrolü açığa çıkardı.

---

## Otonom ISO tetikleme: test etiketleri (2026-09-01)

Codespace token'ı workflow_dispatch yapamıyor (403, bilinen kısıt) ama
etiket PUSH'u iş akışını tetikleyebiliyor. Çözüm: `v*-test*` biçimli
etiketler (örn. v0.2-test1) derleme + tam QEMU matrisini koşturuyor,
release işi bu etiketleri atlıyor (build-iso.yml'de `!contains(
github.ref_name, '-test')`) — Releases sayfası test koşularıyla
kirlenmeden ISO artifact olarak alınabiliyor. Gerçek sürüm etiketleri
(v1.0 gibi) eskisi gibi release üretiyor. İlk kullanım: v0.2-test1
(koşu 33505209926) — Grup B + C değişikliklerinin toplu doğrulaması.

---

## Grup C — panel Vala'ya taşındı (madde 3)

Madde 59 taraması: `docs/referans/grup-c-taramasi.md` (polybar
issue'larından: panel OPAK kalacak, XEmbed tepsisine hiç girilmeyecek,
olay tabanlı mimari korunacak).

### Neden Vala (C değil)

Vala GObject/GTK için C'ye derleniyor: çalışma zamanı maliyeti C ile
aynı (yorumlayıcı yok, GI yok), kod C'nin üçte biri. "İş 3 katına
çıkıyorsa" eşiğine takılmadan derlenmiş panel elde etmenin yolu bu —
performans kuralındaki denge cümlesinin kendisi.

### Ölçümler (aynı makinede, aynı Xvfb, 6 sn boşta)

| | Python (eski) | Vala (yeni) |
|---|---|---|
| RSS | 103 MB | 33 MB |
| PSS | 75 MB | 23 MB |

Kullanıcının VM ölçümü (117 MB) bu makinedeki 103'e denk düşüyor;
ISO'da GTK kütüphaneleri başka süreçlerle paylaşıldığı için gerçek ek
maliyet PSS'e daha yakın olacak. .deb 15 KB'den 29 KB'ye çıktı ama
ISO'dan tüm Python+PyGObject yığını çıktı (02-x11 listesinden python3,
python3-gi, python3-gi-cairo, gir1.2-gtk-3.0 silindi) — net kazanç hem
RAM hem ISO boyutu.

### Yapı

- İş mantığı `src/logic/` (strings, brand, apps, power), arayüz
  `src/ui/` (panel, start_menu, power_menu, indicators) — madde 3'ün
  ayrım şartı dosya düzeyinde.
- Kod tanımlayıcıları İNGİLİZCE (kullanıcının 2026-09-01 kuralı;
  CLAUDE.md ve gorev-listesi'ne işlendi). Eski shell scriptlerindeki
  Türkçe yerel değişkenler dokunuldukça çevrilecek — toplu yeniden
  adlandırma churn'ü bilerek yapılmadı.
- Strut artık doğrudan libX11 `XChangeProperty` — python3-xlib'in var
  olma sebebi PyGObject'in eksiğiydi. BUYUT=1 testiyle doğrulandı.
- `--metin-denetimi` kipi: ekransız metin tablosu denetimi; CI'daki
  Python import kontrolünün yerini aldı (yerelde birebir çalıştırıldı).

### Taşımada yakalanan eski hatalar

1. **setxkbmap bağımlılığı hiç yoktu**: ikili `x11-xkb-utils`
   paketinde; ne panelin Depends'inde ne ISO listesindeydi. Klavye
   göstergesi ISO'da sessizce "TR" varsayılanına düşüyordu. Yeni paket
   bağımlılığı bildiriyor.
2. **Logo SVG'si gdk-pixbuf SVG yükleyicisiz açılmıyor**: `librsvg2-common`
   ISO listesinde vardı ama panelin bağımlılığı değildi; shlibs dinamik
   yükleyiciyi göremez. Açık bağımlılık yapıldı.
3. Vala 0.56'da `partial` anahtar sözcük — strut dizisinin adı bu yüzden
   `strut_values` (aynı tuzağa düşecek sonraki kişi için not).

---

## Karar: userns Grup G'de açılacak, karşılığında beş koruma (2026-09-01)

Kullanıcı kararı: `kernel.unprivileged_userns_clone` şu an 0 (madde 8),
**Grup G'de 1 yapılacak.** Gerekçe: Flatpak/bubblewrap ve Steam
pressure-vessel ayrıcalıksız kullanıcı ad alanlarını kullanıyor; 0
kalırsa mağazanın Flatpak tarafı (madde 41) ve Oyun Modu (madde 13)
çalışmaz.

Karşılığında Grup G'de eklenecek korumalar:

1. **AppArmor** etkin, Debian'ın hazır profilleri açık; tarayıcı ve
   riskli uygulamalar profil altında.
2. **/tmp, /var/tmp, /dev/shm** noexec + nosuid + nodev ile bağlanacak.
3. **Flatpak'e varsayılan dar izinler**: mağaza kurulumda ev dizininin
   tamamını açmayacak, yalnız gerekli klasörler; Ayarlar'dan
   genişletilebilir.
4. **Tüm kavis-* systemd servisleri sertleştirilecek**:
   ProtectSystem=strict, ProtectHome=read-only (gerekmeyenlerde),
   PrivateTmp=yes, NoNewPrivileges=yes, RestrictSUIDSGID=yes,
   MemoryDenyWriteExecute=yes (uygunsa), CapabilityBoundingSet dar.
5. **unattended-upgrades yalnız güvenlik deposu için açık** — madde
   26'daki "kullanıcıya sormadan hiçbir şey kurulmaz" kuralının tek ve
   bilinçli istisnası; kullanıcı kapatabilir.

Bu not `docs/gorev-listesi.md`'de madde 8 ve Grup G kapsamına da
işlendi; sysctl dosyasındaki yorum karara işaret ediyor. Ayrıca modprobe
kara liste dosyası kullanıcı isteğiyle `kavis-blacklist.conf` adını aldı
(`blacklist algif_aead` zaten dört algif girdisiyle birlikte içindeydi).

---

## Grup B — picom, açılış ekranı + F3, /users/karan, sertleştirme, CI testleri

Madde 59 taraması önce yapıldı: `docs/referans/grup-b-taramasi.md`
(earlyoom `--avoid` zorunluluğu ve memtest86+/Secure Boot gerçeği
oradan geldi; picom kararları A2'deki `picom.md`'den).

### Madde 2 — picom

`picom-kavis.conf`: yuvarlak köşe (8px, panel/dock/tam ekran hariç) ve
v12 aç/kapa animasyonları (0.15 sn `appear`/`disappear`) eklendi —
ikisi de XRENDER'da çalışıyor (trixie picom 12.5, referans bulgusu),
QEMU testleri bozulmuyor. `unredir-if-possible` açıldı: tam ekran
pencere kompozitörü atlar (oyun moduna da hazırlık). Blur bilerek YOK —
glx + gerçek GPU ister; madde 38'de koşullu açılacak. Yerel picom 10
animasyon bloğunu tanımayıp uyarıyla geçiyor; panel ekran görüntüsü
bu yüzden animasyonsuz ama sorunsuz çizildi.

### Madde 30 — açılış ekranı ve F3

- Splash yeniden: sade zemin + koyu logo + ürün adı + imza + iki ipucu
  satırı. Ürün adı os-release NAME'den derlemede üretiliyor; Türkçe
  büyük harf (i→İ) Python'un upper()'ı bilmediği için translate ile.
  Yerleşim PIL simülasyonuyla gözle doğrulandı.
- Boşluk atlaması: boot-sound scripti `plymouth watch-keystroke
  --keys=" "` (komutsuz kullanımda tuşta çıkıyor; trixie plymouth
  kaynağından doğrulandı) ile dinliyor; basılınca aplay öldürülüp fade
  başlatılıyor.
- `/etc/kavis/boot.conf` (conffile): MUZIK_CAL / MUZIGI_BEKLE —
  Ayarlar'ın madde 38'de yöneteceği ilk ayar dosyası.
- F3: GRUB 2.12 `submenu --hotkey=f3` destekliyor (kaynaktan
  doğrulandı). 9601 hook'u güvenli modu alt menüye taşıyor, detaylı
  kayıt girdisini quiet/splash'sız üretiyor, memtest86+ girdilerini
  platforma göre yazıyor (BIOS linux16 / UEFI chainloader — EFI ikilisi
  imzasız olduğundan başlık "Secure Boot kapalıyken" diyor). VAR OLMAYAN
  özellik girdisi yok (A/B, snapshot, kurtarma sonraki gruplarda
  eklenecek). Girdi altına ayrı açıklama satırı GRUB'un standart
  menüsünde çizilemiyor; açıklama "ad — açıklama" olarak başlıkta.
  Üretilen config sahte ağaçta 9600+9601 zinciriyle test edildi ve
  `grub-script-check`'ten geçti; aynı kontrol CI'daki önyükleyici
  doğrulamasına da eklendi.
- boot-image.png artık kullanılmıyor (assets/'te duruyor); splash logosu
  koyu-k-logo.svg'den üretiliyor.

### Madde 0 — /users/karan

live-config bileşeni `0031-kavis-dizinler` (user-setup'tan hemen sonra):
evi `usermod -d -m` ile /users/karan'a taşıyor, 6 klasörü kuruyor,
`user-dirs.dirs` yazıyor. `/etc/xdg/user-dirs.conf enabled=False` —
yoksa ilk oturumda xdg-user-dirs-update klasör adlarını Türkçeleştirip
yolları değiştirirdi. GEÇİCİ NOT: kullanıcı sistemi ertelendi (madde 0);
kilit ekranı ve kullanıcı ekleme bilerek yok, madde 18'de gelecek.

### Madde 8 — sertleştirme

sysctl (userns_clone=0, kptr_restrict=2, dmesg_restrict=1,
ptrace_scope=1) + algif_* kara listesi + earlyoom (`--avoid` ile
oturum-kritik süreçler korumalı). AÇIK RİSK KAYDI: unprivileged_userns
kapatmak Flatpak/bubblewrap ve Steam pressure-vessel'ı kırar; madde
41/13 geldiğinde bu değer yeniden ele alınacak (setuid bwrap ya da
değerin açılması) — sysctl dosyasında da not var.

### Madde 46A — CI test altyapısı

Duman matrisi: 3 açılış kipi (varsayılan profil) + UEFI'de iki donanım
profili (dusuk: 2 GB/1 çekirdek; genis: 4 GB/4 çekirdek/virtio-vga) =
5 iş. Boşta RAM > 1 GB uyarı (canlı oturum RAM overlay'i yüzünden hata
değil — CLAUDE.md kuralı), ISO > 1536 MB artık HATA. Her koşu job
summary'ye KAVIS-CHECK tablosu yazıyor. boot-check'e yeni kontroller:
PICOM-OK, USERS-OK, SYSCTL-OK, EARLYOOM-OK + yeni splash dosyaları.

### Doğrulama durumu

Yerelde geçenler: check-config, check-packages (81 paket), shellcheck,
YAML, üç paketin derlemesi, CI içerik/içe aktarma denetimlerinin yerel
eşleri, GRUB hook zinciri + grub-script-check, splash yerleşim
simülasyonu, panel ekran görüntüsü. ISO + QEMU doğrulaması CI koşusu
gerektiriyor — Codespace token'ı tetikleyemediği için koşuyu kullanıcı
başlatacak.

---

## Çok-mimarili hazırlık + madde 59 (kullanıcı eki, 2026-09-01)

Kullanıcı iki kalıcı kural ekledi; ikisi de `docs/gorev-listesi.md`'ye
işlendi (MİMARİ ilkesi + madde 59) ve CLAUDE.md'ye özetlendi.

Mevcut kodda yapılan mimari temizliği:

- `iso/auto/config`: mimari `KAVIS_MIMARI` değişkeninden (varsayılan
  amd64); önyükleyici seçimi case ile — amd64'te grub-pc+grub-efi,
  arm64'te yalnız grub-efi (BIOS x86'ya özgü).
- `01-base.list.chroot`: çekirdek ve GRUB paketleri live-build'in
  `#if ARCHITECTURES` koşullarına alındı; arm64 karşılıkları yazıldı
  (denenmedi, ilk arm64 derlemesinde doğrulanacak).
- `tools/check-packages.sh`: hedef mimari `KAVIS_MIMARI`'den, indeks
  `binary-$MIMARI`, `#if ARCHITECTURES` blokları live-build gibi
  yorumlanıyor. İki mimari de yerelde doğrulandı: amd64 79/79,
  arm64 78/78 paket arşivde var (arm64 grub-pc-bin içermiyor).
- `build-iso.yml`: workflow düzeyinde `env: KAVIS_MIMARI: amd64` (tek
  satır değişiklik noktası); ISO adı, derleme bağımlılıkları ve duman
  testi kapısı bu değişkenden. Duman testi yalnız amd64'te koşuyor
  (qemu-system-x86 + OVMF); arm64 CI'a bilinçli olarak EKLENMEDİ (kota).
- `qemu-smoke-test.sh`: amd64 dışında sessizce atlıyor.
- Paketler zaten `Architecture: all` — değişiklik gerekmedi.

Not: x86'ya özgü ÖZELLİK kapıları (gameopt, Steam, memtest86+, NVIDIA)
henüz var olmayan bileşenlere ait; kuralları gorev-listesi'nde duruyor ve
ilgili maddeler yazılırken uygulanacak (ilk örnek: Grup B'de memtest86+
yalnız amd64 F3 menüsüne girecek).

---

## Grup A2 — referans incelemesi (madde 47)

Dokuz proje sığ klonlanıp incelendi, özetler `docs/referans/` altında
(dizin + kesişen bulgular: `docs/referans/README.md`), klonlar silindi.
İnceleme paralel alt ajanlarla yapıldı; issue taramaları `gh api` ile.
Kod kopyalanmadı.

Sonraki grupları etkileyen en önemli bulgular:

- **Grup B'yi doğrudan etkileyen:** trixie'nin picom 12.5'i yuvarlak köşe
  ve animasyonu XRENDER'da destekliyor (VM'de güvenli); blur glx + gerçek
  GPU şartına bağlanacak. Ayarlar entegrasyonu dosya + SIGUSR1.
- **Grup I'yı etkileyen:** Calamares'te `/users` subvolume'ü yapılandırmayla
  çıkıyor ama A/B kökü için özel Python modülü şart; btrfs swapfile ile
  hibernate'te `resume_offset` üretilmiyor — en az riskli yol swap BÖLÜMÜ
  (`suspend` seçeneği). Bu ikisi disk düzeni kararından önce okunacak.
- **Madde 26 varsayımı düzeltildi:** mintupdate güncelleme öncesi otomatik
  snapshot almıyor; otomatik btrfs snapshot bizim ek değerimiz olacak.
- **Madde 36'nın ucuz yolu:** Nemo boşluk tuşunda `org.nemo.Preview`
  D-Bus servisini çağırıyor, sağlayıcı trixie'de yok — o adı sahiplenen
  kendi önizleyicimiz Nemo'ya yama gerektirmiyor.
- **Trixie'de olmayanlar** (`docs/referans/README.md`'de tam liste):
  ubuntu-drivers-common, gamescope (yalnız backports/contrib), bulky,
  nemo-preview, scx. check-packages.sh ana arşive bakıyor; backports
  kullanılacaksa araca istisna gerekecek.
- **İlkeler:** polkit > sudoers NOPASSWD; her async işe zaman aşımı +
  hata sayfası ("sonsuz spinner" Mint'in bir numaralı şikâyeti); mod
  geçişlerinde masaüstüne güvenli dönüş garantisi (bazzite dersi).

---

## Grup A — Kavis markası, CI iyileştirmesi, logolar, yol haritası

Yeni çalışma düzeni: `docs/gorev-listesi.md` (58 madde, grup sırası).
Grup A'nın kararları:

### Marka değişikliği nasıl yapıldı

- `karanos` → `kavis` her yerde: paket adları, dizinler, systemd
  servisleri, Plymouth teması, hostname, ISO adı, `KARANOS_VERSION` →
  `KAVIS_VERSION`, `KARANOS-CHECK` → `KAVIS-CHECK`. GTK/simge/imleç
  teması `Karan` → `Kavis`, duvar kağıtları `karan-*` → `kavis-*`.
- DOKUNULMAYANLAR: sistem kullanıcısı `karan`, `made-by-karan.svg`
  ("made by Karan" kişi imzası), logo dosya adları, depo adı ve
  `KARANKOYU/karanos` adresleri, paket imzalarındaki "Karan" kişi adı.
- `docs/durum.md` geçmişi ve `docs/kavis-claude-code-prompt.md` (eski
  görev tanımı) kasten YENİDEN YAZILMADI — tarihsel kayıt. Eski prompt
  dosyasının başına "tarihsel" notu kondu.
- Kullanıcı CI'ı yeşile çevirmek için web'den `koyu-k-logo.svg`'yi
  `k-logo.svg`'ye çevirmişti (commit 48c0a80); ad kurala göre
  `koyu-k-logo.svg`'ye geri alındı, derleme iki yeni ada bağlandı.

### İsim bir daha sabitlenmesin (tek kaynak)

Tek kaynak `packages/kavis-theme/src/os-release` (kurulu sistemde
`/etc/os-release`). Okuyanlar: `iso/auto/config` (`. os-release` ile
NAME/ID/HOME_URL), iş akışının "Sürüm bilgisi" adımı (ISO adı ID'den),
`9600-grub-marka.hook.binary` (menü adları chroot'un os-release'inden),
`kavis_panel/marka.py` (panel/hakkında; tek fallback sabiti orada).
Adı denetleyen kontroller de ada değil "Debian kimliği kalmış mı"ya
bakıyor (`ID=debian` görürsek devralma başarısız).

### Madde 22 — CI

- ISO artık push'ta DERLENMİYOR; yalnızca elle (workflow_dispatch) ve
  `v*` etiketi. `build-packages.yml`'nin push tetikleyicisi de kalktı
  (paketler her ISO koşusunda zaten derlenip doğrulanıyor). Push'ta
  yalnızca lint koşuyor.
- apt önbelleği: `iso/cache` (live-build'in debootstrap + .deb
  önbelleği) `actions/cache` ile saklanıyor; anahtar paket listelerinin
  hash'i. Bunun için `lb clean --purge` → `lb clean` yapıldı: purge
  cache'i de siliyor ve geri getirilen önbelleği çöpe atıyordu.
- "Releases'e yükle" neden hiç çalışmadı: adım yalnızca etiket push'unda
  koşuyordu ve depoya bugüne dek HİÇ `v*` etiketi atılmamış; üstelik
  `draft: true` idi (etiket olsaydı bile sürüm taslakta kalacaktı).
  Düzeltme: taslak kapatıldı; elle koşuda "release" kutusu işaretlenirse
  pre-release olarak da yayınlanabiliyor.

### Madde 1 — logolar

- `koyu-k-logo.svg` + `acik-k-logo.svg` tema paketiyle
  `/usr/share/kavis/logo/` altına kuruluyor.
- Boot splash ve GRUB: her zaman koyu logo. GRUB arka planı artık duvar
  kağıdı değil; `gen-wallpapers.py --grub` koyu logoyu düz zeminde, üst
  üçte birlik bölgede çiziyor (menü metni ortada — çakışmasın diye).
- Başlat düğmesi: `marka.logo_resmi()` etkin temaya göre seçiyor
  (kodda şimdilik yalnız koyu tema olduğundan pratikte hep koyu logo;
  plan iki tema — 2 Eyl düzeltmesi, devir kaydı bölüm 3).

### Kod dili kararı

Görev listesi gereği fonksiyon açıklamaları artık İNGİLİZCE (ilk örnek
`marka.py`). Eski dosyaların Türkçe yorumları yeniden yazılmadı —
çeviri uğruna churn yaratmamak için; dokunulan yerlerde kademeli geçiş.

---

## Üçüncü VirtualBox testi — siyah boşluk

VBoxSVGA'ya geçince `vmwgfx` hatası ve splash sonrası konsol metni
kayboldu. Yani teşhis doğruydu: vmwgfx bağlanıp çalışmayınca KMS devre
dışı kalıyor ve Plymouth framebuffer'a düşüyordu.

Kalan sorun: splash kapandıktan sonra masaüstünden önce ~3 saniye siyah
ekran.

### `After=display-manager.service` neden ÇÖZÜM DEĞİL

İlk akla gelen, `plymouth-quit`'i giriş yöneticisinden sonraya almaktı.
Debian'ın `lightdm.service` dosyasını okuyunca bunun döngü yaratacağı
görüldü:

```
# replaces plymouth-quit since lightdm quits plymouth on its own
Conflicts=plymouth-quit.service
After=plymouth-quit.service
OnFailure=plymouth-quit.service
```

lightdm zaten `plymouth-quit`'ten SONRA başlıyor. Ona `After=lightdm`
eklemek karşılıklı bağımlılık olur; systemd döngüyü rastgele bir yerden
kırar ve sonuç öngörülemez hâle gelir. Bu yol kapalı.

### Gerçek sebep: retain-splash boş kareyi tutuyordu

`plymouth quit --retain-splash` ekranda **son kareyi** bırakıyor. Ses
servisi çıkmadan hemen önce splash'i sıfıra kadar söndürdüğü için o son
kare bomboştu — tutulan şey siyahlıktı.

Çözüm: fade artık sıfıra değil **%35'e** iniyor (`SONME_HEDEF`). Görsel
soluk da olsa ekranda kalıyor, X ayağa kalkana kadar geçen süre
"kararmış açılış ekranı" gibi görünüyor, siyah bir hiçlik gibi değil.

Bölüm 5'in istediği "yumuşakça söner" korunuyor, yalnızca dibe
vurmuyor. Kendi giriş ekranımız geldiğinde (5. aşama) devir teslimi biz
yöneteceğiz; o zaman tam sönmeye dönülebilir.

### DRM sürücüsü kapsaması

Farklı hipervizörlerde aynı sorunun çıkmaması için initramfs'te bulunan
sürücüler: `bochs`, `bochs_drm`, `qxl`, `virtio_gpu`, `vmwgfx`,
`vboxvideo`, `simpledrm`. Gerçek donanımınkiler (`i915`, `amdgpu`,
`nouveau`) initramfs-tools'un `most` listesinden zaten geliyor.

`0300-plymouth.hook.chroot` artık hangilerinin gerçekten girdiğini
tek tek yazıyor ve sanal makine sürücülerinden biri eksikse uyarıyor —
"o hipervizörde splash görünmeyebilir" bilgisi derleme günlüğünde
kalıyor.

---

## İkinci VirtualBox testi — kalan iki sorun

Müzik artık splash ekrandayken başlıyor (ilk düzeltme tuttu) ama iki şey
kaldı.

### Müzik görselin ortasında başlıyordu

Script ses aygıtını (`/dev/snd/pcmC*D*p`) bekliyor; VirtualBox'ta ses
modülü kök dosya sistemi bağlandıktan sonra yükleniyor, yani aygıt geç
geliyor. İki taraflı düzeltildi:
- Ses modülleri initramfs'e alındı (`snd_hda_intel`, `snd_intel8x0`,
  `snd_ac97_codec`, `virtio_snd`) — aygıt çok daha erken hazır.
- Yoklama saniyede birden 0,2 saniyede bire çıkarıldı; eskisi aygıt
  hazır olduktan sonra ortalama yarım saniye daha bekletiyordu.

Ölçüm eklendi: `SOUND-DELAY` satırı müziğin splash'ten kaç saniye sonra
başladığını yazıyor, 3 saniyeyi geçerse uyarıyor. Ses servisinin kendi
günlüğü de (`BOOTSOUND-LOG`) aygıtı kaç saniye beklediğini bildiriyor —
gecikmenin kaynağı "servis geç başladı" mı "aygıt geç geldi" mi, ayırt
edilebiliyor.

### Splash → konsol → masaüstü sırası

Sıralama artık doğru çalışıyordu (müzik splash'i tutuyordu) ama düz
`plymouth quit` splash'i kapatıp sanal terminali bırakıyor; altında duran
çekirdek/systemd metni ortaya çıkıyor ve X başlayana kadar ekranda
kalıyor. Görülen konsol ekranı bu boşluk.

Çözüm `plymouth-quit.service` için `ExecStart=-/usr/bin/plymouth quit
--retain-splash`. Son kare framebuffer'da kalıyor, konsol metni yeniden
çizilmiyor, X doğrudan üstüne açılıyor.

**Tuzak:** drop-in aynı dosyadan hem `plymouth-quit.service.d/` hem
`plymouth-quit-wait.service.d/` altına kuruluyordu. `ExecStart`
değişikliği ikincisine de uygulanınca onun `plymouth --wait` komutunu
ezerdi. İki ayrı dosyaya bölündü; sıralama ikisinde de, ExecStart
yalnızca quit'te.

### VirtualBox vmwgfx hatası

VMSVGA denetleyicisiyle `vmwgfx` bağlanıyor ama çalışmıyor
("unsupported hypervisor"). KMS devre dışı kalırsa Plymouth metin
kipine düşer. `simpledrm` initramfs'te olduğu için UEFI framebuffer
üstünde yine bir DRM aygıtı kalıyor. `boot-check` artık her açılışta
`DRM-DEVICES` ve `SPLASH-RENDERER` satırlarını yazıyor, böylece hangi
çizicinin seçildiği kayda giriyor. VirtualBox tarafında Grafik
Denetleyici'yi `VBoxSVGA` yapmak hatayı tamamen kaldırıyor
(`vboxvideo` initramfs'te var).

---

## VirtualBox testi — açılış akışı bozuktu

Gerçek makinede (UEFI, ses etkin) görülen sıra: splash geldi (sessiz) →
söndü, konsol göründü → müzik ANCAK O ZAMAN başladı → splash ikinci kez
geldi → masaüstüne geçildi ama müzik çalmaya devam etti.

QEMU bunu yakalayamadı: ses arka ucu `none`, zamanlama farklı.

**Kök sebep: `After=sound.target`.** Servis, udev ses kartını bulup
`sound.target`'a ulaşılana kadar bekliyordu. Gerçek donanımda bu nokta
açılışın çok ilerisinde; servis splash'i tutamayacak kadar geç
başlıyordu. `plymouth-quit` çoktan koşmuş, splash sönmüş, konsol
görünmüş oluyordu.

**İkinci sebep: drop-in'deki `Wants=`.** `plymouth-quit.service` ses
servisini `Wants=` ile de çekiyordu. Servis erken başlayamayınca
plymouth-quit onu O ANDA başlatıyordu — müziğin splash'in sonunda
başlayıp masaüstüne taşmasının açıklaması bu.

Yapılanlar:

- Servis artık `After=systemd-udev-trigger.service plymouth-start.service`
  ile **erken** başlıyor; `Before=plymouth-quit.service
  plymouth-quit-wait.service` sıralaması unit'in kendisinde de yazılı
  (yalnızca drop-in'e güvenmiyoruz).
- **Ses aygıtını script bekliyor**, systemd değil: `/dev/snd/pcmC*D*p`
  belirene kadar en fazla 8 saniye. Başlama anı öngörülebilir oldu.
- Drop-in'den `Wants=` kaldırıldı. Ses servisi hiç başlamazsa `After=`
  etkisiz kalıyor ve splash normal zamanında kapanıyor: müziksiz ama
  düzgün açılış. Müziğin masaüstüne taşmasından iyi bir hata biçimi.

**Sıralama doğrulaması eklendi** (istenen kontrol): `boot-check` artık
systemd'nin monotonik zaman damgalarını okuyup
`plymouth-start ≤ ses başlangıcı ≤ ses bitişi ≤ plymouth-quit`
sırasını denetliyor, `SPLASH-TIMING` satırıyla dört değeri de yazıyor ve
`journalctl -b -u plymouth-start.service` üzerinden splash'in **kaç kez**
başlatıldığını sayıyor (`SPLASH-COUNT`). Birden fazlaysa arada konsola
düşülmüş demektir. Sıra bozuksa `RESULT=FAIL` ve ilgili unit'lerin
journal dökümü seri konsola yazılıyor.

### GRUB menüsü Karan OS markasına çevrildi

`9600-grub-marka.hook.binary`: menü girdisi adları ("Live system
(amd64)" → "Karan OS (amd64)"), turkuaz vurgulu renkler ve arka plan
olarak `karan-gece.png`. Debian logosu/arka planı kalıntıları siliniyor.

Bu hook **derlemeyi durdurmuyor** — 9500 (timeout) durduruyor çünkü o
olmadan ISO hiç açılmıyor; marka ise kozmetik. Bir dosya beklenen yerde
değilse uyarı yazıp devam ediyor ve ne bulduğunu günlüğe döküyor, ki
live-build yapısı değişirse bir sonraki koşuda görelim.

### Güç menüsü ve kompozitör

Başlat menüsündeki dört güç ikonu yan yana diziliydi ve hangisinin ne
olduğu ancak ipucu metniyle anlaşılıyordu. Yerine tek "Güç" düğmesi ve
üstünde açılan popup kondu: Kilitle, Uyku, Kapat, Yeniden başlat —
solda ikon, sağında metin, üzerine gelince satır vurgulanıyor.

**picom eklendi.** Yuvarlatılmış köşe ve gölge ancak bileşikleme varken
çiziliyor; kompozitörsüz Xvfb testinde kutunun etrafında **siyah bir
çerçeve** çıktı (şeffaf pay siyah çiziliyor). İki taraflı çözüldü:
picom autostart'tan başlıyor (`xrender` arka ucu — 3B gerektirmiyor,
RAM'i az) ve panel `Gdk.Screen.is_composited()` ile bileşikleme yoksa
kutuyu düz dikdörtgen çiziyor. Siyah çerçeve hiçbir durumda görünmüyor.

LibreOffice şartnamedeki setup program listesinde zaten var (bölüm 7 ve
bölüm 11 kategori listesi) — ek iş gerekmedi.

---

## Koşu #7 — masaüstü geldi, iki sorun kaldı

**Tuttu:** `USER-OK karan`, `WM-OK openbox calisiyor (10 saniyede)`,
`OSRELEASE-OK Karan OS 1.0`, `SPLASH-OK`, `BOOTSOUND-SERVICE=active`.
`screen-*-son.png` gerçek masaüstünü gösteriyor: duvar kağıdı ve turkuaz
vurgulu tema imleci. `user-setup` ve `os-release` düzeltmeleri doğrulandı.

### Sorun 1: Plymouth splash hiç çizilmiyordu

Ekranda açılış görseli yerine systemd yazıları akıyordu. `plymouth-start`
başlamıştı, `splash` çekirdek satırındaydı (`karanos-boot-sound.service`
`ConditionKernelCommandLine=splash` ile **active** oldu, yani kanıtlı).

İki sebep birleşiyor:

1. **`console=ttyS0` yüzünden Plymouth seri konsolu birincil sayıyor** ve
   grafik splash'i hiç çizmiyor. Seri konsolu bırakamayız — duman
   testinin tek çıktı kanalı o. Çözüm çekirdek satırına
   `plymouth.ignore-serial-consoles` eklemek.
2. **Splash DRM (KMS) aygıtına çiziliyor**; ekran sürücüsü initramfs'te
   yoksa Plymouth metin kipine düşüyor. initramfs-tools'un `most` listesi
   depolama sürücülerini alıyor, ekran sürücülerini garanti etmiyor.
   `/etc/initramfs-tools/modules` eklendi (bochs, qxl, virtio_gpu,
   vmwgfx, vboxvideo, simpledrm — sanal makine ekran kartları; gerçek
   donanımınkiler `most` içinde zaten var).

`0300-plymouth.hook.chroot` artık initramfs'te en az bir DRM sürücüsü
olduğunu da doğruluyor; yoksa derleme duruyor. Aynı disiplin: sessizce
bozuk bir ISO üretmektense derlemeyi durdur.

### Sorun 2: panel ISO'da başlamıyordu

Panelin çıktısı hiçbir yere yazılmıyordu; duman testi yalnızca
"çalışmıyor" diyebiliyordu. Üç şey yapıldı:

1. **En olası sebep zamanlama.** `boot-check` openbox'ı 60 saniye
   bekliyor ama paneli anında kontrol ediyordu. Panel Python + GTK
   yüklüyor, öykünmeli QEMU'da bu saniyeler sürüyor. Artık 45 saniye
   bekleniyor. (Pencere yöneticisinde daha önce düzeltilen hatanın
   aynısı — aynı hatayı ikinci kez yaptım.)
2. **Görünürlük.** Openbox autostart paneli günlüğe yazıyor ve üç kez
   deniyor; `boot-check` panel yoksa günlüğü, `dpkg-query` durumunu ve
   `import karanos_panel.panel` çıktısını seri konsola döküyor.
3. **Derleme anında içe aktarma denetimi.** `build-packages.yml` artık
   paketi açıp bütün modülleri içe aktarıyor ve metin tablosunun
   tutarlılığını kontrol ediyor. Bir sözdizimi hatası ya da eksik `gi`
   modülü artık 40 dakikalık ISO koşusunu değil, 10 saniyeyi harcıyor.
   Bu denetim yerelde çalıştırıldı: modüller temiz yükleniyor, yani
   çöküş bir içe aktarma hatası **değil** — zamanlama hipotezini
   güçlendiriyor.

---

## Tek tema kararı: yalnızca KOYU → GERİ ALINDI (2 Eyl 2026)

(2 Eyl 2026: plan yeniden İKİ tema — koyu varsayılan, açık ikinci
seçenek, geçiş Ayarlar > Görünüm / Grup F. Kayıt tarihçe için duruyor;
uygulama ayrıntıları bugün hâlâ doğru: kodda yalnız koyu kurulu,
gtk-light.css kaynak olarak bekliyor.)

Açık tema kaldırıldı — ne varsayılan olarak ne seçenek olarak. Sebep:
kimliğe uymuyor.

Nasıl uygulandı:
- `debian/rules` **aynı koyu dosyayı hem `gtk.css` hem `gtk-dark.css`
  olarak** kuruyor. Böylece `gtk-application-prefer-dark-theme`
  kapatılsa ya da bir uygulama açık temayı zorlasa bile görünüm
  değişmiyor. Tek bir ayara güvenmek yerine iki yoldan da kapatmak,
  "bir yerden açık tema sızdı" hatasını imkânsız kılıyor.
- `src/gtk-3.0/gtk.css` → `gtk-light.css` olarak yeniden adlandırıldı ve
  **pakete girmiyor**. Dosya silinmedi; ileride istenirse paletin açık
  karşılığı hazır dursun diye kaynak olarak saklanıyor.
- `appearance.theme` / `theme_light` / `theme_dark` anahtarları
  arayüz metinleri tablosunda üstü çizili işaretlendi. Satırları silmek
  yerine kayıt olarak bırakmak, ileride birinin "bu metinler nerede
  kaldı" sorusunu cevaplıyor.
- Ekran görüntüsü script'lerindeki `VARYANT=acik` seçeneği kaldırıldı.
- `tools/ornek-pencere.py` içindeki "Tema: Açık/Koyu" açılır listesi
  duvar kağıdı seçicisiyle değiştirildi — artık var olmayan bir ayarı
  gösteriyordu ve ekran görüntüsünde "sistem açık temada" izlenimi
  veriyordu.

**Bundan sonraki aşamalarda açık tema için ek iş yapılmaz.**
*(2 Eyl 2026: bu kural geçersiz — üstteki geri alma notuna bak.)*

---

## Aşama 4 — karanos-panel (görev çubuğu + başlat menüsü)

Kapsam bölüm 17'nin 4. maddesi: **görev çubuğu ve başlat menüsü**.
Bölüm 8'deki masaüstü simgeleri, snap (Win+ok), Alt+Tab önizlemeleri ve
kısayol tuşları bu commit'te YOK — ayrı bir adımda yapılacak, durum.md
güncellenecek.

**Karar: pencere listesi için libwnck.** Openbox EWMH konuşuyor;
pencere listesini, sanal masaüstlerini ve "masaüstünü göster"i elle X
protokolüyle yazmak yerine libwnck kullanıyoruz. Zaten Debian'da ve
GTK3 ile aynı olay döngüsünde çalışıyor.

**Karar: uygulama listesi Gio.AppInfo'dan.** Kendi .desktop
ayrıştırıcımızı yazmıyoruz — Gio, NoDisplay/OnlyShowIn/TryExec ve dil
kurallarını zaten doğru uyguluyor.

**Karar: güç eylemleri logind üzerinden, sudo'suz.** logind, yerel
oturum sahibine kapatma/yeniden başlatma iznini polkit üzerinden zaten
veriyor. Böylece parola sorulmuyor ve panelin root yetkisi gerekmiyor.

**Karar: `_NET_WM_STRUT_PARTIAL` xprop ile yazılıyor.** Doğal yolu
`Gdk.property_change` olurdu ama PyGObject onu dışarı vermiyor
(introspection'da `skip`), çağırınca `AttributeError` geliyor. Kalan
seçenekler `python3-xlib` bağımlılığı eklemek ya da x11-utils'ten gelen
`xprop`u çağırmak; xprop zaten ISO'da olduğu için o seçildi. Bu özellik
olmazsa büyütülen pencereler panelin üstünü kaplıyor.

**Karar: dil seçimi tek yerde.** `metinler.py` hem tablo metinlerini
hem `turkce()` bayrağını veriyor; XDG kategori adları da onu kullanıyor.
İlk sürümde kategoriler her zaman Türkçe, düğmeler yerele göreydi —
ekran görüntüsünde "Start" ile "Geliştirme" yan yana çıkınca fark edildi.

**Karar: sistem tepsisi bu aşamada yok.** Bölüm 8 ağ/ses/pil simgelerini
tepside istiyor ama XEmbed/StatusNotifier tepsisi kendi başına bir iş.
Panelin sağ ucundaki göstergeler (klavye dili, pil, saat) doğrudan
sistemden okunuyor; gerçek tepsi 10. aşamadaki karanos-tools ile
gelecek.

**Geçici tema önizlemesi kaldırıldı.** 2. ve 3. aşamada ISO'ya giren
`/usr/lib/karanos/theme-preview` panel geldiği için silindi;
`tools/ornek-pencere.py` olarak geliştirme araçlarının arasına taşındı
(ekran görüntüsü script'leri onu açıyor).

**Doğrulama:** `tools/panel-screenshot.sh` paneli Xvfb + Openbox'ta
çalıştırıp PNG veriyor, `MENU=1` ile başlat menüsü açık hâlde. Bu turda
üç hatayı ISO derlemeden yakaladı: CSS bloğu Türkçe yorum içerdiği için
`bytes` literal olamıyordu, `Gdk.property_change` yoktu, dil seçimi iki
yerde ayrıydı. `boot-check` de artık `PANEL-OK` arıyor — panel
çalışmazsa duman testi düşüyor.

---

## Çalışma biçimi — CI tetiklenmiyor (AÇIK SORUN)

**Belirti:** `45431df` ve `c28a15e` push edildi, GitHub hiçbir iş akışı
koşusu üretmedi. Depo public, üç iş akışı da `active`, `paths` filtreleri
tutuyor. Toplam koşu sayısı `d143bb4`'te kaldı.

**Sebep (büyük olasılıkla):** Bu Codespace oturumunun `GITHUB_TOKEN`'ı
kısıtlı bir kurulum token'ı (`ghu_…`). `gh workflow run` denemesi
`403 Resource not accessible by integration` döndü; `actions/permissions`
uç noktası da 403. GitHub, kurulum token'ıyla yapılan push'lardan iş
akışı tetiklemiyor (özyinelemeli koşuları önlemek için). Daha önceki
push'lar tetikliyordu, yani token kapsamı oturumlar arasında değişmiş.

**Ne yapılmalı:** Actions sekmesinden **Run workflow** ile elle
başlatmak gerekiyor. Bu Codespace'ten tetiklenemiyor — kullanıcının
yapması lazım.

**Sonuç:** 2. ve 3. aşamaların CI doğrulaması **yapılamadı**. Elde
şunlar var:
- `karanos-theme` yerelde derlendi ve Xvfb'de çizildi (koyu ve açık
  varyant), görsel olarak doğrulandı
- `karanos-boot` yerelde derlendi, paket içeriği ve WAV süresi
  (6,14 sn) doğrulandı; splash'in kendisi yalnızca gerçek açılışta
  görülebiliyor
- `user-setup` düzeltmesi ve `os-release` hook'u **hiç çalıştırılmadı**

### Push tetikleyicileri daraltıldı

Codespace beklenmedik anda kapanabildiği için sık commit ediyoruz, ama
her commit 40 dakikalık derlemeyi hak etmiyor. `build-iso.yml` artık
yalnızca `iso/**`, `packages/**`, `assets/**` ve kendi dosyası
değişince koşuyor.

**Bunun bedeli:** `tools/qemu-smoke-test.sh` ya da
`tools/build-packages.sh` değiştiğinde derleme kendiliğinden koşmuyor.
O değişiklikleri denemek için Actions sekmesinden elle başlatmak
gerekiyor. Lint her push'ta koşmaya devam ediyor (20 saniye).
Belge/not commit'lerinin mesajına `[skip ci]` ekleniyor.

---

## Aşama 3 — karanos-boot (açılış ekranı)

**Karar: italik yazı PNG olarak gömüldü.** Bölüm 5'in notu iki seçenek
sunuyordu: hazır PNG ya da kendi framebuffer programımız. Plymouth
bitmap font kullanıyor ve italik gösteremiyor; kendi programımızı yazmak
Plymouth'u ikinci kez yazmak olurdu. `src/made-by-karan.svg` paket
derlenirken `rsvg-convert` ile PNG'ye çevriliyor — açılışta yazı tipi
bağımlılığı yok, sonuç her makinede birebir aynı.

**Karar: müzik WAV olarak gömülüyor, mp3 olarak değil.** Bölüm 5 "görsel
ve ses birlikte yumuşakça söner" diyor ama mp3 çalarların çoğunda
fade-out yok. `ffmpeg` paket derlenirken mp3'ü çözüp sonuna 0,4 saniyelik
fade ekliyor; açılışta `aplay` yetiyor, mp3 çözücü gerekmiyor. Bedeli
~1 MB ISO alanı (99 KB mp3 → 1,08 MB WAV); 1,5 GB hedefinde sorun değil.

**Karar: splash'i tutan mekanizma systemd sıralaması.**
`karanos-boot-sound.service` `Type=oneshot`; müzik bitene kadar
"başlıyor" sayılıyor. `plymouth-quit.service` ve
`plymouth-quit-wait.service` için konan drop-in'ler onu bekliyor. Böylece
sistem daha erken hazır olsa bile splash müzik bitene kadar duruyor —
bölüm 5 madde 4'ün istediği bu. Ses servisi başarısız olsa da sonlandığı
için açılış kilitlenmiyor; script kendi içinde 10 saniyede kesiyor
(madde 5'teki güvenlik ağı), servisin `TimeoutStartSec=20` değeri de
onun üstünde ikinci bir ağ.

**Karar: fade-out'u ses servisi tetikliyor.** Plymouth script'i müziğin
ne zaman bittiğini bilemez. Servis müzik bitince
`plymouth update --status=karanos-sonlaniyor` çağırıyor, tema script'i
bu durumu görünce sönmeyi başlatıyor. Görsel ile sesin birlikte sönmesi
böyle sağlanıyor.

**Karar: initramfs ayrı hook'ta üretiliyor.**
`plymouth-set-default-theme -R` tek adımda yapardı ama her paket
kurulumunda initramfs üretmek live-build chroot'unda derlemeye dakikalar
ekliyor. `postinst` yalnızca temayı seçiyor,
`0300-plymouth.hook.chroot` initramfs'i bir kez üretiyor **ve temanın
gerçekten içine girdiğini `lsinitramfs` ile doğruluyor**. Girmezse
derleme duruyor: aksi hâlde açılışta siyah ekran görünür ve sebebi ISO
açılmadan anlaşılmaz.

**Karar: görsel tek kopya.** Aslı tema dizininde, bölüm 5'in istediği
`/usr/share/karanos/boot/boot-image.png` ona giden bir bağ. Tersi
olsaydı tema dizini initramfs'e kopyalanırken bağ kırılırdı. 432 KB
tasarruf.

**Yan etki: `quiet splash` seri günlüğü kısıyor.** Duman testi
çekirdeğin başladığını "Linux version" satırından anlıyordu; `quiet` ile
o satır görünmüyor. Test artık daha geniş bir desene bakıyor
(`systemd[1]`, `Reached target`, `KARANOS-CHECK`). Bu tespit yalnızca
"önyükleyicide mi takıldık" sorusunu ayırmak için kullanılıyor.

**Splash nasıl görülüyor:** `plymouth-x11` Debian trixie'de yok, yani
açılış ekranı yerelde çizdirilemiyor. Duman testi çekirdek başladıktan
10 saniye sonra ayrı bir kare alıyor: `screen-<mod>-acilis.png`.
QEMU'ya ses kartı da eklendi (`intel-hda`, backend `none`) — ses hiçbir
yere gitmiyor ama `aplay` gerçek zamanda çalışıyor, böylece splash'in
müzik boyunca açık kalması da test ediliyor.

---

## Aşama 2 sonrası — renk kimliği değişimi ve iki gerçek hata

### Renk kimliği turuncu/sarıdan koyu turkuaz-maviye geçti

Yeni palet `CLAUDE.md` ve `docs/karanos-claude-code-prompt.md` bölüm 4'te.
Tek kaynak `packages/karanos-theme/`: CSS'lerdeki `@define-color` blokları
ve `tools/gen-*.py` başındaki sabitler.

**Karar: varsayılan tema koyu, açık tema ikinci seçenek.**
GTK'da bu, tema dizininde iki dosya tutmak demek — `gtk-dark.css` (koyu)
ve `gtk.css` (açık). Hangisinin yükleneceğini
`gtk-application-prefer-dark-theme` belirliyor ve
`/etc/gtk-3.0/settings.ini` içinde açık geliyor. Ayrı iki tema
(`Karan` / `Karan-Light`) yapmadım: tek tema + bir mantıksal anahtar,
8. aşamadaki "Tema: Açık / Koyu" seçiminin değiştireceği tek bir değer
bırakıyor.

**Karar: açık temada turkuaz ve mavi koyulaştırıldı** — `#2DD4BF` yerine
`#0D9488`, `#4F92F7` yerine `#2563EB`. Sebep kontrast: `#2DD4BF` beyaz
zeminde beyaz yazıyı taşıyamıyor (oran ~1.7). Marka degradesinin yönü ve
karakteri korundu, yalnızca değeri düştü.

**Karar: seçili/etkin öğelerde yazı rengi koyu.** Turkuaz açık bir renk;
üstüne beyaz yazı okunmuyor. Koyu temada seçili satırın yazısı
`#0D141B`. Aynı sebeple Openbox'ta etkin pencerenin başlık yazısı da koyu.

**Karar: "yasak" imleci kırmızı kaldı** (`#EF4444`). Turkuaz bir yasak
işareti işlevini anlatmıyor; tek renk istisnası bu.

**Karar: imleç dış çizgisi neredeyse siyah** (`#0D141B`). İmleç hem koyu
masaüstünde hem beyaz bir belgenin üstünde aynı netlikte görünmeli.

**Karar: duvar kağıdı adı `karan-koyu` → `karan-gece`.** Varsayılan tema
koyu olunca "koyu" ayırt edici bir ad olmaktan çıktı. Üçü de koyu:
`karan` (marka degradesi), `karan-gece` (en sakin), `karan-duz` (düz
zemin + logo).

### Hata 1: grafik oturum hiç açılmıyordu — `user-setup` eksikti

**Belirti:** CI 1. ve 2. aşamada yeşil yandı ama QEMU ekran görüntüsü
simsiyahtı. `boot-check` "WM-WARN openbox bulunamadi" yazıyor, buna
rağmen `RESULT=OK` veriyordu.

**Kök sebep:** `live-config`, canlı kullanıcıyı
`/usr/lib/user-setup/user-setup-apply` ile oluşturuyor ve bu dosya
`user-setup` paketinden geliyor. `live-config` onu yalnızca
**Recommends** ile istiyor. Biz `--apt-recommends false` ile derliyoruz,
dolayısıyla paket hiç kurulmadı, `karan` kullanıcısı hiç oluşmadı,
lightdm var olmayan bir kullanıcıya otomatik giriş yapmaya çalışıp boş
bir X kök penceresinde kaldı.

Bu, `CLAUDE.md`'de zaten yazan tuzağın (`libpam-systemd` örneği) ikinci
kez ısırması. `user-setup` artık `01-base.list.chroot` içinde, sebebiyle
birlikte.

**Nasıl bulundu:** ISO'yu Codespace'e indirip squashfs'i açtım,
`lightdm.conf`, `xsessions`, `openbox-session` — hepsi yerindeydi.
Sonra `live-config` paketini indirip `0030-user-setup` bileşenini
okudum; `user-setup-apply` çağrısını görünce paketin Recommends'te
olduğunu doğruladım. Tahminle üç CI koşusu harcamaktan ucuzdu.

**Denenip vazgeçilen:** canlı sisteme seri konsoldan girip
`/var/log/lightdm` okumak. Canlı kullanıcı hiç oluşmadığı için parola
da yoktu (`live-config` parolayı `live` yapıyor ama kullanıcı yaratılmamış).
`systemd.debug-shell` ile tty9'dan root kabuğu denemesi de yarıda kaldı.
Paket metaverisini okumak daha kısa yoldu.

### Hata 2: `/etc/os-release` devralınmıyordu

**Belirti:** ISO içindeki `/usr/lib/os-release` doğru ("Karan OS 1.0")
ama çalışan sistemde `/etc/os-release` "Debian GNU/Linux 13" diyordu.

**Kök sebep:** Debian'da `/etc/os-release`, `/usr/lib/os-release`'e giden
bir sembolik bağ. `karanos-theme` hedefi `dpkg-divert` ile devralıyor —
bu kısım çalıştı, derleme günlüğünde görünüyor. Ama **live-build**
derlemenin erken bir aşamasında `/etc/os-release`'i silip yerine
**gerçek bir dosya** yazıyor: Debian'ın o anki içeriği + `IMAGE_ID` ve
`BUILD_ID`. Bu iş bizim paketimiz kurulmadan önce olduğu için bağ
kopuyor ve eski içerik donuyor.

**Çözüm:** `iso/config/hooks/normal/9996-os-release.hook.chroot`.
Chroot hook'ları paketlerden sonra çalıştığı için burada
`/usr/lib/os-release`'i tekrar `/etc/os-release`'e yazıyoruz.
live-build'in eklediği `IMAGE_ID` / `BUILD_ID` satırları korunuyor —
onlar derlemenin kimliği, bizim üstümüze aldığımız bilgi değil.
Hook, dosya bizim sürümümüz değilse derlemeyi durduruyor.

### Duman testi artık yanlış yeşil veremiyor

İki kere yeşil yanıp aslında masaüstü açılmadığı için testin geçme
şartları sıkılaştırıldı:

- `boot-check` içinde ölümcül hata listesi var. Kullanıcı yok, pencere
  yöneticisi yok, tema eksik, imleç yok, duvar kağıdı yok ya da
  os-release yanlışsa `RESULT=FAIL`. Eskiden bunlar "uyarı"ydı.
- Pencere yöneticisi için 60 saniyelik bekleme eklendi — oturum X'ten
  birkaç saniye sonra açılıyor, anlık bakmak yanlış negatif veriyordu.
- `tools/screen-not-blank.py`: QEMU ekran görüntüsünün gerçekten bir şey
  gösterdiğini ölçüyor (renk çeşitliliği + parlaklık sapması). Boş ekran
  testi düşürüyor. `RESULT=OK` satırını görmek yetmiyor artık.
- Pencere yöneticisi yoksa `boot-check` lightdm günlüklerini, oturum
  dosyalarını ve süreç listesini seri konsola döküyor — bir sonraki
  arıza tek koşuda teşhis edilsin diye.

### Yerel doğrulama

`tools/theme-screenshot.sh` Xvfb + Openbox'ta temayı çizip PNG veriyor,
~10 saniye. `VARYANT=acik` ile açık tema. Bu turda üç hatayı ISO
derlemeden yakaladı: kaydırıcı dolgusu Adwaita mavisinde kalmıştı,
Openbox `label.bg` yazılmadığı için başlık çubuğunun ortasını siyaha
boyuyordu, önizleme penceresi sabit `sleep` yüzünden kareye
girmiyordu (artık pencere haritalanana kadar bekleniyor).

---

## Aşama 2 — karanos-theme

**Karar: sıfırdan GTK teması yazılmadı.** GTK'nın kendi Adwaita'sı
`@import` ile alınıp yalnızca renkler ve vurgu alan bileşenler eziliyor.
Sıfırdan tema binlerce satır ve her GTK güncellemesinde bozulan bir
bakım yükü; bu yöntemde yeni GTK sürümü gelince tema kendiliğinden
uyumlu kalıyor.

**Karar: depoda üretilmiş ikili dosya yok.** Simgeler, imleçler ve duvar
kağıtları `assets/logo/k-logo.svg` ve `tools/gen-*.py` üreteçlerinden
derleme sırasında çıkıyor. 16 imleç şekli × 4 boyut (ikisi 12 kareli
animasyon) = 400'den fazla PNG; bunları depoda tutmak her renk
değişikliğini megabaytlarca ikili fark yapardı.

**Karar: Openbox teması hook'la, dosya değiştirilerek değil.**
`rc.xml` yalnızca tema adını değil **bütün fare ve klavye kısayollarını**
taşıyor. Dosyayı kendi sürümümüzle değiştirseydik `<mouse>` bölümü
giderdi ve pencereler fareyle tutulamaz hâle gelirdi.
`0200-openbox-theme.hook.chroot` awk ile yalnızca `<theme>` bloğundaki
ilk `<name>` alanını değiştiriyor (sonraki `<name>`ler yazı tipi adları).

**Karar: `.deb`'ler ISO'ya `config/packages.chroot/` üzerinden giriyor.**
`build-packages.yml` paketleri üretiyor, `build-iso.yml` onu `uses:` ile
çağırıp yapıtı indiriyor. Böylece ISO'ya giren `.deb` ile test edilen
`.deb` aynı koşunun ürünü. Gerçek APT deposu 13. aşamada.

**Karar: tema önizleme penceresi geçici.** 2. aşamada tema var ama onu
gösterecek panel/masaüstü yok; boş ekranın görüntüsüne bakıp "tema
uygulanmış mı" denemez. `/usr/lib/karanos/theme-preview` yalnızca canlı
ortamda açılıyor (`/run/live/medium` varsa) ve 4. aşamada panel gelince
silinecek. Etiketleri `docs/karanos-arayuz-metinleri.md` içindeki
`appearance.*` anahtarlarından alındı — bu pencereye özel metin
uydurulmadı.

---

## Aşama 1 — çıplak ISO

**Tuzak: live-build `set timeout` yazmıyor.** GRUB'da timeout tanımsızsa
menü sonsuza kadar tuş bekler, ISO hiç açılmaz. Üç QEMU testi de 25
dakika zaman aşımına uğradı. `9500-grub-timeout.hook.binary` bunu
ekliyor; iş akışındaki "ISO içi önyükleyici doğrulaması" adımı ISO'nun
içinden `config.cfg`'yi çıkarıp satırın gerçekten orada olduğunu
doğruluyor.

**Tuzak: binary hook'lar `binary/` dizininin İÇİNDE çalışıyor**, derleme
kökünde değil. İlk sürüm yanlış dizinde arıyordu.

**Tuzak: `cmd | tee` tee'nin çıkış kodunu döndürüyor.** `iso/auto/build`
bu yüzden `#!/bin/bash` + `set -eo pipefail` kullanıyor; olmazsa
başarısız derleme CI'da yeşil görünüyor — bir kez görünmüştü de.

**Karar: `--apt-recommends false` yalnızca derleme için.**
`9990-apt-recommends.hook.chroot` kurulan sistemde Recommends'i geri
açıyor. Bunun bedeli: Recommends'ten gelen paketler (`libpam-systemd`,
`user-setup`) paket listelerinde açıkça yazılmak zorunda.
