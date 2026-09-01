# calamares — referans incelemesi

İlgili Kavis maddeleri: 16 (kurulum), 27C (A/B bölüm), 51A (hibernate swap).
İnceleme tarihi: 2026-09-01, depo HEAD'i `95aa33f` (2025-05-06, `calamares`
dalı = 3.3 LTS serisi, CMake sürümü 3.3.15).

## Kimlik

- Dağıtımdan bağımsız Linux kurulum çerçevesi; C++/Qt çekirdek + modüller.
- Geliştirme **Codeberg'e taşınmış** (codeberg.org/Calamares/calamares);
  GitHub deposu ayna, issue'lar GitHub'da kapalı.
- Debian trixie'de paket **var: `calamares 3.3.14-1`** (sources.debian.org
  API'sinden doğrulandı; sid/forky 3.4.2). Yani trixie paketi, incelenen 3.3
  LTS dalıyla neredeyse aynı sürüm — davranış farkı beklenmez. Debian ayrıca
  `calamares-settings-debian` benzeri hazır ayar paketi taşır (içeriği bu
  incelemede doğrulanmadı).

## Mimari (modül sistemi, branding)

- Üç modül türü: `viewmodule` (C++/Qt ekran; welcome, partition, users,
  summary...), `job` modülleri ve QML tabanlı `*q` varyantları (welcomeq,
  usersq...). `module.desc` dosyası türü ve arayüzü bildirir; sayım: 21
  modül `python`, 1 `process`, 1 `qtplugin` desc'li — C++ modüller desc'siz,
  CMake ile derlenir.
- Kritik iş modülleri Python: `mount`, `unpackfs`, `fstab`, `grubcfg`,
  `bootloader`, `displaymanager`, `machineid`, `services-systemd`. Yani özel
  davranış çoğunlukla Python modülü yazarak veya var olanın .conf'unu
  değiştirerek elde edilir; C++ derlemeye gerek kalmaz.
- `settings.conf`: `modules-search` (yol listesi), `instances` (aynı modülün
  farklı config'le birden çok örneği, `shellprocess@foo` gibi) ve `sequence`.
  Sıra iki fazlı: `show` (ekranlar: welcome→locale→keyboard→partition→users→
  summary) ve `exec` (işler: partition→mount→unpackfs→machineid→locale→
  keyboard→localecfg→fstab→initcpiocfg/initramfs→users→displaymanager→
  networkcfg→hwclock→services-systemd→bootloader→umount), sonda `show:
  finished`.
- Branding: `branding.desc` (ürün adı/sürüm/URL'ler, pencere boyutu,
  `sidebar`/`navigation` widget veya qml), görseller (`productLogo`,
  `productIcon`, `productWallpaper`, `productWelcome`), `style` renkleri
  (SidebarBackground vb.), `stylesheet.qss` ile QSS teması ve **QML
  slideshow** (`show.qml`, `slideshowAPI: 2`). Kavis koyu teması QSS +
  style anahtarlarıyla verilebilir; slideshow tek QML dosyası.

## btrfs subvolume ve A/B düzeni

- Subvolume tanımı **`mount.conf` içindeki `btrfsSubvolumes` listesinde**
  (partition.conf'ta değil): her giriş `mountPoint` + `subvolume` çifti
  (varsayılan `/@`, `/@home`, `/@cache`, `/@log`). Ayrı bölüme sahip
  mountPoint'ler listeden otomatik düşürülür; kök için boş string verilirse
  subvolume hiç oluşturulmaz.
- **`/users` için ayrı subvolume doğrudan tanımlanabilir**: listeye
  `mountPoint: /users`, `subvolume: /@users` girişi eklemek yeterli, özel
  modül gerekmez. fstab modülü bu girişleri `subvol=` seçenekleriyle yazar;
  `mountOptions` bölümünden btrfs'e `compress=zstd:1`, ssd/hdd'ye özel
  seçenekler verilebilir.
- **A/B kök (@a/@b) hazır DEĞİL**: btrfsSubvolumes her subvolume'u bir
  mountPoint'e bağlar; "monte edilmeyen ikinci kök subvolume oluştur"
  kavramı yok. @a'ya kurulum `subvolume: /@a` ile yapılır, ama @b'nin
  oluşturulması, bootloader girişlerinin iki kökü tanıması ve varsayılan
  subvolume yönetimi için **özel bir Python job modülü (veya shellprocess
  instance'ı) gerekir**. grubcfg/bootloader modülleri `rootflags=subvol=`
  mantığını A/B'ye göre üretmez.
- `partitionLayout` (partition.conf) GPT tip/etiket/boyutlu özel bölüm
  şeması tanımlatır (EFI otomatik başa, swap bölümü otomatik sona eklenir);
  subvolume düzeyi burada değil, mount.conf'ta.

## Swap ve hibernate

- `partition.conf` → `userSwapChoices`: `none`, `small` (RAM'e kadar,
  hibernate garantisi yok), `suspend` (en az RAM kadar bölüm, hibernate
  için), `file` (swap dosyası); `reuse` kodda kapalı. `initialSwapChoice`
  varsayılanı belirler.
- `file` seçilirse mount modülü btrfs'te **otomatik ayrı `/@swap`
  subvolume'u** oluşturur (`btrfsSwapSubvol` anahtarı), `btrfs_swap` mount
  seçenekleri (`noatime`) uygulanır; fstab modülü `swap/swapfile`'ı yazıp
  `chattr +C +m` (CoW ve sıkıştırma kapalı) yapar, `mkswap` çalıştırır,
  fstab'a ekler.
- **KRİTİK (madde 51A)**: grubcfg/bootloader modülleri `resume=UUID=...`
  parametresini **yalnızca swap BÖLÜMÜ için** ekler (`fs == "linuxswap"`).
  Swap **dosyası** için ne `resume=` ne `resume_offset=` üretilir; kodda
  `resume_offset`/`filefrag`/`btrfs inspect-internal map-swapfile` hiç
  geçmiyor. Yani btrfs swapfile ile hibernate, Calamares'ten hazır çıkmaz:
  ya `suspend` (swap bölümü) seçeneği kullanılır ya da resume_offset'i
  hesaplayıp kernel parametresi + initramfs ayarı yazan özel modül gerekir.

## unpackfs (squashfs → hedef kopyalama)

- `unpackfs.conf` sıralı `unpack` listesi: her giriş `source` (squashfs/ext4
  imajı, dosya veya dizin), `sourcefs`, `destination` (rootMountPoint'e
  göre; boş string = `/`). İmaj loop-mount edilip **rsync** ile kopyalanır;
  `exclude`/`excludeFile` rsync'e geçer, `weight` ilerleme payını ayarlar,
  `condition` globalstorage değerine göre koşullu unpack (katmanlı squashfs
  senaryosu), `optional: true` yoksa atla demek. `module.desc`'te
  `requiredModules: [ mount ]` var. live-build ISO'sunda kaynak tipik
  olarak `/run/live/medium/live/filesystem.squashfs` olur.

## Kullanıcı ve otomatik giriş

- `users.conf`: `doAutologin: true` başlangıç durumu, `displayAutologin:
  true` kutuyu göster/gizle, `autologinGroup: autologin` (grup yoksa
  oluşturulmasını dağıtım sağlar — Debian'da lightdm için `autologin`
  grubu paket listesine/hook'a eklenmeli). Sudo grubu, shell, parola
  kalite kuralları (libpwquality) da burada.
- `displaymanager.conf`: `displaymanagers` sıralı tercih listesi (slim,
  sddm, lightdm, gdm, mdm, lxdm, greetd desteklenir); modül kurulu olan
  ilkini bulur, autologin'i DM'nin kendi conf dosyasına yazar (lightdm için
  `autologin-user=`, `preferred_greeters` ayarı mevcut). `basicSetup:
  false` bırakılır, DM servisini services-systemd etkinleştirir.

## Tuzaklar (tekrar eden issue şikâyetleri)

GitHub issue'ları kapalı (depo aynaya dönüşmüş); Codeberg API'sinden
tarandı. Öne çıkanlar:

- **bootloader BIOS/MBR + VirtualBox** (118 yorum, kapalı ama uzun süre
  açık kalmış): BIOS modunda GRUB kurulumu en kırılgan nokta. Ayrıca açık
  issue: "BIOS GRUB Installation is Skipped if efiSystemPartition is
  Defined in Configuration" (7 yorum) — efi ayarı verildiğinde BIOS yolu
  atlanabiliyor; Kavis hem UEFI hem BIOS'u QEMU duman testinde denemeli.
- **Otomatik btrfs bölümleme hataları** (57 ve 18 yorumlu kapanmış
  issue'lar: "Automatic installation partition Btrfs fails",
  "automatic partition task fail with swap"): btrfs + swap kombinasyonu
  tarihsel olarak sorunlu; 3.3.14'te düzeltilmiş olsa da CI'da gerçek
  kurulum testi şart.
- **LUKS/şifreleme**: birden çok açık issue (LUKS2 hizalama hatası,
  "could not close encrypted partition", segfault). Kavis şifreleme
  sunacaksa `luksGeneration` ve KPMcore sürümüne dikkat.
- **`initialSwapChoice: file` elle bölümlemede uyarısız swapfile
  oluşturuyor** (kapalı): swap seçimini kullanıcıya net göstermek gerek.
- **`displayAutologin` varsayılan olarak etkin değil** (açık, 3 yorum):
  autologin kutusunun görünmesi conf'ta açıkça istenmeli.
- **"The swapon command is executed twice"** (kapalı): mount/fstab fazları
  arasında swap iki kez etkinleştirilebiliyordu.
- Kapanış/umount aşaması btrfs'te "Could not unmount btrfs root"
  şikâyetleri (dağıtıma özgü, kapalı) — umount modülü sırasına dikkat.

## Kavis için çıkarımlar

- **Olduğu gibi kullanılır**: welcome, locale, keyboard, users,
  summary, mount (btrfsSubvolumes ile `/@a` kökü + `/@users`), unpackfs,
  fstab, machineid, networkcfg, hwclock, services-systemd, displaymanager
  (lightdm autologin), grubcfg/bootloader, umount. Trixie'nin 3.3.14
  paketi yeterli; kaynaktan derleme gerekmez.
- **Yapılandırma ile çözülür**: koyu branding (branding.desc + QSS + QML
  slideshow, metinler `docs/kavis-arayuz-metinleri.md`'den),
  `defaultFileSystemType: btrfs`, `userSwapChoices` seçimi,
  `partitionLayout`, `doAutologin`.
- **Özel Python modülü gerekir**: (1) A/B düzeni — @b subvolume'unun
  oluşturulması ve bootloader'ın iki kökü tanıması (madde 27C); (2) btrfs
  swapfile ile hibernate isteniyorsa `resume=` + `resume_offset=` üretimi
  (madde 51A) — aksi halde `suspend` swap bölümü tercih edilip özel modül
  hiç yazılmayabilir; bu, en az riskli yol.
- İlk kurulum testleri CI'da hem UEFI hem BIOS için koşmalı; btrfs+swap
  kombinasyonu ve umount aşaması, issue geçmişine göre en olası kırılma
  noktaları.
