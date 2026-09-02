# mintupdate — referans incelemesi

İlgili Kavis maddesi: 26 (güncelleme sistemi). İnceleme tarihi: 2026-09-01, depo HEAD'i `1cea35d` (2026-08-20).

Kaynak: `/tmp/referans/mintupdate` (sığ klon, `--depth 1`; bu yüzden tarihçe
gerektiren tespitler "doğrulanmadı" işaretli). Kural gereği bu belgeye kod
kopyalanmadı; yalnızca yaklaşım anlatılıyor.

## Kimlik

- Linux Mint'in güncelleme yöneticisi ("Update Manager"). GPL, Python 3 + GTK 3.
- Kabaca **5.000 satır Python** (en büyük dosya `mintUpdate.py` ~2.300 satır),
  artı ~1.700 satır Glade `.ui` XML'i, birkaç küçük kabuk/politika dosyası.
  Deponun satır sayısını asıl şişiren şey ~100 dildeki `.po` çevirileri.
- APT güncellemelerinin yanında Flatpak ve Cinnamon "spice" (uzantı)
  güncellemelerini de aynı pencerede yönetiyor; Cinnamon/Flatpak destekleri
  içe aktarma başarısız olursa sessizce kapanacak şekilde isteğe bağlı.
- Bağımlılıklar (debian/control): `python3-apt`, `aptkit`, `python3-xapp`,
  `python3-pycurl`, `python3-multiprocess`, `systemd`, `gir1.2-notify-0.7`,
  `gir1.2-xapp-1.0`.

## Mimari

**Ayrı bir daemon YOK.** Tek bir GTK süreci hem pencere hem tepsi simgesi:

- `/etc/xdg/autostart/mintupdate.desktop` oturum açılışında uygulamayı
  argümansız başlatır → pencere **gizli** açılır ("tray modu"). Menüden
  başlatan `/usr/bin/mintupdate` ise `show` argümanıyla aynı betiği çağırır.
  Açılışta `killall` ile eski kopya öldürülür (kaba ama etkili tekilleştirme).
- Tepsi simgesi `XApp.StatusIcon`; durum, **simge adı değiştirilerek**
  gösteriliyor: `checking / updates-available / up-to-date / error / warning`
  sembolik simgeleri. Rozet sayısı yok, sayı tooltip'te ("N update available").
- Eşzamanlılık: iki dekoratörle çözülmüş — `_async` (daemon thread) ve
  `_idle` (GLib.idle_add ile ana döngüye dönüş). Zamanlayıcılar için yeniden
  kurulabilir bir `GLib.Source` sarmalayıcısı (`MainloopTimer`) var.
- Güncelleme listesi hesaplama (`fetch_updates`) **ayrı bir süreçte**
  (`python3-multiprocess`, Queue + 60 sn zaman aşımı) çalışıyor; python-apt
  önbelleği ana süreci kilitlemesin ve çökme ana uygulamayı götürmesin diye.
- Yardımcı süreçler: `mintupdate-cli` (komut satırı, otomasyonun da temeli),
  `mintupdate-automation` (root; systemd timer'ı aç/kapa), flatpak işleri
  için ayrı bir worker süreci.

## Kullandığı sistem arayüzleri

Üç ayrı ayrıcalık yolu bir arada:

1. **python-apt (okuma)**: önbelleği açar, `upgrade(dist-upgrade)` simülasyonu
   yapıp `get_changes()` ile güncelleme listesini çıkarır. Kök gerekmez.
2. **aptkit (kurulum ve etkileşimli önbellek yenileme)**: D-Bus/polkit
   üzerinden çalışan aptdaemon çatallaması; GUI'den paket kurulumunu ve
   pencere açıkken cache yenilemeyi bu yapar (ilerleme diyaloğu dahil).
3. **sudoers istisnaları (sessiz işler)**: `/etc/sudoers.d/` içinde iki komuta
   NOPASSWD verilmiş — `mint-refresh-cache` (rootta python-apt `cache.update()`
   çağıran mini betik; tray modundaki sessiz yenileme bunu kullanır) ve
   `dpkg_lock_check.sh` (`fuser` ile dpkg kilidi dolu mu bakar).
4. `mintupdate-cli` kurulumda aptkit değil doğrudan `apt-get install`
   (subprocess) kullanır; `--yes` modunda `DEBIAN_FRONTEND=noninteractive` +
   `--force-confnew` (veya `--keep-configuration` ile `--force-confold`).

Diğer entegrasyonlar: UPower D-Bus'tan pil durumu (pildeyken otomatik iş
yapma), oturum yöneticisine Inhibit (güncelleme sırasında oturum kapanmasın),
otomatik yükseltme sırasında `systemd-inhibit --what=shutdown --mode=block` +
geçici bir polkit `.pkla` dosyasıyla kapat/yeniden başlat düğmelerinin
kilitlenmesi.

## Snapshot ve güvenlik güncellemesi yaklaşımı

**Önemli bulgu: mevcut HEAD'de güncelleme öncesi otomatik snapshot YOK.**
Timeshift entegrasyonu yalnızca Düzenle menüsünde bir "System Snapshots"
öğesi: `timeshift-gtk` kuruluysa `pkexec` ile açılıyor. Yani Mint'in "önce
snapshot al, sonra her güncellemeyi gönül rahatlığıyla kur" felsefesi
**kullanıcı disiplinine ve Timeshift'in kendi zamanlanmış snapshot'larına**
dayanıyor; güncelleme işlemine bağlı otomatik snapshot mintupdate'te yok.
(Eski sürümlerde güncellemeleri güvenlik seviyelerine göre engelleyen sistem
vardı ve Timeshift'e güvenilerek kaldırıldığı biliniyor; sığ klonda tarihçe
olmadığından bu belgede doğrulanmadı.)

Güvenlik/normal ayrımı paket **origin metaverisinden** yapılıyor:

- Ubuntu kaynaklı paket, arşiv adı `-security` içeriyorsa → güvenlik.
- Debian kaynaklı paket, origin etiketi (label) `-Security` içeriyorsa →
  güvenlik. (Kavis için geçerli olan yol budur: trixie'de
  `trixie-security` deposunun label'ı buna uyar.)
- `firefox`, `thunderbird`, `chromium` **kodda sabitlenmiş**: her
  güncellemeleri güvenlik sayılır.
- Mint'in `romeo` (unstable) bileşeni ayrı "unstable" tipi alır.

Ek mekanizmalar:

- **Kara liste**: gsettings dizisi + `/etc/mintupdate.blacklist`;
  `kaynak-paket` veya `kaynak-paket=sürüm` biçiminde, fnmatch joker destekli.
- **Öncelikli öz-güncelleme**: `mintupdate` ve `mint-upgrade-info`nun yeni
  sürümü varsa liste temizlenir, YALNIZCA bunlar gösterilir ("önce beni
  güncelle" sayfası). Güncelleyicinin kendi hatasının düzeltmesini başka
  güncellemelerin önüne geçirmek için.
- **Otomatik yükseltme**: `mintupdate-automation upgrade enable` bir dokunma
  dosyası + systemd timer (`mintupdate-automation-upgrade.timer`) kurar;
  servis pilde değilse `mintupdate-cli upgrade --refresh-cache --yes`
  çalıştırır, günlüğü `/var/log/mintupdate.log`a yazar (logrotate ile).

## Çekirdek güncellemeleri

- Çekirdek tespiti: paket bölümü `kernel` ise, adı `linux-headers*` ise veya
  kaynak paketi `linux`, `linux-signed`, `linux-meta` vb. ise "kernel" tipi.
  Desteklenen çeşni listesi sabit: `-generic`, `-lowlatency`, bulut
  çekirdekleri vb.
- **Gruplama**: tüm çekirdek paketleri `linux-<sürüm>` adı altında tek
  güncelleme satırında toplanır; meta paketin bağımlılık zinciri yürünerek
  gerçek çekirdek sürümü bulunur (meta sürümü ile imzalı paket sürümü
  farklı olduğundan).
- Kullanıcıya "Linux kernel X" takma adıyla, regresyon riskini ve eski
  çekirdekle açılabileceğini anlatan uzun uyarı metniyle gösterilir.
  Changelog changelogs.ubuntu.com'dan çekilir.
- Ctrl+K yalnız çekirdek güncellemelerini seçer; `mintupdate-cli --only-kernel`
  ile otomasyonda da ayrıştırılabilir. Eski çekirdek temizleme aracı bu
  HEAD'de yok (eskiden ayrı "kernel manager" penceresi vardı; doğrulanmadı).

## "Sessiz otomatik kontrol + rozet" kurgusu

Katmanlı ve gecikmeli bir kurgu; hepsi GUI sürecinin içinde:

1. **İlk kontrol gecikmesi**: oturum açılınca hemen değil, varsayılan
   ~10 dk sonra (gsettings `refresh-minutes/hours/days`); açılış anındaki
   ağ/disk yarışını önlemek için.
2. **Periyodik kontrol**: varsayılan 2 saatte bir (`autorefresh-*`); pencere
   açıksa veya başka yenileme sürüyorsa 60 sn sonraya ertelenir.
3. **Önbellek gözcüsü**: 90 saniyede bir `pkgcache.bin` ve `dpkg/status`
   mtime'larına bakan bir thread; kullanıcı terminalden apt çalıştırdıysa
   listeyi kendiliğinden tazeler (dpkg kilidi doluysa dokunmaz).
4. **Rozet**: tepsi simgesinin adının değişmesi; "sistem güncel" simgesi
   istenirse gizlenebilir (`hide-systray`), güncelleme varken hep görünür.
5. **Bildirim nagging'i (UpdateTracker)**: her bildirimde değil; JSON
   dosyasında hangi güncellemenin kaç gündür beklediği izlenir. Bildirim
   ancak şu eşiklerde çıkar: bir güncelleme N oturum günü görüldüyse
   (varsayılan 7) veya M takvim günü beklediyse (15); üstelik kullanıcı son
   30 gün içinde elle güncelleme yaptıysa (apt history.log'dan bakılır)
   bildirim bastırılır, iki bildirim arasına en az 2 gün konur ve
   varsayılan olarak yalnız güvenlik/çekirdek güncellemeleri sayılır.
   Bildirimde "güncellemeleri gör" ve "otomatik güncellemeyi aç" eylemleri
   bulunur. Rahatsız etmeyen ama süreklilik kazandıran akıllıca bir denge.

## Tuzaklar (tekrar eden issue şikâyetleri)

`gh api` ile açık issue'lar yoruma göre sıralandı (2026-09-01). Öne çıkanlar:

- **fwupd/aygıt yazılımı desteği yok** (en çok yorumlanan istek, 19 yorum) —
  kullanıcılar UEFI/firmware güncellemelerinin de aynı yerde olmasını istiyor.
- **Aşırı disk yazma**: "2 günde 500 GB yazdı" (10 yorum) — önbellek
  yenileme/izleme kurgusunun agresifleşebildiğinin işareti.
- **Çekirdek sınıflandırma karışıklığı**: kurulu olmayan bir çekirdek
  sürümünü güncelleme diye dayatma (9), yanlış simge/yanlış tip (8),
  "eski çekirdekte takılı kaldı" (5), "çekirdek kaldırırken çekirdek
  kurdu" (5) — meta paket/sürüm eşleme sezgiselinin kırılgan olduğu yerler.
- **Depo etiketi değişince kırılma** (6): `apt update` "changed its label"
  hatası verdiğinde GUI çaresiz kalıyor; mintupdate hata metnine "terminalden
  apt update çalıştırın" önerisi eklemek zorunda kalmış.
- **Pencere odak çalma** (6) ve "güncelleme sonrası pencere açık kalsın"
  isteği (5) — pencere yaşam döngüsü ayrıntıları kullanıcıyı çok etkiliyor.
- **apt-listchanges kuruluyken kurulumun takılması** (5) — arka plandaki
  kurulum etkileşimli bir prompt'a düşerse her şey kilitleniyor.
- **Otomatik güncellemeye zamanlama/yeniden başlatma planı** isteği (5) ve
  Flatpak otomatik güncellemenin çalışmadığı şikâyetleri (4+3).
- İlk açılışta aniden kapanma (5) — muhtemelen `killall` tekilleştirmesinin
  yan etkisi (doğrulanmadı).

## Kavis için çıkarımlar

Madde 26'yı (güncelleme sistemi) yazarken:

1. **Snapshot'ı işleme bağla, mintupdate'i aşan yer burası.** Mintupdate
   snapshot'ı kullanıcıya bırakıyor; bizim plandaki "güncellemeden önce
   btrfs snapshot" fikri bir apt/dpkg kancası veya güncelleyicinin kurulum
   adımının ilk işi olarak **otomatik** olmalı. Bu, mintupdate'in en zayıf
   halkasını kapatır. Başarısız snapshot'ta kullanıcıya sorup devam etme
   seçeneği bırakılmalı (disk dolu senaryosu).
2. **Güvenlik ayrımı için origin metaverisi yeterli**: trixie'de
   Debian-Security label'ına bakmak mintupdate'in Debian yolu ile birebir
   aynı; ayrıca tarayıcı gibi paketleri güvenlik saymak için küçük bir sabit
   liste meşru bir kestirme.
3. **Daemon şart değil**: gizli pencereli tek GTK süreci + durum simgesi
   modeli 2 çekirdekli hedef için de hafif; ama liste hesaplamayı ayrı
   süreçte, kurulumları da GUI'den ayrı bir ayrıcalık kanalında (polkit)
   tutma kararı aynen alınmalı. Sudoers NOPASSWD yerine baştan polkit
   kullanmak daha temiz olur.
4. **Kademeli sessizlik**: açılışta gecikmeli ilk kontrol, birkaç saatlik
   periyot, apt kilidi kontrolü, pildeyken erteleme, pencere açıkken
   erteleme — bu erteleme merdiveninin tamamı düşük maliyetli ve almaya
   değer. Ancak "500 GB yazdı" şikâyeti ders: mtime yoklamasını seyrek tut,
   her tetikte tam cache yeniden kurma.
5. **Nagging eşiği**: her kontrolde bildirim değil, "X gündür bekliyor +
   yakınlarda elle güncelleme yapılmamış" eşiği. Bildirim metinleri
   `po/` (gettext)den gelecek; tabloda güncelleme
   bildirimi satırı yoksa önce eklenmesi istenmeli.
6. **Öz-güncelleme önceliği** (önce güncelleyicinin kendisi) küçük ama
   değerli bir fikir; Kavis'in güncelleyici paketi için aynen uygulanabilir.
7. **Etkileşimli prompt'a düşmeyi imkânsızlaştır**: otomatik kurulumlarda
   `noninteractive` + conffile politikası baştan seçilmeli
   (apt-listchanges takılması dersi). Otomatik yükseltme sırasında
   `systemd-inhibit` + kapatma engeli de alınmalı.
8. **Çekirdek gruplaması bizde basitleşir**: Kavis tek Debian çekirdeği
   dağıttığı için mintupdate'in kırılgan meta-paket sürüm eşleme sezgiseline
   gerek yok; "linux-image-* = çekirdek tipi, yeniden başlatma gerektirir"
   demek yeter. Yeniden başlatma gereğini ayrı bir durumla (simge + kalıcı
   uyarı) göstermek mintupdate'ten alınacak iyi bir örüntü.
9. **Kara liste biçimi**: `kaynak-paket[=sürüm]` + joker deseni basit ve
   kanıtlanmış; CLI ve GUI'nin aynı listeyi paylaşması da (bizde tek
   yapılandırma dosyası) korunmalı.
10. **Bizim plandan fark**: mintupdate Flatpak/Cinnamon uzantılarını da
    kapsıyor; mintupdate issue'larının önemli bölümü bu ek kapsamların bakım
    yükünden geliyor. Kavis'te sıralama görev listesiyle uyumlu tutulmalı:
    madde 26 (Grup J'ye kadar) yalnız APT'yi kapsar, Flatpak güncellemeleri
    madde 41 gereği ancak Grup G'de mağazayla birlikte aynı ekrana eklenir —
    yani "önce APT" önerisi plandan sapma değil, sıranın kendisi.
