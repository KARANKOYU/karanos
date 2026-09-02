# mintdrivers — referans incelemesi

İlgili Kavis maddesi: 35 (sürücü yardımcısı). İnceleme tarihi: 2026-09-01, depo HEAD'i `5c8046c`.

## Kimlik

- Dil: Python 3 + GTK 3 (PyGObject); arayüz Glade `main.ui` dosyasından yükleniyor.
- Boyut: çekirdek uygulama tek dosya, 763 satır (`mintdrivers.py`). Yardımcı betiklerle
  (canlı ortam ekleme/çıkarma, Broadcom modül yükleyici, başlatıcılar) toplam ~860 satır
  Python; Glade UI dosyası 610 satır. Gerisi çeviri (`po/`) ve paketleme.
- Lisans: GPL-2+ (Clement Lefebvre / Linux Mint).
- **Kod kopyalanmadı, yalnızca yaklaşım incelendi.**

## Mimari

Tek pencereli, tek dosyalık bir GTK uygulaması; ayrı bir daemon veya servis yok.
Akış kabaca şöyle:

1. **Açılış kontrolü**: `/proc/cmdline` içinde `boot=live` / `boot=casper` aranarak
   canlı oturum tespit edilir. Kurulu sistemde önce internet bağlantısı denenir
   (archive.ubuntu.com'a soket açarak); çevrimdışıysa `psutil.disk_partitions()` ile
   iso9660 bölüm aranır ve kurulum medyası APT deposu olarak bağlanmak üzere önerilir.
2. **Tespit**: `UbuntuDrivers.detect.system_device_drivers()` çağrısı cihaz → aday
   sürücü paketleri sözlüğünü döndürür (aşağıda). Bu çağrı ve APT önbellek yüklemesi
   arka plan iş parçacığında yapılır; UI güncellemeleri `GLib.idle_add` ile ana
   döngüye taşınır (dekoratör tabanlı basit async/idle deseni).
3. **Sunum**: Her cihaz için bir kutu; sürücü seçenekleri RadioButton grubu olarak
   listelenir — "önerilen", "alternatif", "elle kurulmuş", "cihazı kullanma"
   kategorileri. NVIDIA için özel mantık: `-server` varyantları gizlenir, 560 ve
   üzeri sürümlerde açık kaynak (`-open`) varyant, altında kapalı varyant tercih
   edilip diğeri listeden düşülür. Elle kurulmuş sürücü varsa diğer seçenekler
   pasifleştirilir.
4. **Uygulama**: Seçim değişiklikleri bir "değişiklik listesi"nde birikir;
   Uygula'ya basılınca PackageKit `Task` API'siyle (`install_packages_async`,
   `remove_packages_async`, Mint'in çatalladığı packagekit'te `purge_packages_async`)
   kurulum/kaldırma yapılır. Yetkilendirme PackageKit'in kendi polkit akışıyla gelir.
   NVIDIA kaldırırken üst paket meta paket olduğundan bağımlılıklar apt önbelleğinden
   toplanıp birlikte kaldırılır.
5. **Sonrası**: `/var/run/reboot-required` veya kendi bayrağı varsa "yeniden başlat"
   düğmesi gösterilir; Broadcom `wl` kurulduysa çakışan modüller (`b43`, `bcma`,
   `brcmsmac`...) root yardımcı betikle söküp `wl` yüklenir — yeniden başlatmadan
   Wi-Fi çalışsın diye.

Ayrıca `test` argümanıyla sahte bir cihaz eklenip UI donanımsız test edilebiliyor —
küçük ama değerli bir fikir.

## Kullandığı sistem arayüzleri

| Arayüz | Kullanım |
|---|---|
| `UbuntuDrivers.detect` (python3, `ubuntu-drivers-common` paketi) | Asıl sürücü tespiti: modalias'ları sistem paket arşivindeki `Modaliases` üstbilgileriyle eşler, önerilen sürücüyü seçer |
| PackageKit (GObject introspection, `gir1.2-packagekitglib-1.0`) | Paket kurma/kaldırma/önbellek yenileme; polkit yetkilendirmesi bunun içinden |
| `python3-apt` | Paket durumu okuma (kurulu mu, sürüm, özet, bağımlılıklar) — kurulum için değil, yalnızca sorgu |
| polkit | Tek özel eylem: kurulum medyasını bağlama (`pkexec` ile yardımcı betik) |
| sudoers bırakması (`etc/sudoers.d/`) | Medya kaldırma ve Broadcom modül yükleme betikleri NOPASSWD ile herkese açık — polkit yerine kestirme, güvenlik açısından tartışmalı |
| psutil / /proc | iso9660 bölüm arama, `/proc/cmdline`, `/proc/cpuinfo` (CPU adı) |
| XApp (`gir1.2-xapp-1.0`) | Görev çubuğunda ilerleme yüzdesi göstermek gibi Mint'e özgü süsler |

Doğrudan D-Bus, udev veya sysfs kullanımı yok — hepsi UbuntuDrivers ve PackageKit'in
arkasına saklanmış. udev/modalias işini fiilen `ubuntu-drivers-common` yapıyor.

## Debian'a taşınabilirlik

Debian trixie'de **çalışmayacak / karşılığı olmayan** kısımlar:

- **`ubuntu-drivers-common` trixie arşivinde yok** (tools/check-packages indeksiyle
  doğrulandı). Uygulamanın kalbi bu; onsuz tespit mekanizması tamamen boş kalır.
  Ayrıca yöntemin kendisi Ubuntu arşivine bağımlı: Ubuntu, paketlerine `Modaliases`
  üstbilgisi ekler ve `detect` bunları tarar. Debian paketlerinde bu üstbilgi
  bulunmadığından kod taşınsa bile eşleşme üretmez.
- **NVIDIA paket adlandırması farklı**: Ubuntu `nvidia-driver-535`, `-open`,
  `-server` gibi sürümlü paketler dağıtır; koddaki sürüm ayrıştırma ve açık/kapalı
  tercih mantığı bu adlara göre yazılmış. Debian'da tek `nvidia-driver` (+
  `nvidia-tesla-*` / legacy dalları) var; bu mantığın tamamı anlamsızlaşır.
- Çevrimiçilik testi archive.ubuntu.com'a bağlanıyor; canlı ISO tespiti casper
  (`boot=casper`) varsayımı da içeriyor (live-boot'un `boot=live`'ı ayrıca
  destekleniyor, o kısım uyar).
- `purge_packages_async` Mint'in kendi packagekit çatalında var; Debian
  packagekit'inde yalnız remove mümkün (kod zaten geri düşüyor).
- XApp Debian'da mevcut (`gir1.2-xapp-1.0` trixie'de VAR) ama Kavis'e gereksiz.

Debian tarafındaki karşılıklar (tümü trixie arşivinde doğrulandı):

- **`nvidia-detect`** (non-free): PCI ID'ye bakıp hangi NVIDIA paketinin uygun
  olduğunu söyler — Debian'ın resmi yolu, ama yalnız NVIDIA ve yalnız metin çıktısı.
- **`isenkram` / `isenkram-cli`**: modalias → paket eşlemesini Debian usulüyle yapar
  (AppStream verisi + kendi eşleme listeleri); `isenkram-autoinstall-firmware`
  komutu dmesg'den eksik firmware'i bulup ilgili `firmware-*` paketini kurar.
- **`fwupd`**: aygıt yazılımı güncellemeleri için (sürücüden ayrı ama aynı ekranda
  sunulabilir).
- PackageKit + `gir1.2-packagekitglib-1.0` + `python3-apt` trixie'de aynen var;
  kurulum katmanı yaklaşımı olduğu gibi Debian'da geçerli.

## Tuzaklar (tekrar eden issue şikâyetleri)

`gh api` ile issue'lar tarandı (açık + kapalı, yoruma göre sıralı). Tekrar eden temalar:

1. **"Elle kurulmuş sürücü" kilidi** (en çok yorumlanan issue): kullanıcı depo dışı
   sürücü kurup dönmek isteyince tüm seçenekler gri kalıyor, çıkış yolu sunulmuyor.
2. **Sonsuz "donanım aranıyor" / donma**: tespit veya önbellek yenileme takılınca
   arayüz süresiz spinner'da kalıyor; zaman aşımı ve hata sayfası her yolu kapsamıyor.
3. **Çevrimiçilik testinin kırılganlığı**: bir dönem 8.8.8.8:53'e TCP, sonra
   archive.ubuntu.com — kısıtlı ağlarda ve proxy arkasında "çevrimdışısın" yanlış
   alarmı; proxy ayarlarının yok sayılması ayrı bir şikâyet.
4. **Secure Boot**: DKMS modülü imzalanmadığında sürücü "kuruldu" görünüp
   çalışmıyor; MOK kaydı akışının olmaması / bozulması birden çok issue'da
   (uyarı bile gösterilmiyor).
5. **Broadcom özel durumları**: b43 seçeneğinin listelenmemesi, wl/b43 çakışmaları —
   Wi-Fi sürücülerinin özel muamele gerektirdiğinin kanıtı.
6. **Sahte canlı USB ile shell injection** (kapatılmış güvenlik issue'su): iso9660
   etiketli medyayı köke bağlayıp APT deposu yapmak saldırı yüzeyi açmış;
   `trusted=yes` ile imzasız depo eklenmesi de riskin parçası.
7. NVIDIA sürüm seçimi şikâyetleri (en yeni sürücünün gelmemesi, PPA paketlerinin
   yanlış "açık kaynak" etiketlenmesi) — sürücü listesi arşiv metaverisine güvenince
   metaveri hatası doğrudan UI hatası oluyor.

## Kavis için çıkarımlar

Madde 35'i (sürücü yardımcısı) yazarken:

- **Tespit katmanını Ubuntu'dan değil Debian araçlarından kur**: GPU için
  `nvidia-detect` çıktısını ayrıştır; firmware için `isenkram-cli`'nin
  modalias/AppStream eşlemesini kullan (veya doğrudan
  `isenkram-autoinstall-firmware`'ı "kuru çalıştırma" kipinde çağırıp öneri listesi
  al). `ubuntu-drivers-common`'ı taşımaya çalışmak çıkmaz sokak — arşiv metaverisi
  Debian'da yok.
- **Kurulum katmanı mintdrivers'taki gibi PackageKit Task API olsun**: polkit
  yetkilendirmesi bedavaya gelir, ayrı root daemon yazılmaz. Mint'in sudoers
  NOPASSWD kestirmesini **kopyalama**; root gerektiren her iş polkit eylemi olsun.
- **Async/idle ayrımını baştan kur**: tespit ve önbellek işleri iş parçacığında,
  UI güncellemeleri ana döngüde — mintdrivers'ın dekoratör deseni basit ve yeterli.
  Ama her async yola **zaman aşımı ve hata sayfası** ekle; "sonsuz spinner" en çok
  şikâyet edilen davranış.
- **Çevrimiçilik testini kendi deponla yap** (deb.debian.org veya Kavis aynası),
  sistem proxy ayarlarına saygı göster; başarısızlıkta "çevrimdışısın" değil
  "şu adrese erişemedim" de.
- **Secure Boot'u FARKLI yap**: açılışta `mokutil --sb-state` kontrol et; Secure
  Boot açıkken DKMS sürücüsü kurulacaksa en azından açık uyarı, mümkünse MOK kayıt
  akışına yönlendirme göster. Mint'te bunun yokluğu yıllardır issue üretiyor.
- **"Elle kurulmuş sürücü" durumunda kullanıcıyı kilitleme**: depo dışı kurulum
  tespit edilirse seçenekleri griletmek yerine ne yapması gerektiğini söyle
  (ör. hangi paketi kaldıracağı).
- **Canlı medyayı APT deposu yapma numarasını alma**: hem güvenlik geçmişi kötü
  (shell injection, `trusted=yes`) hem de Kavis ISO'su 1.5 GB altı hedefiyle zaten
  sürücü deposu taşımayacak. Çevrimdışı senaryoda dürüst ol: "internet gerekli" de.
- **Kapsamı dar tut**: mintdrivers 763 satırla NVIDIA + Broadcom + mikrokod +
  VirtualBox'ı idare ediyor; Kavis için gerçekçi kapsam NVIDIA (nvidia-detect),
  eksik firmware (isenkram) ve CPU mikrokodu (`intel-microcode` /
  `amd64-microcode`, bunlar trixie'de mevcut). Test kipi (sahte cihaz enjekte eden
  bir bayrak) UI'yi donanımsız/CI'da denemek için aynen alınmaya değer bir fikir
  (fikir olarak; kod değil).
- Arayüz metinleri her zamanki gibi `po/` (gettext)'den gelecek;
  bu incelemedeki kategori adları (önerilen/alternatif vb.) oradaki tablolara
  eklenmeden kullanılmamalı.
