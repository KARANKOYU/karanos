# gamescope — referans incelemesi

İlgili Kavis maddesi: 13 (Oyun Modu çekirdeği). İnceleme tarihi: 2026-09-01,
depo HEAD'i `ea3579e` (2026-08-30). Kaynak: `/tmp/referans/gamescope`
(sığ klon; kod kopyalanmadı, yalnızca yaklaşım incelendi).

## Kimlik

- Valve'ın "mikro-kompozitörü"; SteamOS/Steam Deck'te Oyun Modu'nun temelini
  oluşturan bileşen. Eski adı steamcompmgr.
- C/C++ (C++20), meson ile derleniyor. Oyunu kendi özel Xwayland
  "kum havuzu" masaüstünde çalıştırır; oyun yalnızca gamescope'un
  taklit ettiği sanal ekranı görür.
- Sürüm numarası meson'da sabit değil, `git describe --tags` ile üretiliyor;
  HEAD'in tam sürüm etiketi sığ klonda görünmüyor (doğrulanmadı), ancak
  Debian sid paketlemesi 3.16.24 olduğuna göre HEAD ~3.16.x düzeyinde.

## Çalışma kipleri ve gereksinimler

İki ana kip, tek `--backend` seçeneğiyle seçiliyor; seçilmezse otomatik
karar `main.cpp` içinde: `WAYLAND_DISPLAY` varsa **wayland**, `DISPLAY`
varsa **sdl** (X11 altında iç içe), hiçbiri yoksa **drm** (embedded).
Ayrıca `headless` ve (derlenirse) `openvr` arka uçları var.

- **İç içe (nested, SDL/Wayland arka ucu):** Mevcut masaüstünün üstünde
  normal bir pencere. Kavis'in "Oyun Modu düğmesi" akışına uyan kip budur:
  X11+Openbox oturumu açık kalır, gamescope `-f` ile tam ekran bir X11
  penceresi olur. Sınırlar: DRM'e doğrudan flip yok (her kare masaüstü
  kompozisyonundan geçer, gecikme ve bir kopya fazla), HDR/VRR gibi
  özellikler ana kompozitöre bağımlı; Openbox kompozitörsüz olduğundan
  bunlar zaten söz konusu değil ama temel akış çalışır.
- **Embedded (DRM arka ucu):** tty'den kendi KMS oturumunu açar; ekrana
  doğrudan flip, en düşük gecikme. Oturum yönetimi wlroots'un
  `wlsession`/**libseat (seatd veya logind)** yoluyla; DRM master bu
  katmandan alınır. Kavis'te bunu kullanmak panel/X oturumunu durdurup
  ayrı bir VT'de gamescope başlatmak demek — SteamOS'un yaptığı bu, ama
  madde 13'ün "çıkınca masaüstüne döner" hedefi için nested çok daha basit.
- **Vulkan zorunlu.** Kompozisyon async Vulkan compute ile yapılıyor;
  Vulkan aygıtı yoksa başlamaz. Kod, seçilen fiziksel aygıtta DRM
  primary/render node arıyor (`rendervulkan.cpp`: "physical device has no
  render node" hatası) — llvmpipe/lavapipe DRM node'u sunmadığı için
  salt yazılımsal Vulkan ile çalışması beklenmez (canlı test yapılmadı;
  doğrulanmadı). Pratik sonuç: 3B hızlandırmasız VM'lerde (CI'daki QEMU
  dahil) gamescope açılmaz.
- Sürücü tabanı: Mesa + AMD (Mesa 20.3+) ve Intel (21.2+); NVIDIA kapalı
  sürücüde 515.43.04+ ve `nvidia-drm.modeset=1` şart.
- **CAP_SYS_NICE isteğe bağlı ama önemli:** varsa gerçek zamanlı compute
  kuyruğu ve iş parçacığı önceliği; yoksa "falling back to
  regular-priority" uyarısıyla düşük performansla devam eder. `--rt`
  bayrağı gerçek zamanlı zamanlama açar. Paketlemede binary'ye
  `setcap cap_sys_nice+ep` vermek yaygın yaklaşım.
- GameMode ile doğrudan bir bütünleşme kodda yok; GameMode ayrı ve
  tamamlayıcı bir araç (CPU vali/öncelik ayarı), birlikte kullanılabilir.

## Steam Big Picture akışı

- Temel komut biçimi: `gamescope [seçenekler] -- steam -gamepadui`
  (`-gamepadui` = Big Picture / Deck arayüzü).
- `-e` / `--steam` bayrağı "Steam bütünleşmesini" açar: kod
  `steamMode=true` yapıp `STEAM_GAMESCOPE_*` ortam değişkenlerini
  (VRR/NIS/HDR/dinamik FPS limiti destek bildirimleri) ayarlıyor; Steam
  arayüzü bu değişkenlere bakarak gamescope'a özgü ayar sayfalarını
  gösteriyor. Kavis için hedef komut kabaca:
  `gamescope -e -f -W <genişlik> -H <yükseklik> -- steam -gamepadui`.
- Çözünürlük/ölçekleme: `-W/-H` gamescope çıktısı, `-w/-h` oyunun
  gördüğü sanal ekran; `-S integer|stretch` ölçekleme kipi,
  `-F fsr|nis` yükseltme filtresi (FSR 1.0 / NVIDIA Image Scaling),
  `-r` FPS sınırı, `-o` odak dışı FPS sınırı, `-f` tam ekran,
  `-b` kenarlıksız. Super+F/U/Y gibi kısayollar çalışma anında değiştirir.
- **MangoHud:** `--mangoapp` bayrağı gamescope'un kendi "mangoapp"
  sürecini (mangohud tabanlı performans katmanı) başlatır; yardım metni
  oyuna ayrıca mangohud takmak yerine bunu kullanmayı öneriyor.
  `--steam` ile birlikteyken yatay çubuk kipi ve varsayılan yapılandırma
  otomatik ayarlanıyor.
- Yardımcı süreçler: `gamescopereaper` (oyun kapanınca alt süreçleri
  toplar), `gamescopectl` (çalışan gamescope'a komut). "Çıkınca masaüstüne
  dönüş" nested kipte kendiliğinden olur: gamescope süreci bitince X11
  penceresi kapanır, Openbox oturumu zaten yerindedir.

## Donanım/sürücü gerçekleri

- **NVIDIA sorunlu bölge:** en çok yorum alan açık issue'lardan üçü NVIDIA
  ("gamescope doesn't run on NVIDIA", 555 sürücü durumu, hibrit NVIDIA'da
  bozulma). Kapalı sürücüde çalışma, sürücü sürümüne aşırı duyarlı;
  hibrit (Optimus) dizüstülerde ayrıca kırılgan.
- **VM'de çalışmaz:** Vulkan + DRM render node şartı yüzünden CI'daki
  QEMU duman testinde Oyun Modu **test edilemez**. Kavis CI'sında en fazla
  "gamescope binary'si var mı, --help çalışıyor mu" düzeyinde doğrulama
  yapılabilir; gerçek doğrulama kullanıcının VirtualBox'ı değil (orada da
  çalışmaz), gerçek donanımı gerektirir.
- Eski AMD kartlarda (GFX8 ve altı) `R600_DEBUG=nodcc` gerekiyor, yoksa
  görüntü bozulması oluyor (README).
- **Debian paketi:** gamescope **trixie'nin kendisinde yok**; bookworm
  main'de 3.11.49 vardı, trixie'de paket çıkarılmış. trixie-backports'ta
  `3.16.22+ds-1~bpo13+1` (contrib bölümünde), forky/sid'de `3.16.24+ds-2`
  var (sources.debian.org, 2026-09-01). Yani backports paketi kaynağın
  yalnızca 1-2 yama sürümü gerisinde ve gayet güncel; ama Kavis'in paket
  listesine girmesi için **backports deposunun ve contrib bölümünün**
  etkin olması gerekir. `tools/check-packages.sh`'nin trixie ana arşivine
  baktığı varsayılırsa gamescope orada bulunamayacaktır — kontrol aracına
  backports istisnası gerekebilir (doğrulanmadı).

## Tuzaklar (tekrar eden issue şikâyetleri)

En çok yorum alan issue'lardan (2026-09-01, `gh api` ile):

- NVIDIA'da hiç açılmama / sürücü sürümüne bağlı kırılmalar (107, 80, 66,
  58 yorumlu issue'lar) — en büyük şikâyet kümesi.
- Masaüstünde (nested) ağır takılma/stutter raporları; "girdi takılıyor
  ama frame time mükemmel" tarzı girdi gecikmesi şikâyetleri (114, 88).
- Launcher'lı oyunlar (ayrı pencere açan başlatıcılar) nested gamescope
  içinde sorun çıkarıyor (113 yorum) — Kavis'te Steam dışı oyunlar için
  akılda tutulmalı; Steam Big Picture akışında daha az sorun.
- "Gamescope breaks Steam Overlay" (76): overlay'i yalnızca SDL arka ucu
  çizebiliyor (kodda açık yorum var); Wayland arka ucunda overlay sorunu.
- "Gamescope doesn't quit when game quits" (62): süreç yaşam döngüsü
  kırılganlığı — Kavis'in "çıkınca masaüstüne dön" betiği gamescope'un
  kendi kendine kapanmasına güvenmemeli, süreç izleyip gerekirse
  öldürmeli.
- `vkCreateDevice failed (VkResult: -7)` ve Intel'de fiziksel aygıt
  bulunamaması: eski/uyumsuz Vulkan sürücülerinde tipik açılmama biçimi.
- Fare imleci hız/kilitleme sorunları (50, 37 yorumlu) ve nested kipte
  klavye düzeninin ana oturumdan alınmaması (54) — Türkçe klavye
  kullanan Kavis için bu sonuncusu doğrudan ilgili.

## Kavis için çıkarımlar

1. **Nested kip doğru seçim.** Madde 13'ün akışı ("panel durur → tam ekran
   gamescope → çıkınca masaüstü") X11+Openbox üstünde
   `gamescope -e -f -W… -H… -- steam -gamepadui` ile kurulabilir; ayrı VT
   / DRM oturumu (SteamOS tarzı embedded) karmaşıklığına gerek yok.
   Panel'i durdurup gamescope'u bekleyen, dönüşte paneli geri başlatan
   basit bir sarmalayıcı betik yeterli.
2. **Çıkış güvencesi betikte olmalı:** gamescope/steam'in asılı kalma
   şikâyetleri nedeniyle sarmalayıcı, Steam kapanınca gamescope'u
   zaman aşımıyla sonlandırmalı; masaüstüne dönüş gamescope'un iyi
   niyetine bırakılmamalı.
3. **Donanım kapısı koy:** Vulkan aygıtı yoksa (VM, çok eski GPU) Oyun
   Modu düğmesi ya gizlenmeli ya da arayüz metinleri belgesindeki uygun
   hata mesajıyla reddetmeli (`vulkaninfo`/aygıt sorgusu ile ön kontrol).
   Bu durum arayüz metinlerine mesaj eklenmesini gerektirebilir —
   `docs/kavis-arayuz-metinleri.md`'de karşılığı yoksa metin uydurmadan
   sorulmalı.
4. **CI sınırı kabullenilmeli:** QEMU duman testi Oyun Modu'nu asla
   çalıştıramayacak; CI yalnızca paketin kurulduğunu ve betiğin sözdizimini
   doğrular, görsel test gerçek donanımda elle yapılır.
5. **Paketleme:** trixie ana arşivinde gamescope yok; trixie-backports +
   contrib etkinleştirilmeli (3.16.22) ve `check-packages.sh`'ye bu
   istisna öğretilmeli. Binary'ye `cap_sys_nice` verilmesi ve klavye
   düzeni (TR) ile fare davranışının gerçek donanımda test listesine
   eklenmesi önerilir. NVIDIA'lı makinelerde Oyun Modu "elden geldiğince"
   statüsünde tutulmalı; birincil hedef AMD/Intel + Mesa olmalı.
