# Grup E — sorun önleme taraması (madde 59)

Tarih: 2026-09-02. Nemo'nun taraması zaten ayrıntılı yapılmıştı:
[`nemo.md`](nemo.md) (tuzaklar bölümü + madde 39 karşılaştırma
tablosu) — burada tekrarlanmıyor. Aşağıdakiler Grup E'nin diğer
bileşenleri (en çok yorum alan açık issue'lar, GitHub API; Kate için
KDE Bugzilla API taranamadı, bilinen şikâyetler yazıldı).

## udisks (madde 42/63/64 — otomatik bağlama, güvenli çıkar, onarım)

En çok yorumlanan açık issue'lardan (2026-09-02):

- **eMMC/sabit aygıt "çıkarılabilir" sanılıyor** (#358, 34 yorum):
  udisks'in `removable` bayrağı yanılabilir. Çıkarım: USB listemiz
  (63) `removable`a değil **bus == "usb"** bilgisine bakmalı; tepsi
  UsbIndicator zaten öyle yapıyor, koruyalım.
- **Housekeeping 10 dakikada bir diskleri uyandırıyor** (#892/#407):
  SMART yoklaması uyuyan diski döndürüyor. Çıkarım: 42'nin SMART
  ekranı isteğe bağlı yoklasın, arka planda periyodik SMART sorgusu
  KOYMAYALIM.
- **Btrfs çok-aygıt otomatik bağlamada veri riski** (#88/#802):
  eksik üyeli btrfs'i bağlamaya çalışmak tehlikeli. Çıkarım: onarım
  aracı (64) btrfs'e fsck ÖNERMEZ (btrfs check zaten ayrı dünya);
  64 kapsamı bilinçli olarak ext4/FAT/NTFS ile sınırlı kalıyor.
- **NTFS: ntfs3 (çekirdek) vs ntfs-3g karışıklığı** (#818): trixie'de
  her ikisi de var; udisks hangisini seçerse ona göre davranış
  değişir. Çıkarım: 42'de bağlama hatasında hangi sürücünün
  kullanıldığını günlüğe yaz; onarımda `ntfsfix` yalnız ntfs-3g
  tarafını düzeltir, "Windows'ta chkdsk çalıştırın" önerisi mesajda
  kalmalı (ntfsfix'in kendi belgesindeki sınır).
- **udisksd nadiren %100 CPU** (#850): çözümsüz eski kayıt; duman
  testine "udisksd CPU" bakışı eklemek yeterli, önlem alınamaz.

## system-config-printer / CUPS (madde 43 — yazıcı)

- s-c-p issue'ları az ve çoğu bakım konusu; en anlamlısı **#48:
  udev-add-printer D-Bus hatası** — USB yazıcı takılınca otomatik
  kurulum servisi yoksa sessizce düşüyor. Çıkarım: sihirbazımız
  cups + cups-browsed çalışıyor mu diye önce bakmalı, değilse
  anlaşılır mesaj ("Yazdırma servisi başlatılıyor…" + systemctl).
- **#312 (renkliye geri dönüş yok)**: seçenek adları PPD'ye göre
  değişiyor. Çıkarım: sihirbaz PPD seçeneklerini olduğu gibi listeler,
  kendi renk anahtarımızı icat etmeyiz.
- CUPS tarafında modern gerçek: **sürücüsüz (IPP Everywhere/AirPrint)
  yazıcılar çoğunlukta** — `cups-browsed` + Avahi ağ yazıcısını
  kendiliğinden gösterir. Çıkarım: sihirbazın birinci yolu "keşfet ve
  seç" (ipp://), PPD/sürücü arama İKİNCİ yol; çoğu kullanıcı sürücü
  hiç görmemeli. mDNS için `avahi-daemon` paket listesine açıkça
  yazılmalı (Recommends kapalı tuzağı).
- Web arayüzü (631) dışarı kapalı kalmalı: cupsd.conf varsayılanı
  zaten localhost; hook'la doğrulanır, değiştirilmez.

## Kate (madde 40 — kod editörü; KDE Bugzilla, API taranamadı)

Bilinen tekrar eden şikâyetler (bugs.kde.org sık kayıtları):

- **KDE dışı masaüstünde bağımlılık kuyruğu**: Kate, KF6/Qt6 yığını
  çeker (trixie'de ~80-100 MB kurulu). ISO şişmesi 1.5 GB sınırına
  bakılarak CI'da ölçülecek; şişme kabul edilemezse ONAY BEKLEYEN'e
  alternatifle dönülür.
- **Oturum/yan panel karmaşası**: yeni kullanıcı için açılışta
  "oturum seç" diyaloğu ve kalabalık araç görünümleri şaşırtıcı.
  Çıkarım: kateschemarc/katerc varsayılanlarını iskelete koy —
  tek pencere, oturum sorusu kapalı, koyu tema (Kavis renkleri),
  satır numarası açık.
- **GTK/Qt tema uyumsuzluğu**: koyu GTK temamız Qt uygulamasına
  uygulanmaz. Çıkarım: `qt6ct` veya `QT_QPA_PLATFORMTHEME` ile koyu
  palet; kavis-theme'e Kate renk şeması (`.theme` JSON) eklenebilir.

## Terminal (madde 40)

ISO'daki lxterminal sekme destekler ama bölünmüş pencere yok.
Adaylar trixie'de: `xfce4-terminal` (sekme + koyu tema, bölme yok),
`tilix` (bölme var; GTK3+VTE, bakımı yavaşladı), `sakura` (sade).
Bölünmüş pencere şartını en hafif karşılayan tilix; bakım riski
ONAY BEKLEYEN'e yazılır. Karar uygulama sırasında verilecek.

## Arşiv / file-roller (madde 39 arşiv kısmı)

- nemo-fileroller sıkıştırmayı file-roller'a delege eder (nemo.md).
  Tekrarlayan şikâyet: **rar/7z ikilileri yoksa format listede sessizce
  görünmez** — p7zip-full, unrar(-free değil, non-free!), zstd, pigz
  paket listesine açıkça girmeli. `unrar` non-free bileşeni gerektirir;
  ISO'da non-free zaten açık (firmware), sorun değil.
- file-roller çok çekirdekli sıkıştırmayı kendisi seçmez; "en hızlı
  yöntem" isteği için varsayılan formatı zstd/7z yapmak yeterli,
  file-roller'ı yamalamayız.

## command-not-found (madde 44)

- Debian'daki `command-not-found` paketi apt-file veritabanı ister ve
  ilk çalıştırmada güncelleme bekler; canlı ISO'da veritabanı
  DERLEMEDE hazırlanmalı (hook'ta `apt-file update` + c-n-f
  önbelleği), yoksa ilk deneme "veritabanı yok" hatası verir.
- dnf/pacman/zypper çevirisi c-n-f'in işi değil — bizim küçük bash
  kancamız (command_not_found_handle) c-n-f'i sarmalar.

## Özet — uygulamaya taşınan kararlar

1. USB listesi `removable` değil bus=usb ile (63) — mevcut davranış.
2. Arka planda periyodik SMART yok; ekran açıkken sorgula (42).
3. Onarım (64) yalnız ext4/FAT/NTFS; btrfs'e dokunmaz; NTFS mesajında
   chkdsk önerisi kalır.
4. Yazıcıda birinci yol sürücüsüz IPP keşfi; avahi-daemon listeye (43).
5. Kate boyutu CI'da ölçülür; Qt koyu tema ayrıca verilir (40).
6. apt-file veritabanı derlemede hazırlanır (44).
7. unrar (non-free), p7zip-full, zstd, pigz açıkça listeye (39).
