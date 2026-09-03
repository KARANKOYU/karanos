# Pardus araçları — referans incelemesi (3 Eyl 2026, 20 dk sınırı)

Kaynak: github.com/pardus altındaki altı depo, `--depth 1` klon
(pardus-software, pardus-update, pardus-package-installer,
pardus-power-manager, pardus-boot-repair, pardus-welcome). Hepsi
Python 3 + GTK3 (pardus-software 7.400, pardus-update 4.700 satır;
diğerleri ~1.000). KOD KOPYALANMAZ — yaklaşım Vala'ya uyarlanır.
Kavis eşlemesi: mağaza 12/41 (kararlar.md 1), güncelleme 26
(kararlar.md 3), güç 51, kurucu/kurtarma 16/20/33, resmi kurucu
(katalog "official" girdileri), ilk açılış 15/24.

## Ortak kalıp — "root yardımcısı + polkit" (tüm depolarda aynı)

- GUI süreci root DEĞİL. Yetki isteyen her iş tek bir küçük
  `Actions.py`/`SysActions.py`'ye toplanır; GUI onu `pkexec` ile
  çağırır, stdout/stderr'i Vte/`Gio.Subprocess` üzerinden canlı okur.
- Polkit ilkesi: `allow_active=auth_admin_keep` (parola bir kez, kısa
  süre hatırlanır), `exec.path` ile yardımcı yolu SABİT — GUI'nin
  başka bir şey çalıştırması imkânsız. Güç yöneticisi `auth_admin`
  (tek seferlik: kullanıcıyı `video` grubuna ekleme).
- Yardımcı ilk iş **apt kilidini dener** (`apt_pkg.pkgsystem_lock`);
  alamazsa çıktıya "dpkg lock error" / "dpkg interrupt error" basar,
  GUI bu iki satırı tanıyıp kullanıcıya iki farklı mesaj gösterir
  (başka bir paket yöneticisi açık / `dpkg --configure -a` gerekli).
- `DEBIAN_FRONTEND=noninteractive` + `-yq` + `APT::Status-Fd=2`:
  ilerleme yüzdesi stderr'deki `pmstatus:`/`dlstatus:` satırlarından
  ayrıştırılır (GUI 4866-4871), gerçek hata satırları `E:` ile başlar.

**Kavis'e uyarlama (mağaza 12, güncelleyici 26, resmi kurucu — hepsi
için tek çekirdek, Grup G'de yazılacak `kavis-common/aptjob.vala`):**
1. Tek root yardımcısı `/usr/lib/kavis/pkg-helper` (sh veya Vala),
   polkit `org.kavis.pkg` `auth_admin_keep`, `exec.path` sabit; GUI
   yalnız `install|remove|update|upgrade|deb <yol>` ister.
2. Yardımcı önce kilit dener; iki ayrı çıkış kodu: 10 = kilit dolu
   (kim tutuyor: `fuser /var/lib/dpkg/lock-frontend` ile süreç adı
   mesaja girer), 11 = yarım kalmış dpkg (`dpkg --configure -a`
   teklifi düğmeyle). Pardus mesajı yalnız gösteriyor; Kavis düğmeyle
   onarır.
3. `APT::Status-Fd` ayrıştırıcı Vala'da tek sınıf: `pmstatus:pkg:yüzde:
   metin` → ilerleme çubuğu + "şu an: libfoo kuruluyor" satırı;
   `E:` satırları biriktirilip özet diyalogda; ham günlük "Ayrıntılar"
   açılırında (Pardus'ta Vte terminali — Kavis'te de Vte, tilix zaten
   getiriyor).
4. Kullanıcı iptal ederse Pardus apt'ın alt süreç ağacını (`apt`,
   `_apt` indirme metodları) seçerek öldürüyor; dpkg aşamasındaysa
   ÖLDÜRMÜYOR (yarım paket bırakmamak için). Aynı kural: indirme
   iptal edilebilir, kurulum başladıysa düğme "bekleyin"e döner.

## 1. pardus-software (mağaza)

- **Ne yapıyor:** apt tabanlı uygulama mağazası. Katalog kendi
  sunucusundan (`/api/v3/hash`, `/apps`, `/homepage`, `/details`):
  önce hash'ler indirilir, yerel önbellekle (`~/.cache/pardus/
  pardus-software/`) karşılaştırılır, yalnız değişen arşiv
  (`apps.tar.gz`, `icons.tar.gz`, `images.tar.gz`, `cats.tar.gz`,
  `home.tar.gz`) yeniden iner. Puan/yorum/öneri sunucuda; GNOME
  odrs puanları ayrıca çekiliyor. **Flatpak yok** — yalnız apt.
- **apt/polkit:** yukarıdaki kalıp; ek olarak i386 mimarisi ekleme
  (`dpkg --add-architecture`) ayrı eylem, "önerilenlerle kur"
  seçeneği apt seçeneği olarak yardımcıya geçiyor.
- **Hata durumları:** dpkg kilidi ve yarım dpkg (iki mesaj); apt
  önbelleği bozuksa (`cache.broken_count > 0`) mağaza açılışta uyarır;
  sunucu hash'i alınamazsa önbellekteki katalogla ÇEVRİMDIŞI açılır;
  kurulu-mu bilgisi `apt.Cache` üzerinden (masaüstü dosyasından
  `dpkg -S` ile paket adı çıkarma — menüden gelen uygulamalar için).
- **Kavis'e (12/41):**
  1. Katalog güncellemesi hash'le: `data/store-catalog.json` yanında
     `sha256` — ISO'daki kopya çevrimdışı çalışır, çevrimiçi yalnız
     hash değişince iner (kararlar.md 1'in "kendini günceller"i).
  2. İkon/görsel arşivleri ayrı ve tembel: katalog önce metin, görseller
     görünen kart için iner (Pardus tek seferde hepsini çekiyor —
     ilk açılış yavaş; Kavis kart başına).
  3. "Kurulu mu" kararı Pardus'ta apt cache'ten, Flatpak için
     `flatpak list --app --columns=application` ile aynı tabloya —
     tek kaynaktan iki bayrak (kararlar.md 1: aynı anda tek kaynak).
  4. Sunucu tarafı puan/yorum Kavis'te YOK (kararlar.md: sunucu yok);
     odrs'nin bedava GNOME puanlarını göstermek düşünülebilir — ONAY.

## 2. pardus-update (güncelleyici)

- **Ne yapıyor:** apt güncellemeleri (paket listesi, boyut, değişim
  günlüğü), otomatik denetim aralığı (kullanıcı/sistem ayarı;
  `-1` = hiç), tepsi simgesi + bildirim, "dist-upgrade" (sürüm
  yükseltme) sunucudan gelen dağıtım anahtarıyla, apt temizliği
  (autoremove, clean, lists), artık paketleri kaldırma, kaynak
  listesi kontrolü ("kötü niyetli kaynak" reddi).
- **apt/polkit:** `SysActions.py` üzerinden `apt full-upgrade` +
  `Dpkg::Options::=--force-confnew|confold|(sor)` seçeneği; belirli
  paketler geçici `apt-mark hold` ile tutulup sonra bırakılıyor;
  `dpkg --configure -a`, `apt clean`, `autoremove` ayrı eylemler.
  Otomatik `apt update` ayrı küçük betik (`LC_ALL=C`, root cron/timer).
- **Hata durumları:** kilit / yarım dpkg (stderr'e sabit dizge);
  apt cache açılamıyorsa "aborting"; artık paket adı cache'te yoksa
  atlanır; upgrade çıkış kodu → ikon durumu (normal/error);
  "retry" 10 yerde — sunucu istekleri yeniden deneniyor.
- **Kavis'e (26, kararlar.md 3):**
  1. Yapılandırma dosyası çakışması politikası Ayarlar'da seçilebilir
     olmasın: Kavis varsayılanı `--force-confold` + değişen conf'ları
     listeleyen bilgi (Pardus'un üç seçeneği kullanıcıyı yoruyor).
  2. Snapshot Pardus'ta yok — Kavis'in farkı: upgrade ÖNCE btrfs
     snapshot, ÇIKIŞ KODU ≠ 0 ise "geri al" düğmesi aynı ekranda.
  3. Tepsi ikonunun üç durumu (güncel / güncelleme var / hata) ve
     bildirim "ne zaman": Pardus aralık dolunca; Kavis pilde/ölçülü
     ağda ERTELER (Pardus'ta yok).
  4. "Sadece güvenlik" (kararlar.md 3): Pardus'ta yok; apt'ın
     `-t`/`Origin` filtresi yerine `apt list --upgradable` çıktısındaki
     kaynak sütunu (`Debian-Security`) ile liste iki gruba ayrılır.
  5. Otomatik `apt update`'i ayrı root betiğine vermek doğru: Kavis'te
     systemd timer + `kavis-apt-refresh` (root), GUI yalnız okur.

## 3. pardus-package-installer (.deb kurucu)

- **Ne yapıyor:** `.deb` çift tıklanınca açılan pencere: paket adı,
  sürüm, kurulu sürüm, bağımlılıklar, EKSİK bağımlılıklar; Kur /
  Yeniden kur / Sürüm düşür / Kaldır; sürükle-bırak.
- **apt/polkit:** `apt install ./x.deb -yq --force-confnew` (dpkg -i
  DEĞİL — bağımlılıkları apt çözer; bizim test10 dersimizle aynı),
  `--reinstall --allow-downgrades` ayrı eylemler. Kilit kontrolü aynı.
- **Hata durumları:** `apt.debfile.DebPackage` ile ÖNCEDEN çakışma /
  eksik bağımlılık analizi (kurmadan söyler); "daha yeni sürüm zaten
  kurulu" hata sayılmaz, "sürüm düşür" düğmesi çıkar.
- **Kavis'e (resmî kurucu — kararlar.md 1 "official" girdileri):**
  1. İndirilen `.deb` kurulmadan önce `dpkg-deb -f` + `apt-get install
     --simulate ./x.deb` ile bağımlılık/çakışma önizlemesi; kullanıcıya
     "şunlar da kurulacak (N MB)" listesi.
  2. `apt install ./x.deb` yolu (dpkg -i asla) — CI'da zaten öğrenildi.
  3. Aynı paket kuruluysa sürüm karşılaştırması (`dpkg
     --compare-versions`) ile Kur/Yeniden kur/Düşür düğmesi otomatik.
  4. sha256 doğrulaması Pardus'ta yok (yerel dosya); Kavis'te resmi
     indirmede ZORUNLU (katalogdaki `sha256` boşsa yalnız uyarıyla).

## 4. pardus-power-manager

- **Ne yapıyor:** `power-profiles-daemon` (net.hadess.PowerProfiles,
  sistem D-Bus'ı) profil seçici + parlaklık kaydırıcıları (birden çok
  backlight aygıtı), tepsi/panel eklentisi.
- **polkit:** parlaklık için `/sys/class/backlight` yazma izni
  kullanıcıyı `video` grubuna ekleyerek (tek seferlik `adduser`,
  `auth_admin`); sonrasında pkexec YOK. Kavis'in brightnessctl+udev
  yaklaşımıyla aynı fikir.
- **Hata durumları:** ppd yoksa açılışta hata diyaloğu ve çıkış;
  ppd profil değişimini `PropertiesChanged` sinyaliyle izleyip UI'ı
  eşitler; backlight aygıtı yoksa kaydırıcı gizli (+ hata mesajı).
- **Kavis'e (51):**
  1. PowerPlan (SAVER/NORMAL/PERFORMANCE/GAME) ppd'ye yazıyor;
     Pardus gibi `PropertiesChanged` DİNLENMELİ — başka bir araç
     profili değiştirirse hızlı ayarlar kutucuğu doğru kalır (bugün
     yalnız yazıyoruz).
  2. ppd yoksa (VM, minimal) Kavis diyalog çıkarmaz: kutucuk gizlenir,
     Ayarlar > Güç açıklar (madde 62 dürüstlük ilkesi).
  3. Birden çok backlight (dizüstü + harici DDC) Pardus'ta liste;
     Kavis'te 3C tek aygıt varsayıyor — ikinci aygıt gelince ikinci
     kaydırıcı (ddcutil sonraki iş).

## 5. pardus-boot-repair

- **Ne yapıyor:** canlı ortamdan kurulu sistemi onarma menüsü: GRUB'u
  yeniden kur (EFI/legacy otomatik; efivars temizleme ve `--removable`
  seçenekleri sorulur), bozuk paketleri onar, parola sıfırla, tam
  güncelleme, sistemi yeniden kur (dosyalar korunur), dosya sistemi
  onarımı (fsck; LUKS açma, LVM bağlama), yapılandırmayı sıfırla,
  günlük dökümü, elle chroot. Hepsi Vte'de görünür komutlar.
- **polkit:** tek ilke `auth_admin`, `exec.path=/usr/bin/pardus-boot-
  repair` (uygulamanın tamamı root). Kabuk betikleri: `pardus-mount-
  rootfs` (btrfs @ alt birimi dahil kök bulur), `pardus-chroot`
  (`unshare --fork --pid chroot` + dev/sys/proc/run/efivars
  bağlama/çözme döngüsü), `grub-reinstall` (depmod + initramfs her
  çekirdek için, `apt install --reinstall grub-*`, `grub-install
  --force`, Windows'un aradığı `EFI/Microsoft/Boot/bootmgfw.efi`
  yoluna kopya!), `fix-broken-packages` (sources.list.d ve apt
  listeleri sıfırlanır, `apt -f install`, yarım paketler `dpkg -r
  --force-depends` ile tek tek).
- **Hata durumları:** bölüm bulunamazsa durum sayfası; LUKS/LVM
  iteratif açma; her adım `set +e` ile devam edip son komutta `set -e`;
  chroot çıkışında umount döngüsü (`while umount`) — asılı bağ
  bırakmaz.
- **Kavis'e (16/20/33 — kurtarma ortamı ve kurucu):**
  1. `kavis-chroot` yardımcısı Pardus'unkiyle aynı sözleşmeyle
     (kök bul → bağla → unshare/chroot → umount döngüsü) — kurucu da
     kurulum sonrası grub-install'ı bununla yapar; tek kod yolu.
  2. GRUB onarımında EFI'de `--removable` VE `EFI/Microsoft/Boot`
     kopyası: sabit yazılım Windows girdisini arayan makinelerde
     tek çözüm; Kavis kurucusu bunu VARSAYILAN yapar (sorusuz).
  3. Kurtarma menüsü maddeleri (madde 33 A/C) Pardus listesinden:
     GRUB, bozuk paket, parola sıfırla, fsck (LUKS/LVM/btrfs), günlük
     dökümü, chroot — her biri Vte'de görünür komutla.
  4. `fix-broken-packages`'ın "apt listelerini sil + yeniden dene"
     adımı: bozuk `Packages` dosyası apt'ı kilitler; Kavis
     güncelleyicisinin hata yolunda aynı temizlik (kararlar.md 3).

## 6. pardus-welcome (ilk açılış)

- **Ne yapıyor:** ilk oturumda sayfa akışı: Hoş geldin, Duvar kâğıdı,
  Tema (açık/koyu), Ekran (panel boyutu, masaüstü ikon boyutu, ölçek —
  xrandr çıktısından), Klavye (`/etc/default/keyboard` okur),
  Destek/Topluluk. Masaüstüne göre (xfce/gnome) sayfa gizler.
- **polkit:** yok — her şey kullanıcı ayarı (gsettings/xfconf); klavye
  düzeni sistem geneli değiştirilmiyor (yalnız gösteriliyor).
- **Hata durumları:** neredeyse yok; masaüstü tanınmazsa sayfa
  gizlenir; xrandr çıktısı `grep '*'` ile ayrıştırılıyor (kırılgan).
- **Kavis'e (15/24 ilk açılış sihirbazı):**
  1. Sayfa listesi Pardus'la aynı omurga + Kavis ekleri: dil (78),
     klavye (tam xkb listesi, kararlar.md 7), tema, duvar kâğıdı,
     ölçek, "dürüst uyumluluk ekranı" (madde 15), uygulama setleri
     (madde 24).
  2. Ayarlar'la AYNI uygulayıcılar (Apply.theme/scale/keyboard/
     language) — Pardus'ta welcome ve ayarlar iki ayrı kod; Kavis'te
     sihirbaz sayfaları kavis-settings'in sayfalarını yeniden kullanır
     (tek yazıcı ilkesi).
  3. Bir kez gösterilip `~/.config/kavis/welcome-done` ile kapanır;
     Ayarlar > Sistem'den yeniden açılabilir.

## Özet: alınacak yaklaşımlar (Grup G/J girdisi)

| Yaklaşım | Kaynak | Kavis maddesi |
|---|---|---|
| Tek root yardımcısı + polkit `exec.path` + `auth_admin_keep` | hepsi | 12, 26, resmi kurucu |
| Kilit/yarım-dpkg ayrımı, ayrı çıkış kodları, düğmeyle onarım | software/update | 12, 26 |
| `APT::Status-Fd` ayrıştırıcı (ilerleme + `E:` özeti) | software | 12, 26 |
| Katalog hash ile artımlı, görseller tembel | software | 12 (kararlar.md 1) |
| `apt install ./x.deb` + simülasyon önizlemesi + sürüm karşılaştırma | package-installer | resmi kurucu |
| conf çakışması varsayılanı + snapshot geri alma + pil/ölçülü erteleme | update | 26 (kararlar.md 3) |
| ppd `PropertiesChanged` dinleme, ppd yoksa sessiz gizleme | power-manager | 51 |
| `kavis-chroot`, GRUB `--removable` + Microsoft yolu kopyası | boot-repair | 16, 20, 33 |
| Welcome = Ayarlar sayfalarının yeniden kullanımı | welcome | 15, 24 |
