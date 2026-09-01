# bazzite — referans incelemesi

İlgili Kavis maddesi: 13 (Oyun Modu) + proje stratejisi. İnceleme tarihi:
2026-09-01, depo HEAD'i `b2d2bf0` (2026-08-31).

Not: Bu belge yalnızca yaklaşımı anlatır; Bazzite'ten kod kopyalanmamıştır.

## Kimlik

Bazzite, Universal Blue çatısı altında geliştirilen, Fedora Atomic
(Kinoite/Silverblue) tabanlı **OSTree/bootc konteyner imajı** olarak dağıtılan
bir oyun odaklı dağıtım. Sıfırdan dağıtım değil: hazır Fedora Atomic imajının
üstüne tek bir `Containerfile` ile paket + yapılandırma katmanı bindiriyor.
Tek depo, GitHub Actions'ta derlenen ~10 imaj varyantı (masaüstü / deck /
nvidia × KDE / GNOME). Steam Deck ve el konsolları (ROG Ally, Legion Go,
GPD...) için SteamOS benzeri "Game Mode" deneyimini Fedora'ya taşımasıyla
tanınıyor.

## Oyun Modu teknik kurulumu

### Oturum: gamescope-session

- Oyun modu ayrı bir **Wayland oturumu**: `gamescope` bileşik yöneticisi
  (compositor) içinde Steam'in Big Picture arayüzü çalışıyor. Bazzite bunu
  hazır paketlerle kuruyor: `gamescope-session-plus` (ChimeraOS kökenli
  oturum çatısı) + oturum tanımı paketi (`gamescope-session-ogui-steam`).
  Paketler Fedora COPR/Terra depolarından geliyor; yani oturum altyapısı
  Bazzite'in kendi kodu değil, ChimeraOS/Valve ekosisteminden alınan hazır
  bileşen.
- Steam'in ilk açılışta internetsiz de çalışabilmesi için Nobara projesinden
  hazır bir `bootstrap_steam.tar.gz` arşivi imaja gömülüyor; ilk oturumda
  kullanıcının `~/.local/share/Steam` dizinine açılıyor.
- Steam masaüstü oturumunda da sistem genelinde `xdg/autostart` ile sessiz
  (`-silent`) başlatılıyor.

### Masaüstü ↔ oyun modu geçişi

- Geçiş mantığının merkezi Valve'ın **steamos-manager** servisi: `steamosctl`
  komutuyla `switch-to-game-mode` / `switch-to-desktop-mode` çağrılıyor ve
  varsayılan giriş kipi (`set-default-login-mode game|desktop`) saklanıyor.
- Görüntü yöneticisi **SDDM** (GNOME imajında bile GDM kapatılıp SDDM
  kuruluyor — tek DM, tek otomatik giriş mekanizması). Açılışta
  `display-manager.service`'ten önce çalışan küçük bir oneshot servis
  (`bazzite-autologin.service`) SDDM'e `conf.d` altına iki damla (drop-in)
  yazıyor: biri `Autologin/User` (UID 1000), diğeri `Autologin/Session`
  (varsayılan kipe göre gamescope oturumu ya da plasma/gnome). Yani geçiş =
  "varsayılan oturumu değiştir + oturumu kapat, SDDM otomatik girişle diğer
  oturumu açar".
- Masaüstünde kullanıcıya "Oyun moduna dön" kısayolu veriliyor
  (`return-to-gamemode`); Steam istemcisinin beklediği eski
  `os-session-select` betiği de geriye dönük uyumluluk için duruyor, içi
  `steamosctl`'e yönlendirme.
- Deck imajlarında oturum kapanırken süreçlerin asılı kalmaması için logind'e
  `KillUserProcesses=true` ve güç tuşunun oyun modunca yönetilmesi için
  `HandlePowerKey=ignore` damlaları konmuş.

### Çekirdek / zamanlayıcı / sysctl

- Çekirdek: Fedora'nın stok çekirdeği değil; "ogc" adlı, oyun yamaları
  (fsync/futex, el cihazı sürücüleri vb.) içeren özel derlenmiş çekirdek ayrı
  bir imajdan (akmods) alınıyor. Nvidia imajlarında LTS varyantı tercih
  edilmiş.
- Zamanlayıcı: System76-scheduler değil, **sched_ext (scx)** kullanıyorlar:
  `scx-scheds` paketi + `scx_loader` servisi, varsayılan zamanlayıcı
  `scx_lavd` ("Auto" kipinde). Oyun kipine geçildiğinde steamos-manager,
  scx_loader'a "gaming_mode" profili uygulatıyor (ör. lavd için performans
  bayrağı). scx, 6.12+ çekirdek ve Rust araçları istiyor.
- sysctl (masaüstü ortak): `vm.max_map_count=2147483642` (bazı oyunlar ve
  Proton için şart), `kernel.split_lock_mitigate=0` (split-lock cezası
  oyunlarda ciddi FPS düşürür), inotify limitlerinin yükseltilmesi, TCP BBR.
- sysctl (deck/el cihazı ek): watchdog'ların tamamen kapatılması
  (`kernel.nmi_watchdog=0` vb.), zram'e uygun bellek ayarı
  (`vm.swappiness=180`, `vm.page-cluster=0`, dirty_bytes sınırları) —
  SteamOS'un bilinen değerleri.
- modprobe ile iTCO ve sp5100 watchdog modülleri kara listede; PAM
  limits ile kullanıcıya `nice -8` hakkı (gamemode'un önceliği yükseltmesi
  için).
- Güç profilleri: `tuned` + power-profiles-daemon uyumluluk katmanı;
  Bazzite kendi tuned profillerini (`*-bazzite`) ppd.conf'a eşliyor. Ayrıca
  AC/pil durumuna göre hedeflenebilen `ac.target` / `battery.target`
  systemd hedefleri var.

### MangoHud / GameMode

- `mangohud` hem 64 hem 32 bit olarak imaja kurulu (Proton'daki 32-bit
  oyunlar için i686 kopya önemli). Oyun modunda gamescope'un kendi mangoapp
  entegrasyonu kullanılıyor (performans göstergesi Steam arayüzünden
  açılıyor; ayrıntısı doğrulanmadı).
- Feral `gamemode` kurulu; ayrıca oyun modu oturumuna haber/duyuru düşüren
  küçük bir kullanıcı servisi (gamemode-news-hook) eklemişler.

### Ses ve el cihazı (handheld) özelleştirmesi

- `steamdeck-dsp`: Valve'ın Deck DSP/EQ zinciri. Cihaza özel PipeWire ve
  WirePlumber profilleri `hardware-profiles` dizinlerinde cihaz adıyla
  (DMI kimliği) eşleşiyor — ROG Ally, GPD Win, Legion Go için ayrı ayrı.
- Giriş: `inputplumber` (denetleyici yeniden eşleme daemon'u), `sdgyrodsu`
  (jiroskop), `vpower`/`powerbuttond` (güç tuşu), `jupiter-fan-control` ve
  `jupiter-hw-support` (Valve'ın Deck donanım paketleri; Deck dışı donanımda
  servisleri kapalı geliyor, udev ile açılıyor).
- Donanım tespiti tek yerde: `hwsupport/` altında `valve-hardware`,
  `handheld-hardware`, `needs-200-scale` gibi küçük sorgu betikleri; oturum
  başlangıcı ve udev kuralları bunlara danışıyor. Ekran döndürme/ölçek gibi
  cihaz tuhaflıkları bu betiklerle çözülüyor.
- SDDM'de dokunmatik için Qt sanal klavye etkin.

### ujust komut sistemi

- `just` tabanlı kullanıcı komutları: sistemde `/usr/share/ublue-os/just/`
  altında konuya göre bölünmüş ~20 `.just` dosyası (uygulama kurulumları,
  ses düzeltmeleri, sanal makine, Waydroid, Decky, oturum varsayılanı...).
  `ujust` sarmalayıcısı bunları tek listede sunuyor. Toplam ~5600 satır —
  "belge yerine çalıştırılabilir SSS" işlevi görüyor: kullanıcıya "şu üç
  komutu yapıştır" demek yerine "ujust fix-..." deniyor.

## Proje stratejisi dersleri

1. **Sıfırdan dağıtım değil, katman.** Bazzite Fedora Atomic'in üstüne tek
   Containerfile'lık bir katman; çekirdek, oturum çatısı
   (gamescope-session-plus), Deck paketleri (jupiter/steamdeck-*) ve
   steamos-manager gibi ağır parçaların hepsi başkalarının bakımındaki hazır
   paketler. Kendi yazdıkları şey çoğunlukla **küçük tutkal betikleri ve
   yapılandırma damlaları**. Depolarının başındaki notta bile "fork etme,
   şablon imajı kullan" deniyor.
2. **Tek depo, matris CI.** GitHub Actions'ta haftalık zamanlanmış + push
   tetiklemeli derleme; tek workflow, ~10 imajlık matris; imzalama (cosign),
   sürüm etiketi otomatiği ve ISO üretimi ayrı workflow'lar. Kavis'in
   "yapılandırma depoda, derleme CI'da" yaklaşımının aynısı, ölçeği büyük.
3. **Yerleşik teşhis ve tek tip kurtarma.** İmaja `image-info.json` gömülüyor
   (betikler hangi varyantta çalıştığını buradan öğreniyor); geri alma için
   `bazzite-rollback-helper` var. Betiklerin cihaza/varyanta göre dallanması
   tek bir gerçek kaynaktan yapılıyor.
4. **Belge + topluluk ayrı kanallar.** Depo README'si vitrin; asıl bilgi
   docs.bazzite.gg (ayrı depo), forum/Discord ve issue şablonları. README
   ~10 dile çevrilmiş (TR dahil) — el cihazı kitlesi küresel.
5. **Kullanıcıya dokunan her şey komutlaştırılmış.** Sık sorunların cevabı
   ujust komutu olarak gemiye konuyor; destek yükü "şu komutu çalıştır"a
   iniyor. Kavis'te karşılığı: sık işlemler için Türkçe adlı küçük araçlar.
6. **Duyuru mekanizması imajın içinde.** JSON duyuru dosyaları depodan
   çekilip oturuma bildirim olarak düşüyor; dağıtım-kullanıcı iletişimi için
   ayrı bir uygulamaya gerek kalmıyor.

## Tuzaklar (tekrar eden issue şikâyetleri)

En çok yorum alan açık issue'lardan süzülen tekrar eden temalar
(2026-09-01, `gh api` ile):

- **Ses**: gamescope altında ses kekemeliği (6700XT, 144 yorum), Xbox Ally X
  ses sorunları, AMD HDMI ses kesintileri, Ayaneo'da eksik ses firmware'i.
  DSP/profil yaklaşımı cihaz başına elle emek istiyor ve kırılgan.
- **Uyku/uyanma**: uyanınca ekran gelmiyor, uyanma sonrası performans
  düşüşü, GPU reset. El cihazlarında suspend en kırılgan yüzey.
- **HDR/görüntü**: oyun modunda HDR'ın güncellemeyle bozulması; HDR açıkken
  masaüstünün soluk görünmesi; eski GPU'larda (RX 580) gamescope'un hiç
  çalışmaması — gamescope'un donanım eşiği gerçek bir sınır.
- **Giriş cihazları**: Xbox kablosuz alıcısı, Ally denetleyicisinin oturum
  ortasında ölmesi, direksiyon sürücüleri (hid-tmff2) talebi.
- **DM/oturum**: "SDDM başlamıyor", "oyun moduna önyüklenemedi" — otomatik
  giriş + oturum seçme zinciri koptuğunda kullanıcı siyah ekranda kalıyor.
- **Donanım genişledikçe regresyon**: her yeni el cihazı kendi udev/DSP/
  firmware istisnasını getiriyor; sürücü çıkarımları (Broadcom) eski
  donanımları kırıyor.

Ders: oyun modu zincirinin (DM → otomatik giriş → gamescope → Steam) her
halkası tek hata noktası; bozulunca kullanıcı grafik arayüzsüz kalıyor.
Kavis'te bu zincire girilecekse "masaüstüne güvenli dönüş" yolu baştan
tasarlanmalı.

## Kavis için çıkarımlar

Madde 13'ü (Oyun Modu) yazarken somut yol:

- **apt'te (trixie) hazır olanlar** (paket indeksine karşı doğrulandı):
  `mangohud`, `gamemode`, `steam-installer` + `steam-devices` (non-free),
  `tuned`, `irqbalance`. Bunlar doğrudan paket listesine yazılabilir.
- **apt'te OLMAYANLAR**: `gamescope` trixie ANA arşivinde **yok** (doğrulandı;
  trixie-backports/contrib'te 3.16.22 var — ayrıntı için bkz. `gamescope.md`);
  gamescope-session-plus, steamos-manager, inputplumber, steamdeck-dsp gibi
  parçaların hiçbiri Debian'da yok. Tam SteamOS benzeri oturum istenirse
  gamescope'un elle derlenmesi/paketlenmesi gerekir — bakım yükü büyük.
- **Gerçekçi hedef önerisi**: Kavis bir el cihazı dağıtımı değil; madde 13
  için "gamescope oturumu" yerine Bazzite'ten şu taşınabilir parçaları
  almak yeterli olabilir:
  - sysctl damlası: `vm.max_map_count` artışı, `kernel.split_lock_mitigate=0`,
    inotify limitleri (hepsi Debian'da aynen çalışır, çekirdek 6.12
    `split_lock_mitigate` anahtarını içeriyor — trixie çekirdeğinde var olup
    olmadığı doğrulanmadı, hook'ta koşullu yazılmalı).
  - `gamemode` + kullanıcıya `nice` hakkı veren limits damlası.
  - `mangohud` kurulumu ve Steam başlatma seçeneklerinde kullanımı için
    belge/araç.
  - İsteğe bağlı "Büyük Ekran" kestirmesi: tam oturum değil, Steam Big
    Picture'ı açan bir masaüstü kısayolu — geçiş zinciri riskine girmeden
    oyun modu hissi verir.
- **Geçiş mimarisi dersi**: yine de tam oyun modu yapılacaksa Bazzite'in
  deseni Debian'a birebir taşınabilir: tek DM (Kavis'te LightDM/SDDM hangisi
  seçildiyse) + açılışta autologin conf damlası yazan oneshot servis +
  "varsayılan oturum" durumunu tutan tek dosya + masaüstünde "oyun moduna
  dön" kısayolu. steamos-manager yerine bu mantığı kuran küçük bir betik
  çifti yeterli.
- **scx/sched_ext**: Debian trixie'de scx zamanlayıcı paketleri yok
  (indekste bulunamadı); bu kapı şimdilik kapalı, `gamemode` yeterli.
- **Strateji**: Bazzite'in asıl sırrı teknik değil — hazır bileşenleri
  katmanlayıp kendi emeğini tutkal betiklerine ve kullanıcı deneyimine
  harcaması. Kavis zaten Debian + live-build ile aynı felsefede; madde 13'te
  de "gamescope'u kendimiz paketleyelim" tuzağına düşmeden apt'teki
  parçalarla yetinmek bu stratejinin devamı olur.
