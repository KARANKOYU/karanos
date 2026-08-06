# Karan OS — Claude Code Görev Tanımı

> Bu dosyayı Claude Code'a olduğu gibi ver. Köşeli parantezli `[...]` yerleri
> sen doldur (kurtarma ifadesi, boot görseli, mp3, GitHub kullanıcı adı).

---

## 1. Proje

Debian tabanlı, x86_64 mimarisinde, kişisel bir Linux dağıtımı yapıyoruz:
**Karan OS**. Windows benzeri bir masaüstü, kendi açılış ekranı, kendi giriş
ekranı ve kendi ayarlar uygulaması olacak. Kendi kernel'imizi yazmıyoruz —
Debian'ın imzalı çekirdeğini kullanıyoruz.

Hedef kitle: geliştiricinin kendisi ve birkaç arkadaşı. Halka dağıtım yok.

**Çıktı:** GitHub Releases'ten indirilebilen, USB'ye yazılıp kurulabilen bir
ISO (hedef boyut: 1.5 GB altı).

---

## 2. Teknik temel

| Konu | Karar |
|---|---|
| Taban | Debian stable (trixie), `live-build` ile ISO üretimi |
| Mimari | x86_64 (amd64) |
| Çekirdek | Debian'ın kendi imzalı çekirdeği — **derleme yok**, Secure Boot açık kalabilmeli |
| Kök dosya sistemi | btrfs, `@` (sistem) ve `@users` (kullanıcı) alt birimleriyle |
| EFI bölümü | FAT32, 512 MB |
| Görüntü sunucusu | X11 |
| Pencere yöneticisi | Openbox (tema edilmiş) |
| Kendi yazılımlarımızın dili | **Python 3 + GTK3 (PyGObject)** |
| Kurulum aracı | Calamares (özel markalama + özel ön kontrol modülü) |
| Genel ilke | **Hafiflik** — boşta toplam RAM kullanımı ideal olarak 1 GB altı, en fazla 1.5 GB |
| Snapshot | Timeshift (btrfs modu), her `apt` işleminden önce otomatik |

---

## 3. Depo yapısı

```
karanos/
├── packages/
│   ├── karanos-boot/         # Plymouth teması (görsel + mp3)
│   ├── karanos-greeter/      # giriş ekranı
│   ├── karanos-setup/        # ilk açılış sihirbazı
│   ├── karanos-panel/        # görev çubuğu + başlat menüsü
│   ├── karanos-settings/     # ayarlar uygulaması
│   ├── karanos-store/        # uygulama mağazası
│   ├── karanos-deb-installer/# .deb kurucu (Paket Kurucu)
│   ├── karanos-taskmanager/  # görev yöneticisi
│   ├── karanos-tools/        # ekran görüntüsü, pano geçmişi, bildirimler, OSD
│   ├── karanos-theme/        # GTK teması, imleç teması, K logosu, duvar kağıtları
│   └── karanos-desktop/      # meta paket (hepsini bağlar)
├── iso/                      # live-build yapılandırması, paket listeleri
├── installer/                # Calamares yapılandırması + ön kontrol modülü
├── repo/                     # aptly ile üretilen APT deposu (GitHub Pages)
└── .github/workflows/        # otomatik .deb üretimi + ISO derleme
```

---

## 4. Kimlik ve tema

- **Tek tema: KOYU.** Açık tema yok — ne varsayılan olarak ne seçenek
  olarak. Ayarlar > Görünüm'de "Tema" seçimi bulunmaz.
- **Renkler:**

  | Rol | Değer |
  |---|---|
  | Ana vurgu (turkuaz) | `#2DD4BF` |
  | İkincil (mavi) | `#4F92F7` |
  | Vurgu degradesi | `#2DD4BF` → `#4F92F7` |
  | Zemin (masaüstü) | `#0D141B` |
  | Panel / görev çubuğu | `#121C26` |
  | Yüzey (pencere, menü) | `#17222C` |
  | Yüzey (üzerine gelince) | `#1D2C38` |
  | Kenarlık | `#233A45` |
  | Ana metin | `#E6EDF3` |
  | İkincil metin | `#8B9BA8` |
  | Başarı / uyarı / hata | `#22C55E` / `#F59E0B` / `#EF4444` |

  Turkuaz açık bir renk olduğu için üstüne gelen yazı koyu (`#0D141B`)
  olmalı, beyaz değil.
- **Logo:** el yazısı/imza tarzı "K" harfi — kalın gövde, ince kollar,
  köşeleri yuvarlatılmış koyu kare kutu (`#0F2A2C` → `#152444`) içinde,
  harf turkuaz→mavi degradeli.
  SVG olarak verilir (`assets/logo/k-logo.svg`), tüm boyutlara buradan
  türetilir.
- **İmleç teması:** özel XCursor teması (`xcursorgen` ile üretilir),
  turkuaz vurgu.
- `/etc/os-release` içinde `NAME="Karan OS"`, `PRETTY_NAME="Karan OS 1.0"`.

---

## 5. Açılış ekranı (karanos-boot)

Plymouth teması:

1. Ekran ortasında sabit bir görsel (`[BOOT_GÖRSELİ]`) — **%15 opaklıkla
   başlar**, ~1.5 saniyede %100'e çıkar ve hafif bir parlama (glow) alır
2. Görselin altında italik yazı: **made by Karan**
3. Aynı anda `[BOOT_MÜZİĞİ].mp3` çalar (ALSA sürücüsü kernel'de yerleşik olmalı;
   Plymouth'un ses desteği olmadığı için sesi erken çalışan ayrı bir systemd
   servisi yönetecek)
4. **Splash, müzik bittikten 0.5 saniye sonra kapanır.** Sistem daha erken
   hazır olsa bile açılış ekranı beklemeye devam eder — müzik yarıda
   kesilmez. Kapanmadan hemen önce görsel ve ses birlikte yumuşakça söner
   (kısa fade-out).
5. Güvenlik ağı: müzik herhangi bir sebeple çalmazsa veya ses aygıtı yoksa
   splash en fazla 10 saniye bekler, sonra yine de geçer. Sistem müzikten
   uzun sürerse (yavaş disk) splash zaten sistemi bekler; bu durumda müzik
   bir kez çalıp susar, döngüye alınmaz.
6. Boot bitince giriş ekranına geçer

**Kritik:** boot görseli ve müziği ISO'ya gömülü gelir, `/usr/share/karanos/boot/`
altında durur, sadece root yazabilir. Ne setup'ta ne ayarlarda değiştirme
seçeneği **olmayacak**.

Not: italik yazı için ya hazır PNG gömülecek ya da splash kendi framebuffer
programımızla çizilecek (Plymouth bitmap font kullandığı için italik desteği yok).
Hangisinin daha sağlam olduğuna karar verip uygula.

---

## 6. Giriş ekranı (karanos-greeter)

- Kullanıcı listesi (avatar + isim), şifre alanı
- Koyu tema (turkuaz vurgu), arka planda duvar kağıdı, sağ altta saat
- **"Şifremi unuttum" bağlantısı** şifre sıfırlama akışını başlatır.
  Gizli/sabit bir kurtarma ifadesi **yoktur** — tek sıfırlama yolu aşağıdaki
  güvenlik sorularıdır.

**Şifre sıfırlama akışı — üç bilgi sorulur, ikisi doğruysa yeter:**

1. **Doğum tarihi** — kullanıcının setup'ta seçtiği tarih (gün/ay/yıl seçici)
2. **Güvenlik sorusu 1** — setup'ta seçtiği soru ve cevabı
3. **Güvenlik sorusu 2** — setup'ta seçtiği ikinci soru ve cevabı

Üçünden **en az ikisi** doğruysa yeni şifre belirleme ekranı açılır. Böylece
bir cevabı unutsan bile sisteme kilitlenmezsin. Hangi cevabın yanlış olduğu
söylenmez, sadece "yeterli bilgi doğrulanamadı" denir.

Kurallar:
- Cevaplarda **büyük/küçük harf farkı yok**; ayrıca baştaki/sondaki boşluklar
  kırpılır ve Türkçe karakterler normalize edilirken `i/İ/ı/I` dönüşümü
  Türkçe locale'e göre değil, güvenli biçimde yapılmalı (`casefold` benzeri)
- Cevaplar düz metin saklanmaz, **hash'lenerek** saklanır
- Sorular hazır bir listeden seçilir (ilk öğretmenin adı, ilk evcil hayvanın
  adı, doğduğun şehir, en sevdiğin takım, ilkokulunun adı, annenin kızlık
  soyadı…) ve kullanıcı isterse **kendi sorusunu yazabilir**
- İki soru birbirinden farklı olmak zorunda
- Bilgiler Ayarlar > Kullanıcılar altından sonradan değiştirilebilir
- **Yanlış deneme sınırı yok** — bekletme, kilitleme veya sayaç uygulanmayacak;
  kullanıcı istediği kadar deneyebilir
- `Win+L` ile kilit ekranı (aynı görsel dil, saat + şifre)

Güvenlik burada öncelik değil; sistem kişisel kullanım için.

---

## 7. İlk kurulum sihirbazı (karanos-setup)

İlk açılışta bir kez çalışır. Adımlar:

1. **Dil + klavye düzeni** (Türkçe Q, Türkçe F, İngilizce)
2. **Saat dilimi** (otomatik algıla, onaylat)
3. **Wi-Fi bağlantısı** (sonraki adımlar internet ister)
4. **Kullanıcı adı + bilgisayar adı**
5. **Şifre belirleme**
6. **Şifre kurtarma bilgileri** — doğum tarihi + iki güvenlik sorusu ve cevabı.
   Kısa açıklama: *"Şifreni unutursan bunlarla sıfırlayabilirsin."*
7. **Vurgu rengi + duvar kağıdı**
8. **Programlar** — işaretlemeli liste, seçilenler arka planda indirilir:

```
Geliştirme
 ☑ VS Code
 ☑ Git
 ☑ C/C++ (gcc, g++, make, gdb)
 ☐ Python 3 + pip
 ☐ Java (Temurin)
 ☐ Node.js + npm
 ☐ Rust
 ☐ Go
 ☐ Arduino IDE + PlatformIO
 ☐ TurboWarp (Scratch)

Oyun & Medya
 ☐ Minecraft (Java gerekir — birlikte kurulur)
 ☐ Prism Launcher (modlu Minecraft)
 ☑ VLC
 ☐ Steam
 ☐ OBS Studio

Günlük
 ☐ LibreOffice
 ☐ GIMP + Inkscape
```

9. **Otomatik yedekleme** — "Sistem ne sıklıkta geri yükleme noktası alsın?"
   → kapalı / günlük / **haftalık (varsayılan)** / aylık.
   Kısa açıklama: *"Bir şey bozulursa sistemi eski hâline döndürebilirsin."*
10. **Özet** → "Hoş geldin, Karan OS hazır"

**Minecraft ayrı bir soru değildir** — yukarıdaki listede VS Code veya
TurboWarp gibi normal bir seçenektir. İşaretlenirse, listede altında şu uyarı
belirir: *"Minecraft için Java gereklidir, birlikte kurulacak."* ve Java satırı
otomatik işaretlenip **kilitlenir** (kullanıcı kaldıramaz). Ardından sadece
sürüm seçilir (Eclipse Temurin):

```
Hangi Java sürümü kurulsun?

 ( ) Java 21  — Uzun destekli sürüm. Modlar ve mod paketleri
                en çok bunda test edilir.            ★ önerilen
 ( ) Java 25  — Güncel uzun destekli sürüm (Eylül 2025).
                Daha hızlı, 2029'a kadar destekli.
 ( ) Java 26  — En yeni sürüm (Mart 2026). Kısa destekli,
                Eylül 2026'da desteği bitiyor.
```

- Varsayılan seçili: **Java 21**
- Minecraft seçilmediyse Java isteğe bağlıdır; hiç seçilmeyebilir
- Java 21 Debian deposunda hazır (`openjdk-21-jre`); 25 ve 26 için kurulum
  script'i Adoptium (Eclipse Temurin) deposunu otomatik ekler
- Birden fazla Java kurulu olabilir; aktif sürüm `update-alternatives` ile
  ayarlanır ve Ayarlar > Uygulamalar'dan değiştirilebilir

**Diğer kurallar:**
- Boot görseli/müziği **sorulmaz**
- Linux'ta PATH otomatik çalıştığı için PATH sorusu gereksiz — ama kurulum
  bittiğinde `gcc`, `g++`, `code`, `git` komutlarının terminalde çalıştığını
  doğrula
- İnternet yoksa program adımı atlanır, sonradan Ayarlar'dan kurulabilir

---

## 8. Masaüstü (karanos-panel)

Windows benzeri:

- **Görev çubuğu** (altta): sol altta K logosu (başlat), açık pencereler,
  sistem tepsisi (ağ, ses, pil, klavye dili TR/EN), saat
- **Başlat menüsü:** arama kutusu, kategorilere ayrılmış program listesi,
  altta güç düğmesi (kapat / yeniden başlat / oturumu kapat)
- **Masaüstü ikonları:** `pcmanfm --desktop` ile, her kullanıcının kendi
  `desktop` klasöründen. Yeni kullanıcıda masaüstünde hazır duracaklar
  (Windows tarzı): **Ayarlar**, **Terminal**, **Görev Yöneticisi**,
  **Karan OS Mağaza**, **Firefox**, **Bilgisayarım** (dosya yöneticisi) ve
  **Çöp Kutusu**. Kullanıcı bunları silebilir; Ayarlar > Görünüm altında
  "Varsayılan masaüstü simgelerini geri yükle" seçeneği olacak.
- **Kısayollar:** `Win` = başlat menüsü, `Win+E` = dosya yöneticisi,
  `Win+D` = masaüstünü göster, `Win+L` = kilitle, `Win+V` = pano geçmişi,
  `PrtSc` = ekran görüntüsü, `Ctrl+Shift+Esc` = görev yöneticisi
- **Pencere yerleştirme (snap):** `Win+←/→` pencereyi ekranın soluna/sağına
  yarım yapar, `Win+↑` tam ekran, `Win+↓` küçültür/eski boyutuna döner.
  `Win+Shift+←/→` pencereyi diğer monitöre taşır. Pencereyi fareyle ekranın
  kenarına sürüklemek de aynı işi yapar; sürükleme sırasında yerleşeceği alan
  yarı saydam bir çerçeveyle gösterilir. Köşelere sürüklemek çeyrek ekran yapar.
- **Sanal masaüstleri:** 4 masaüstü. `Win+Ctrl+←/→` ile geçiş,
  `Win+Ctrl+Shift+←/→` ile aktif pencereyi diğer masaüstüne taşıma. Görev
  çubuğunun sağında küçük bir gösterge; tıklayınca geçiş yapılır, üzerine
  gelince hangi pencerelerin olduğu görünür. (Openbox zaten destekliyor,
  panelde göstergesini biz çizeceğiz.)
- **Alt+Tab:** ekranın ortasında açık pencerelerin **küçük önizlemeleriyle**
  bir geçiş kutusu. `Alt+Tab` ileri, `Alt+Shift+Tab` geri; tuş bırakılınca
  seçilen pencere öne gelir. `Alt+\`` aynı uygulamanın pencereleri arasında
  geçiş. Sadece o anki sanal masaüstünün pencereleri listelenir (tümünü
  gösterme seçeneği ayarlarda).

---

## 9. Kullanıcılar ve dizin yapısı

```
/users/<kullanıcı>/desktop
/users/<kullanıcı>/downloads
/users/<kullanıcı>/documents
/users/<kullanıcı>/pictures
/users/<kullanıcı>/music
/users/<kullanıcı>/videos
```

- `/home` → `/users` sembolik bağı kurulacak (uyumluluk için)
- Sistem klasörü isimleri **İngilizce, küçük harf, değiştirilemez**.
  Uygulama: gerçek klasörler `/users/<kullanıcı>/.karan/<isim>` altında durur,
  girişte `/users/<kullanıcı>/<isim>` üzerine **bind mount** edilir. Böylece
  yeniden adlandırma/silme mümkün olmaz ama içine yazmak normal çalışır.
  Dosya yöneticisinde bu klasörlerin "yeniden adlandır" seçeneği devre dışı
  bırakılacak.
- Kullanıcı `/users/<kullanıcı>/` altına **kendi klasörlerini açabilir**,
  isimlerinde Türkçe karakter kullanabilir
- Kullanıcılar **birbirlerinin klasörlerine girebilir** (izinler `755`)
- **Yetki:** her kullanıcı `sudo` grubunda ve **şifresiz sudo** (`NOPASSWD`).
  Kullanıcıları gerçekten UID 0 yapma — Firefox, Chrome, VS Code root olarak
  çalışmayı reddediyor. Şifresiz sudo pratikte aynı sonucu verir.
- XDG dizinleri (`~/.config/user-dirs.dirs`) bu yapıya göre ayarlanacak

---

## 10. Ayarlar uygulaması (karanos-settings)

Solda başlık listesi, sağda içerik, üstte arama (Windows 11 tarzı).

**Görünüm** — duvar kağıdı, vurgu rengi, imleç teması ve boyutu,
yazı boyutu, görev çubuğu konumu/yüksekliği, saat formatı

**Kullanıcılar** — kullanıcı ekle/sil, avatar, şifre değiştir

**Ağ** — Wi-Fi listesi, bağlan/unut, kablolu bağlantı, IP bilgisi
- **"Kayıtlı ağlar" sekmesi:** daha önce bağlanılan tüm ağlar; her satırda
  SSID, **şifre** (varsayılan gizli, göz ikonuyla açılır), güvenlik türü
  (WPA3-SAE / WPA2-PSK / WPA-PSK / WEP / açık), frekans bandı, son bağlanma,
  otomatik bağlan anahtarı, "Unut" düğmesi
- Her satırda **QR kod göster** düğmesi (`qrencode` ile;
  `WIFI:T:WPA;S:<ssid>;P:<şifre>;;` biçimi) — telefonla okutup bağlanmak için
- Bağlantılar **sistem geneli** kaydedilecek (`psk-flags=0`), böylece tüm
  kullanıcılar şifreleri görebilir

**Bluetooth** — cihaz tara/eşleştir/kaldır, kulaklık-mouse-kumanda desteği,
pil durumu gösterimi (destekleyen cihazlarda)

**Ses** — çıkış aygıtı, seviye, mikrofon, sistem sesleri

**Ekran** — çözünürlük, yenileme hızı, ölçekleme, gece modu

**Klavye & Fare** — düzen, diller arası geçiş kısayolu, fare hızı, dokunmatik yüzey

**Pil ve şarj (laptop)** — panelde pil simgesi: doluluk yüzdesi, şarjda ise
şarj simgesi/animasyonu, üzerine gelince **kalan süre tahmini**
("2 sa 15 dk kaldı" / "%80 — tam dolmasına 25 dk"). Tıklayınca küçük panel
açılır: güç profili (performans / dengeli / tasarruf) ve pil ayarlarına
kısayol. Bildirimler: **%20'de** uyarı, **%10'da** ikinci uyarı, **%5'te**
otomatik uyku/hazırda bekletme (ayarlardan değiştirilebilir). Ayarlar >
Sistem > Donanım bilgisinde **pil sağlığı** (tasarım kapasitesi / şu anki
kapasite, şarj döngüsü sayısı) gösterilir. Masaüstü bilgisayarda pil simgesi
ve bu bölüm hiç görünmez.

**Güç** — ekran kapanma süresi, uyku süresi, kapak kapanınca ne olsun
(uyku / kapat / hiçbir şey), pil yüzdesini panelde göster, ısınma koruması
eşikleri. **Laptop yoksa bu bölüm hiç gösterilmez** (masaüstünde sistem her
zaman tam performansta çalışır).

**Güç planları (yalnızca laptop):** üç profil var — **Tam performans**,
**Normal**, **Tasarruf**. Sistem şarj durumuna ve pil yüzdesine göre otomatik
geçiş yapar; **varsayılan kurallar** şöyle:

| Durum | Pil | Profil |
|---|---|---|
| Şarjda | %50 üstü | Tam performans |
| Şarjda | %50 altı | Normal |
| Şarjda değil | %50 üstü | Normal |
| Şarjda değil | %50 altı | Tasarruf |

- Kullanıcı bu eşleşmeyi **kendisi değiştirebilir**: "şarjdayken" ve "şarjda
  değilken" için ayrı ayrı profil seçer, isterse yüzde eşiğini de değiştirir
  (varsayılan %50).
- "Otomatik geçişi kapat" seçeneği olacak; kapatılırsa tek bir sabit profil
  kullanılır. Panelde pil ikonuna tıklayarak da profil elle seçilebilir.
- Profillerin yaptıkları: **Tam performans** — CPU performans yöneticisi,
  ekran parlaklığı düşürülmez, uyku uzun. **Normal** — dengeli yönetici,
  orta parlaklık. **Tasarruf** — güç tasarrufu yöneticisi, parlaklık kısılır,
  ekran daha çabuk kapanır, arka plan güncelleme kontrolleri ertelenir.
- Altta `tlp`/`power-profiles-daemon` gibi hazır bir araç kullanılacak.

**Ek sürücüler** — sistemdeki ekran kartını ve diğer donanımı tarar, uygun
tescilli sürücüyü (Nvidia, AMD) bulur ve tek tıkla kurar. Hangi sürücünün
kullanıldığını gösterir, açık kaynak sürücüye geri dönme seçeneği sunar.

**Yazıcılar** — CUPS üzerinden yazıcı ekle/kaldır, test sayfası yazdır

**Uygulamalar** — kurulu programlar + kaldır, setup'ta atlanan programları kur
(Minecraft, Steam, VS Code…), varsayılan uygulamalar, başlangıçta çalışanlar

**Sistem**
- Karan OS hakkında (sürüm, K logosu, "made by Karan")
- **Donanım bilgisi** — kullanıcı kendi sistemini eksiksiz görsün:
  - İşlemci: model, çekirdek/iş parçacığı sayısı, temel ve anlık frekans (GHz),
    önbellek, mimari, anlık kullanım
  - RAM: toplam boyut, kullanılan/boş, tip (DDR4/DDR5), hız (MHz), takılı modül
    sayısı ve her yuvanın durumu
  - Anakart: üretici, model, BIOS/UEFI sürümü ve tarihi
  - Ekran kartı: model, VRAM, kullanılan sürücü
  - Depolama: her disk için model, boyut, tip (NVMe/SSD/HDD), sağlık durumu (SMART)
  - Ağ: kablolu/kablosuz kart modelleri, MAC adresleri
  - Ekran: bağlı monitörler, çözünürlük, yenileme hızı
  - Pil (laptop'ta): üretici, tasarım kapasitesi, şu anki tam kapasite,
    **pil sağlığı (%)**, şarj döngüsü sayısı, anlık şarj durumu
  - Sistem: çekirdek sürümü, açık kalma süresi, ana kart seri no
  - "Bilgileri kopyala" düğmesi (yardım isterken yapıştırmak için)
  - Veri kaynağı: `lscpu`, `dmidecode`, `lsblk`, `lspci`, `/proc`, `/sys` —
    ek ağır bağımlılık kurmadan
- **Güncellemeler:** "Güncellemeleri denetle" → liste → "Güncelle".
  Güncelleme başlamadan **önce otomatik btrfs snapshot** alınır.
- **Temizlik:** `apt autoremove` + `apt clean`, kazanılan alanı MB olarak göster
- **Yedek al:** Timeshift ile anlık snapshot
- **Otomatik geri yükleme noktaları:** sistem belirli aralıklarla kendiliğinden
  snapshot alır. Aralığı kullanıcı seçer: *kapalı / günlük / haftalık / aylık*
  (varsayılan: haftalık). Ayrıca her `apt` işleminden önce her hâlükârda bir
  snapshot alınır. Kaç snapshot saklanacağı ve toplam disk kullanımı burada
  gösterilir; tek tek silinebilir. Listeden herhangi birine "Geri dön"
  denebilir.
- **Geliştirici modu:** kapalı gelir. Açıkken "Kaynağı güncelle" düğmesi
  çıkar — panel/ayarlar deposunu `git pull` yapıp bileşenleri yeniden başlatır

⚠️ Ayarlarda **"Açılış" bölümü olmayacak** — boot görseli ve sesi sabittir.

Ağ, ses, ekran ve güç kısımlarında altta NetworkManager, PipeWire, xrandr ve
logind kullanılacak; sıfırdan yazma yok, sadece kendi arayüzümüz.

---

## 11. Karan OS Mağaza (karanos-store)

Grafik uygulama mağazası. Kullanıcı terminale hiç dokunmadan program kursun.
Tasarım referansı: **Pardus Mağaza** — sol tarafta kategori listesi, sağda
ikonlu uygulama kartları, üstte arama kutusu.

**Çalışma mantığı:** Basınca arka planda `apt` komutu çalışır (PolicyKit
üzerinden), ilerleme çubuğu gösterilir, kullanıcı hiç komut görmez.
Düğme uygulamanın durumuna göre değişir:

| Durum | Düğme(ler) |
|---|---|
| Kurulu değil | **Yükle** |
| Kurulu, güncel | **Sil** (+ küçük "Aç" düğmesi) |
| Kurulu, güncellemesi var | **Güncelle** ve yanında **Sil** |
| İşlem sürüyor | ilerleme çubuğu + **İptal** |

Kurulum biter bitmez düğme "Yükle"den "Sil"e dönmeli — sayfayı yenilemeye
gerek kalmadan.

**Kategoriler:**

| Kategori | Örnek uygulamalar |
|---|---|
| Oyun | Steam, Minecraft (Java 21/25/26), Prism Launcher, Lutris, SuperTuxKart, 0 A.D., RetroArch |
| Kod editörü & geliştirme | VS Code, Vim, Neovim, Geany, Arduino IDE, PlatformIO, Git, Docker, Thonny, Android Studio |
| Diller & derleyiciler | **C/C++ (gcc, g++, make, cmake, gdb)**, **Java (Temurin 21 / 25 / 26)**, Python 3 + pip, Node.js + npm, Rust, Go, PHP, Lua, .NET SDK |
| İnternet | Firefox, Chromium, Thunderbird, qBittorrent, FileZilla, Telegram |
| Medya | VLC, MPV, Audacity, OBS Studio, Kdenlive, Spotify |
| Grafik & tasarım | GIMP, Inkscape, Krita, Blender, darktable |
| Ofis & eğitim | LibreOffice, Okular, Calibre, GeoGebra, Anki, TurboWarp (Scratch), Stellarium |
| Sistem & araçlar | GParted, Timeshift, htop, neofetch, BleachBit, balenaEtcher, VirtualBox, Flameshot |
| Güvenlik & ağ | nmap, Wireshark, Burp Suite Community, tcpdump, netcat, iperf3, Angry IP Scanner, ClamAV, KeePassXC |

**Gereken davranışlar:**

- **Küratörlü katalog GitHub'dan iner:** ISO'ya sadece mağaza programı
  (~5 MB) ve boş bir katalog gömülür. Katalog dosyası (ikonlar + Türkçe
  açıklamalar + paket adları + kategoriler) ilk açılışta GitHub'dan indirilip
  `/var/cache/karanos/store/` altına yazılır; mağaza her açılışta yeni sürüm
  var mı diye bakar. Böylece ISO şişmez ve yeni uygulama eklemek için sistem
  güncellemesi gerekmez — GitHub'daki katalog dosyasını değiştirmek yeter.
  İnternet yoksa mağaza "Katalog indirilemedi" der ama arama yine çalışır.
- **Arama tüm Debian deposunu kapsar:** katalogda olmayan bir şey aransa bile
  (`wireshark`, `htop`…) `apt-cache` üzerinden bulunup kurulabilmeli.
- **apt dışındaki kurulum yolları da desteklenecek.** Katalogdaki her kaydın
  bir `type` alanı olacak ve mağaza buna göre davranacak:

  | type | Ne yapar | Örnek uygulamalar |
  |---|---|---|
  | `apt` | Debian deposundan kurar | nmap, VLC, GIMP, htop |
  | `apt-repo` | Önce harici depoyu + GPG anahtarını ekler, sonra kurar | VS Code, Steam, Spotify, Temurin Java |
  | `deb-url` | Belirtilen adresten `.deb` indirir, doğrular, kurar | Minecraft launcher, TurboWarp, Prism Launcher |
  | `appimage` | AppImage indirir, `/opt/karanos-apps/` altına koyar, çalıştırma izni verir, menü kısayolu oluşturur | Arduino IDE 2, Obsidian, balenaEtcher |
  | `tarball` | Arşivi indirip `/opt/` altına açar, kısayol ve gerekirse `PATH` girdisi oluşturur | Burp Suite Community, Android Studio, Ghidra, Postman |
  | `flatpak` | Flatpak olarak kurar (yalnızca başka yolu olmayan uygulamalarda) | — |

- **apt dışı kurulumlarda da "Sil" ve "Güncelle" çalışmalı.** Mağaza kendi
  kurduğu her uygulamayı bir kayıt dosyasında tutacak (ad, sürüm, tür, dosya
  yolları, kaynak adres). Silme bu kayda göre yapılacak; güncelleme kontrolü
  için kaynak adresteki sürüm numarası karşılaştırılacak. Kayıtsız/manuel
  kurulmuş şeylere dokunulmayacak.
- İndirilen dosyalar mümkün olduğunda **sha256 ile doğrulanacak**; doğrulama
  başarısızsa kurulum yapılmayacak.
- Java gerektiren uygulamalarda (Burp Suite, Ghidra) Java kurulu değilse
  mağaza bunu tespit edip bağımlılık olarak kuracak.
- **Arama tüm Debian deposunu kapsayacak** — katalogda olmayan bir paket
  (`iperf3`, `sqlmap`, `ffmpeg`…) aransa bile `apt-cache` üzerinden bulunup
  kurulabilmeli. Yani mağaza kapalı bir liste değil, `apt`'ın tamamının
  grafik arayüzü.
- **Kurulum kuyruğu:** birden fazla uygulama sıraya alınabilsin.
- **"Kurulu uygulamalarım" sekmesi:** kurulu olanlar listelensin, kaldırılabilsin.
- **Setup ile ortak kaynak:** ilk kurulum sihirbazındaki program listesi de
  aynı katalog dosyasından beslenecek — iki yerde ayrı liste tutulmayacak.
- Başlat menüsünde ve görev çubuğunda kısayolu olacak.
- **Kurulan her uygulama masaüstüne de kısayol bırakacak** (Windows tarzı).
  Kısayol kullanıcının `desktop` klasörüne `.desktop` dosyası olarak yazılır,
  doğru ikonla. Kullanıcı istemezse Ayarlar > Görünüm altından
  "Kurulan uygulamaları masaüstüne ekle" seçeneği kapatılabilir. Uygulama
  silinince kısayolu da silinir.
- Diller/derleyiciler gibi arayüzü olmayan paketler için masaüstü kısayolu
  oluşturulmaz (gcc'nin kısayolu anlamsız olur).

---

## 12. Görev yöneticisi (karanos-taskmanager)

`Ctrl+Shift+Esc` **veya görev çubuğuna sağ tık → "Görev Yöneticisi"** ile açılır.
Altta `psutil` + `lm-sensors`.

**İki görünüm modu:**
- **Basit** — sadece açık uygulamalar ve "Görevi sonlandır" düğmesi. Küçük
  pencere, karmaşa yok. Donan bir programı kapatmak isteyen buraya bakar.
- **Detaylı** — aşağıdaki tüm sekmeler. Seçim hatırlanır.

**Sekmeler (detaylı mod):**

1. **İşlemler** — üstte "Uygulamalar" (açık pencereler), altta "Arka plan
   işlemleri". Sütunlar: ad, CPU %, RAM, disk, ağ, PID, kullanıcı. Sütun
   başlığına tıklayınca sıralama. En çok kaynak yiyen satırlar renkle
   vurgulanır. Yanıt vermeyen pencereler **"Yanıt vermiyor"** etiketiyle
   işaretlenir (X11'de `_NET_WM_PING` ile tespit).
2. **Performans** — solda CPU / RAM / Disk / Ağ / GPU listesi, seçilene göre
   sağda büyük grafik. CPU'da çekirdek başına ayrı grafik, anlık frekans (GHz),
   açık kalma süresi. **Sıcaklıklar bu sekmede gösterilir** (ayrı sekme yok):
   ilgili bileşenin grafiğinin altında CPU çekirdek sıcaklıkları, GPU
   sıcaklığı, NVMe sıcaklığı ve fan hızları (RPM), renk kodlu —
   yeşil < 70 °C, sarı 70–85 °C, kırmızı > 85 °C.
   **GPU kullanımı gösterilecek:** Nvidia'da `nvidia-smi`, AMD/Intel'de
   `/sys/class/drm/.../gpu_busy_percent` üzerinden. Okunamıyorsa "desteklenmiyor"
   yazılacak, boş grafik gösterilmeyecek.
3. **Başlangıç** — açılışta çalışan programlar, aç/kapa anahtarı, tahmini
   etkisi (düşük/orta/yüksek).
4. **Kullanıcılar** — oturum açmış kullanıcılar ve kaynak kullanımları.

**Sağ tık menüsü:** görevi sonlandır, zorla sonlandır (SIGKILL), önceliği
değiştir, dosya konumunu aç, işlem ağacını göster.

**Diğer:**
- **Yenileme aralığı seçilebilir:** 1 sn / 2 sn / 5 sn — varsayılan **2 sn**
  (hafiflik için). Pencere arka plandayken yenileme yavaşlatılır.
- Sistem için kritik bir işlem sonlandırılmak istenirse uyarı çıkar;
  normal uygulamalarda onay sorulmaz.

**Aşırı ısınma koruması** (arka planda çalışan küçük bir servis):

- 85 °C'yi geçince masaüstünde uyarı bildirimi: hangi bileşen, kaç derece,
  o an en çok CPU yiyen işlem hangisi
- 90 °C'yi geçip 60 saniye orada kalırsa ikinci, daha sert uyarı + isteğe bağlı
  "performans yerine serinlik" güç profiline geçiş (CPU frekans sınırı)
- Eşikler ve otomatik davranış Ayarlar > Güç altından değiştirilebilir,
  tamamen kapatılabilir
- **Not:** donanımın kendi koruması (kernel thermal throttling ve kritik
  sıcaklıkta ACPI kapatma) zaten en alttaki güvenlik ağıdır; bizim
  yaptığımız onun yerine geçmez, sadece kullanıcıyı erken uyarır.
  Kendi kapatma mantığımızı kernel'in kritik eşiğinin altında tutma.
- Intel işlemcilerde `thermald` kurulu gelecek

---

## 12-B. Paket Kurucu (karanos-deb-installer)

`.deb` dosyalarını çift tıklayarak kurmak için küçük, tek pencerelik bir
uygulama. Adı: **Paket Kurucu** / *Package Installer*.

- ISO'ya gömülü gelir (mağaza dışı uygulamalar için gerekli), ayrıca
  Karan OS Store'da da listelenir
- `.deb` dosyalarının **varsayılan uygulaması** olarak kaydedilir — dosya
  yöneticisinde çift tıklayınca açılır
- Pencere içeriği:
  - Dosya seçme alanı ("Gözat" düğmesi + sürükle-bırak desteği)
  - Seçilen paketin bilgileri: ad, sürüm, boyut, kısa açıklama, bağımlılıklar
  - **Kur** ve **İptal** düğmeleri
  - Kurulum sırasında ilerleme çubuğu ve "Ayrıntıları göster" ile çıktı
- Eksik bağımlılıklar varsa uyarır ve depodan otomatik kurar
  (`apt install -f` mantığı)
- Paket zaten kuruluysa düğme **Yeniden kur** veya **Sil** olur; daha yeni
  sürümse **Güncelle** olur
- Mimarisi uyumsuz (i386/arm) veya bozuk paketlerde net hata verir, kurmaz
- Kurulum, 19. bölümdeki **merkezi paket işlemleri servisi** üzerinden geçer —
  aynı anda mağaza kurulum yapıyorsa sıraya girer

---

## 12-C. Dosya yöneticisi sağ tık menüsü

Windows'tan gelen biri sağ tıkladığında aradığı her şeyi bulmalı. `pcmanfm`
menüsü özelleştirilecek (özel eylemler `.desktop` dosyalarıyla eklenir):

**Dosya/klasöre sağ tık:**
Aç · Birlikte aç ▸ · **Yönetici olarak aç** · Kes · Kopyala · Yapıştır ·
Kısayol oluştur · Masaüstüne gönder · Yeniden adlandır · Sil ·
Sıkıştır (zip/tar.gz) · Buraya çıkart · **Burada terminal aç** ·
**Burada yönetici terminali aç** · **Özellikler**

**Boş alana sağ tık:**
Yeni klasör · Yeni dosya · Yapıştır · Görünüm ▸ · Sırala ▸ ·
Burada terminal aç · Duvar kağıdını değiştir (masaüstünde)

**Özellikler penceresi:** ad, tür, konum, boyut, içerik sayısı, oluşturma ve
değiştirme tarihi, sahip/grup, izinler (okuma/yazma/çalıştırma kutuları),
"Bu dosyayı açacak uygulama" seçimi, klasörlerde disk kullanımı.

**"Yönetici olarak aç"** `pkexec` ile dosya yöneticisini/editörü yükseltilmiş
yetkiyle açar. Bunu yalnızca dosya yöneticisi ve metin editörü için sun;
tarayıcı gibi uygulamalarda gösterme (root olarak çalışmayı reddederler).
İşlem öncesi kısa bir onay penceresi çıksın.

**Sistem klasörlerinde** (`desktop`, `documents`, `downloads`…) "Yeniden
adlandır" ve "Sil" seçenekleri gri/gizli olacak — 9. bölümdeki koruma kuralı.

---

## 13. Küçük araçlar (karanos-tools)

- **Ekran görüntüsü / ekran kaydı** — Windows'un Snipping Tool'una benzer
  tek bir araç:
  - `PrtSc`'ye basılınca ekran karartılır ve **alan seçme** moduna girilir.
    Üstte küçük bir araç çubuğu belirir: **Görsel | Video** geçişi, seçim
    biçimi (alan / pencere / tüm ekran), zamanlayıcı (0/3/5 sn), ayarlar
    ve iptal (`Esc`).
  - Mod geçişi seçim yapılırken de değiştirilebilir; **seçilen alan her iki
    modda da aynı şekilde kullanılır** — görselde o alanın fotoğrafı, videoda
    o alanın kaydı alınır.
  - **Görsel:** panoya kopyalanır ve `pictures/screenshots/` altına kaydedilir.
    Kaydedince küçük bir bildirim çıkar; bildirime tıklayınca dosya açılır.
  - **Video:** kayıt başlar ve ekranın üst ortasında küçük, sürüklenebilir bir
    **kayıt çubuğu** belirir: kırmızı nokta, **geçen süre** (`00:42` biçiminde,
    kaydın başladığı andan itibaren), **Durdur** düğmesi ve duraklat düğmesi.
    Bu çubuk kayda dahil edilmez.
  - Kaydı durdurmanın iki yolu vardır: **Durdur düğmesi** veya **tekrar
    `PrtSc`**. Dosya `videos/recordings/` altına kaydedilir.
  - `Win+Alt+R` seçim ekranını atlayıp tüm ekranın kaydını doğrudan
    başlatır/durdurur.
  - Ayarlar: ses kaydı açık/kapalı, imleci göster/gizle, kare hızı (30/60),
    kayıt biçimi (MP4/WebM), kayıt sırasında görev çubuğunda gösterge.
  - Altta `ffmpeg`/`wf-recorder` benzeri hafif bir araç kullanılacak.
- **Pano geçmişi:** `Win+V`, son 20 kopyalanan öğe
- **Bildirim merkezi:** sağ altta bildirimler, geçmiş paneli, "rahatsız etme" modu
- **Ses/parlaklık OSD:** tuşa basınca ekranın ortasında/üstünde kaybolan bar
- **USB:** takılınca bildirim, tepside "güvenle çıkar"
- **Pil göstergesi (laptop):** görev çubuğunda pil ikonu + yüzde. Üzerine
  gelince kalan süre tahmini ("2 sa 15 dk kaldı") ve şarj durumu görünür.
  Şarja takılınca ikon değişir ve kısa bir bildirim çıkar. **%20**'de uyarı,
  **%10**'da daha sert uyarı + pil tasarrufu moduna geçme önerisi, **%5**'te
  otomatik uyku (ayarlardan değiştirilebilir). Masaüstü bilgisayarda pil
  ikonu hiç gösterilmez.
- **Yazı tipi kurucu:** `.ttf`/`.otf` dosyasına çift tıklayınca açılır;
  yazı tipinin önizlemesi (alfabe + örnek cümle, Türkçe karakterler dahil),
  ad/sürüm bilgisi ve **Yükle** düğmesi. Kurulunca "Kaldır" olur.
- **Düşük disk alanı uyarısı:** boş alan %10'un altına düşünce bildirim
  çıkar; bildirimde "Temizlik yap" ve "Geri yükleme noktalarını yönet"
  kısayolları olur (btrfs snapshot'lar sessizce yer kaplar). %5'in altında
  daha sert uyarı verilir.
- **Kısayol listesi:** `Win+/` ile tüm klavye kısayollarını kategorilere
  ayrılmış hâlde gösteren pencere. Ayarlar > Klavye altından da açılabilir.
- **USB biçimlendirme:** dosya yöneticisinde veya tepside sağ tık →
  "Biçimlendir". Küçük pencere: aygıt adı, dosya sistemi seçimi
  (FAT32 / exFAT / ext4 / NTFS), etiket, hızlı biçimlendirme kutusu,
  Biçimlendir/İptal. Silme uyarısı ve onay zorunlu. Sistem diski ve
  o an çalışılan aygıt listede **çıkmayacak**.
- **Karşılama uygulaması:** ilk girişte açılır, kısa tanıtım turu
  (başlat menüsü, ayarlar, güncelleme, dosya yapısı), "bir daha gösterme" kutusu

---

## 14. Kurulum aracı, canlı mod ve kurtarma ortamı

Calamares tabanlı, Karan OS markalamalı. Türkçe ve İngilizce.

**Canlı (live) mod:** USB'den boot edilince ilk ekranda iki seçenek çıkar:
**"Karan OS'u kur"** ve **"Kurmadan dene"**. Deneme modunda sistem RAM'den
çalışır, masaüstü tam işlevlidir, Wi-Fi ve donanım test edilebilir; masaüstünde
"Karan OS'u kur" kısayolu durur.

**Adım 0 — Sistem kontrolü (özel modül):** Sorun yoksa hiç görünmez.
Tespit edilecekler ve **teknik terim kullanmadan**, ekran görüntüsü eşliğinde
anlatılacaklar:

- Diskte yeterli boş alan var mı
- Diskte başka işletim sistemi/veri var mı (varsa **silinecek** uyarısı)
- **Windows Hızlı Başlatma açık mı** → açıksa Windows dosyalarına yazılamaz;
  nasıl kapatılacağı adım adım anlatılır, ama kurulum engellenmez
- **Secure Boot** → Debian'ın imzalı çekirdeğini kullandığımız için hiçbir şey
  yapılmasına gerek yok. Kullanıcıya sorulmayacak, UEFI ayarlarına girmesi
  istenmeyecek, kapatılması önerilmeyecek.
- **BitLocker** → dual boot desteklenmediği ve bölüm küçültme yapılmadığı için
  konu dışı; kullanıcıya sorulmayacak.
- **Windows Hızlı Başlatma** → yalnızca kurulumdan sonra başka bir diskteki
  Windows bölümüne erişilmek istenirse önemlidir. Kurulum sırasında engel
  değildir; gerekirse sistem kullanılırken sade bir bilgi notu gösterilir.

**Disk seçimi — kullanıcı yalnızca hangi diske kurulacağını seçer.**
Bölüm küçültme, yanına kurma, bölüm boyutu ayarlama gibi adımlar yok.
Seçilen disk **tamamen silinir** ve baştan sona Karan OS'a ayrılır
(EFI + btrfs kök + swap otomatik oluşturulur). **Diğer disklere hiç
dokunulmaz.**

Ekran, takılı diskleri listeler; her satırda:
- Disk modeli ve boyutu (örn. *Samsung 970 EVO — 500 GB*)
- Bağlantı tipi (NVMe / SATA / USB)
- Üzerinde ne olduğu (örn. *Windows 11 kurulu*, *veri diski*, *boş*)
- Sistemin şu an çalıştığı USB açıkça işaretlenir ve seçilemez

Seçtikten sonra **büyük ve net bir uyarı** çıkar: hangi disk, üzerinde ne var,
her şeyin silineceği. Kullanıcı onay kutusunu işaretlemeden "Kur" düğmesi
aktifleşmez. Yedek alma hatırlatması yapılır.

### Windows'la yan yana yaşama kuralları

Sistemde başka bir diskte Windows varsa şu iki davranış **zorunlu**:

**1. Karan OS diski Windows'ta görünmesin.** Karan OS bölümlerine GPT
"otomatik bağlama yok / sürücü harfi atama" özniteliği (bit 63,
`0x8000000000000000`) verilecek; ayrıca `msftdata` yerine doğru Linux bölüm
tipi GUID'leri kullanılacak. Böylece Windows bu diske sürücü harfi vermez,
Gezgin'de görünmez ve *"Diski biçimlendirmeniz gerekiyor"* uyarısı çıkmaz.
Disk Yönetimi'nde yine görünür (bu engellenemez) ama dokunulmaz durur.
Not: bunun bir güvenlik önlemi değil, kaza önleme olduğunu unutma —
yönetici yetkisiyle isteyen yine de biçimlendirebilir.

**2. Varsayılan açılış Windows kalsın.** Kurulum, UEFI açılış sırasını
**değiştirmeyecek**: `efibootmgr` ile Karan OS girdisi oluşturulacak ama
sıranın **sonuna** eklenecek, mevcut sıra korunacak (`efibootmgr -o` ile eski
sıra geri yazılacak). Bilgisayar normalde açıldığında Windows gelecek;
Karan OS'a girmek için açılışta F12 (üreticiye göre F8/F9/Esc) ile açılış
menüsünden seçilecek. Kurulum bittiğinde bu, kullanıcıya tek cümleyle
açıklanacak.

Diskte Windows yoksa Karan OS normal şekilde varsayılan açılış olur.

**İkinci diske kurulum:** Kullanıcı Windows'u başka bir diskte tutmak isterse
Karan OS'u ikinci bir SSD'ye kurabilir. Bu durumda Windows diski hiç
etkilenmez. GRUB'a çift sistem menüsü **eklenmez**; hangi sistemle açılacağı
anakartın açılış menüsünden (genelde F12) veya UEFI'deki açılış sırası
ayarından seçilir. Kurulum sonunda bu, kullanıcıya sade bir cümleyle
açıklanır.

Bölümleme: EFI (FAT32, 512 MB) + kök (btrfs, `@` ve `@users` alt birimleri) + swap.
NTFS bölümleri okuma/yazma erişilebilir olacak ve dosya yöneticisinde görünecek.

### Kurtarma ortamı (karanos-recovery)

Windows'un kurtarma ekranının karşılığı. GRUB menüsünde **"Karan OS
(Kurtarma)"** girişi olacak; sistem üst üste iki kez açılamazsa **kendiliğinden**
buraya düşecek. Ayrı, küçük bir başlangıç ortamı — grafik arayüzlü, Türkçe,
fare ile kullanılabilir:

- **Geri yükleme noktasına dön** — snapshot listesi (tarih + boyut), seç ve dön
- **Güvenli mod** — temel sürücüler, düşük çözünürlük, ek servisler kapalı;
  ayrıca **ağ ile güvenli mod** seçeneği
- **Açılışı onar** — GRUB'u yeniden kur, `fsck`/btrfs kontrolü çalıştır
- **Dosyalarımı kurtar** — dosya yöneticisi açar, `/users` altındaki dosyaları
  USB'ye kopyalamaya izin verir (sistem açılmasa bile)
- **Şifreyi sıfırla** — kullanıcı seç, yeni şifre belirle (kurtarma ortamı
  fiziksel erişim gerektirdiği için burada soru sorulmaz)
- **Terminal** — ileri seviye kullanıcı için
- **Sistem bilgisi / günlükler** — son hata kayıtlarını gösterir

Kurtarma ortamı ayrı bir btrfs alt biriminde veya EFI bölümünün yanında
tutulacak, sistem bozulsa bile açılabilmeli.

---

## 15. Paketleme, depo ve dağıtım

- Her bileşen ayrı `.deb`; `karanos-desktop` meta paketi hepsini bağlar
- `aptly` ile APT deposu üretilecek, **GitHub Pages**'te yayınlanacak,
  GPG anahtarıyla imzalanacak
- Sistemde: `/etc/apt/sources.list.d/karanos.list` →
  `deb https://[GITHUB_KULLANICI].github.io/karanos-repo stable main`
- **GitHub Actions:** sürüm etiketi (`v1.3`) atılınca otomatik olarak
  `.deb`'leri üretir, depoyu günceller, ISO'yu derler ve Releases'e yükler
- Böylece kurulu sistemler panel/ayarlar güncellemelerini normal
  `apt upgrade` ile alır

---

## 16. ISO içeriği

**Gömülü gelecek:** çekirdek, X11 + Openbox, karanos-* paketleri (mağaza
programı dahil — ama kataloğu ve ikonları hariç), Python/GTK bağımlılıkları,
NetworkManager, PipeWire, **Firefox ESR**, **CUPS (yazıcı)**, **BlueZ
(Bluetooth)** ve **kurtarma ortamı**.

**Temel aksesuarlar da gömülü gelecek** (hepsi Debian deposunda hazır, sadece
temaya uydurulacak): terminal, dosya yöneticisi, metin editörü, arşiv
yöneticisi, **hesap makinesi**, **resim görüntüleyici**, **PDF okuyucu**,
basit **medya oynatıcı**. Yeni kurulan sistemde bir PNG'ye veya PDF'e çift
tıklayınca bir şey açılmalı; bunlar olmadan ilk izlenim kötü olur.

**Saat/tarih:** NTP senkronu (`systemd-timesyncd`) açık gelecek.

**Firmware — zorunlu:** `firmware-linux`, `firmware-iwlwifi`,
`firmware-realtek`, `firmware-atheros`, `firmware-misc-nonfree` ve Mesa
sürücüleri ISO'ya gömülecek (~200 MB). Bunlar olmazsa kurulumdan sonra Wi-Fi
veya ekran kartı çalışmayabilir ve kullanıcı internetsiz kalır — bu yüzden
"küçük ISO" hedefinin istisnasıdır. Tescilli Nvidia/AMD sürücüleri gömülmez,
Ayarlar > Ek sürücüler'den sonradan kurulur.

**Gömülmeyecek:** VS Code, Steam, Minecraft, LibreOffice, GIMP/Inkscape,
Arduino IDE, TurboWarp, OBS, Prism Launcher — hepsi setup'ta seçilirse internetten iner.

Firefox tek istisna: internet çalışmazsa kullanıcının elinde bir tarayıcı olsun diye.

---

## 17. Geliştirme sırası

Her aşama bitince QEMU'da test edilip doğrulanacak, sonra diğerine geçilecek:

1. `live-build` ile boot eden çıplak ISO (X11 + Openbox + terminal)
2. Tema paketi: renkler, K logosu, imleç, GTK teması
3. Boot splash (görsel + parlama + mp3)
4. Panel: görev çubuğu + başlat menüsü
5. Giriş ekranı + kurtarma ifadesi + kilit ekranı
6. Kullanıcı/dizin yapısı + bind mount koruması
7. Setup sihirbazı
8. Ayarlar uygulaması (önce Görünüm, Ağ, Sistem; sonra gerisi)
9. Karan OS Mağaza (program + GitHub kataloğu)
10. Görev yöneticisi + küçük araçlar
11. Calamares kurulum aracı + canlı mod + sistem kontrol modülü
12. Kurtarma ortamı (snapshot geri dönüş, güvenli mod, açılış onarımı)
13. APT deposu + GitHub Actions
14. Gerçek donanımda test (laptop dahil: pil, kapak, Bluetooth, Wi-Fi)

---

## 18. Kabul kriterleri

- ISO QEMU'da ve gerçek donanımda boot ediyor, ISO 1.5 GB'ın altında
- Secure Boot açıkken kurulum ve boot çalışıyor
- Kurulum, silinecek diski ve verileri net biçimde uyarmadan devam etmiyor
- Seçilmeyen disklere hiç dokunulmuyor; ikinci diske kurulumda diğer diskteki
  sistem sağlam kalıyor
- Windows açıldığında Karan OS diskine sürücü harfi verilmiyor, biçimlendirme
  uyarısı çıkmıyor
- Windows varsa bilgisayar varsayılan olarak Windows'a açılıyor; Karan OS
  açılış menüsünden seçilebiliyor
- Boot ekranı görsel + parlama + ses ile eksiksiz çalışıyor
- "Şifremi unuttum" akışı, üç bilgiden ikisi doğru olduğunda şifre değiştirmeye izin veriyor
- Sistem klasörleri yeniden adlandırılamıyor; kullanıcı klasörleri Türkçe isim alabiliyor
- `sudo apt install wireshark` gibi komutlar çalışıyor
- Kayıtlı ağlar sekmesi şifreleri ve QR kodları gösteriyor
- Mağazadan "Yükle" ile kurulan uygulama terminale dokunmadan çalışır hale geliyor
- `apt upgrade` öncesi otomatik snapshot alınıyor, boot menüsünden geri dönülebiliyor
- Seçilen aralıkta otomatik geri yükleme noktası alınıyor
- USB'den "kurmadan dene" modu tam çalışıyor
- Sistem iki kez açılamazsa kurtarma ortamına kendiliğinden düşüyor; oradan
  snapshot'a dönmek, güvenli moda girmek ve dosya kurtarmak mümkün
- Wi-Fi ve ekran kartı kurulumdan hemen sonra çalışıyor (firmware gömülü)
- Laptop'ta pil göstergesi, uyku ve kapak davranışı çalışıyor
- Bluetooth kulaklık ve fare eşleşiyor

---

## 19. Sağlamlık ve hata önleme

Bu sistem günlük kullanılacak; yarım çalışan bir özellik hiç olmamasından
kötüdür. Aşağıdakiler zorunlu:

**Aynı işlemin iki kez çalışması engellenecek** (en sık karşılaşılacak hata):

- Tüm paket işlemleri (mağaza, güncelleme aracı, setup, ek sürücüler) **tek bir
  merkezi servis** üzerinden geçecek. Bu servis bir kuyruk tutar; aynı anda tek
  bir `apt` işlemi çalışır, ikinci istek kuyruğa girer.
- `dpkg`/`apt` kilidi kontrol edilecek; kilit meşgulse kullanıcıya
  *"Başka bir kurulum sürüyor, sıraya alındı"* denecek — hata verilmeyecek,
  sessizce ikinci bir işlem başlatılmayacak.
- Düğmeye basılır basılmaz düğme devre dışı kalacak (debounce); çift tıklama
  iki kurulum başlatmayacak.
- Aynı paket zaten kuyruktaysa tekrar eklenmeyecek.
- Her işlem **idempotent** olacak: zaten kurulu bir paketi kurmak, zaten
  kaldırılmış bir paketi kaldırmak hata değil, sessiz geçiş olacak.

**Uygulamalar tek örnek (single instance) çalışacak** — mağaza, ayarlar, görev
yöneticisi ikinci kez açılmaya çalışılırsa yeni pencere açılmayacak, var olan
pencere öne getirilecek.

**Yarım kalan işlemler:**

- İndirme kesilirse: zaman aşımı, otomatik yeniden deneme (3 kez), sonra
  anlaşılır bir hata; sistem tutarsız durumda bırakılmayacak
- Açılışta `dpkg --configure -a` kontrolü — elektrik kesintisi gibi bir durumda
  yarım kalan kurulum otomatik toparlanacak
- İnternet yokken mağaza/güncelleme çökmeyecek, sade bir uyarı gösterecek

**Genel kurallar:**

- Arayüz asla donmayacak: uzun işlemler ayrı iş parçacığında/süreçte çalışacak,
  ilerleme gösterilecek, iptal edilebilecek
- Durum değişikliği sonrası arayüz kendini yenileyecek (kurulum bitince düğme
  anında "Sil"e dönmeli)
- Hata mesajları **Türkçe ve anlaşılır** olacak; teknik ayrıntı ayrı bir
  "Ayrıntıları göster" alanında dursun
- Her bileşen `/var/log/karanos/` altına log yazacak
- Beklenmedik çökmede bileşen kendini yeniden başlatacak (systemd `Restart=`),
  panel çökerse masaüstü kullanılamaz hale gelmeyecek
- Her aşama QEMU'da test edilecek; özellikle şu senaryolar denenmeli:
  çift tıklama, kurulum sırasında internetin kesilmesi, aynı anda iki
  uygulamadan kurulum başlatma, kurulum sırasında pencereyi kapatma

---

## 20. Çalışma biçimi

- Her aşamada önce kısa bir plan sun, onay al, sonra kodla
- **Sistem iki dilli: Türkçe ve İngilizce.** Hiçbir metin koda gömülmeyecek;
  tüm arayüz yazıları çeviri dosyalarında tutulacak (gettext `.po/.mo` veya
  bileşen başına JSON). Anahtar tabanlı olacak, örn. `panel.start`,
  `store.button.install`. Dil setup'ta seçilir, Ayarlar > Görünüm'den
  (veya Dil bölümünden) anında değiştirilebilir; oturumu kapatmaya gerek
  kalmadan uygulanırsa daha iyi. Varsayılan sistem dili Türkçe.
  **Metinler ayrıca verilecek** — hazır Türkçe/İngilizce dizeleri kullan,
  kendin uydurma. Eksik anahtar bulursan bana sor.
- Değişken/fonksiyon/dosya isimleri İngilizce
- Sık sık QEMU'da test et, çalışmayan bir şeyi "tamam" diye işaretleme
- Bir aşamayı bitirmeden diğerine geçme; yarım özellik bırakma
- Bir şey teknik olarak mümkün değilse veya kötü bir fikirse **söyle**,
  sessizce etrafından dolaşma
- **Hafiflik:** boşta (masaüstü açık, uygulama yokken) toplam RAM kullanımı
  ideal olarak 1 GB'ın altında, en fazla 1.5 GB olmalı. Ağır bağımlılıklardan
  kaçın, arka planda sürekli çalışan servisleri gereksiz yere çoğaltma,
  yoklama (polling) aralıklarını makul tut. Ama istenen bir özelliği bu uğurda
  kesme — sınırı zorlarsan önce haber ver.

---

## 21. İlk iş: bana dosya listesi ver

Koda başlamadan önce, **benim elimle koymam gereken her dosyayı** net biçimde
listele. Şunu istiyorum: hangi dosyayı, hangi klasöre, tam olarak hangi adla
koyacağım — tahmin etmek zorunda kalmayayım.

Ben şu iki dosyayı sana vereceğim, projede kullanacağın yere sen karar ver ve
adını bana bildir:

- Açılış görseli (PNG)
- Açılış müziği (MP3)

Bunları koyacağım klasörü oluştur ve içine bir `README.md` bırak; hangi
dosyanın hangi ada sahip olması gerektiği, önerilen çözünürlük/süre/boyut
sınırları orada yazsın. Örnek beklediğim netlik:

```
assets/boot/boot-image.png     ← açılış görseli (önerilen: 512×512, şeffaf arka plan)
assets/boot/boot-sound.mp3     ← açılış müziği (önerilen: 3-6 saniye, 128 kbps)
assets/logo/k-logo.svg         ← K logosu (bende hazır, sana vereceğim)
```

Ayrıca **GitHub'a ne koyacağımı** da ayrı bir liste hâlinde söyle:

- Hangi depolar açılacak (örn. `karanos`, `karanos-repo`, `karanos-catalog`) ve
  hangisi ne işe yarıyor
- Hangi depo GitHub Pages olarak yayınlanacak, hangi ayarın açılması gerekiyor
- Hangi gizli anahtarların (GPG anahtarı, Actions secret'ları) oluşturulup
  nereye ekleneceği — adım adım
- Release'e hangi dosyaların yükleneceği ve dosya adlandırma kuralı
  (örn. `karanos-1.0-amd64.iso`, `karanos-1.0-amd64.iso.sha256`)
- Katalog dosyasının adı ve deposu, hangi URL'den indirileceği

Bu listeyi verdikten sonra 17. bölümdeki geliştirme sırasına geç.

(Bu bölüm dosyanın sonunda ama **ilk yapılacak iş budur**.)

---

## Doldurulacak yer tutucular

| Yer tutucu | Ne konacak |
|---|---|
| `[BOOT_GÖRSELİ]` | Açılışta görünecek PNG |
| `[BOOT_MÜZİĞİ]` | Açılışta çalacak mp3 |
| `[GITHUB_KULLANICI]` | APT deposu ve Releases için GitHub kullanıcı adı |
