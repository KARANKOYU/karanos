# docs/referans/ — referans incelemeleri

Madde 47 gereği dokuz proje `/tmp/referans` altına sığ klonlanıp incelendi
(2026-09-01), özetler buraya yazıldı ve klonlar silindi. KESİN KURAL:
bu projelerden **kod kopyalanmaz** — yalnızca yaklaşım öğrenilir.

Bir gruba başlamadan önce ilgili özet(ler) okunur:

| Belge | İlgili maddeler | Ne zaman oku |
|---|---|---|
| `picom.md` | 2, 4, 38, 13 | Grup B (picom) ve Grup D (görünüm) |
| `bazzite.md` | 13 + strateji | Grup B (sysctl kısmı madde 8'e de girdi) ve Grup H |
| `gamescope.md` | 13 | Grup H |
| `nemo.md` | 39, 36 | Grup E |
| `flameshot.md` | 29 | Grup D |
| `calamares.md` | 16, 27C, 51A | Grup I (disk düzeni kararından ÖNCE) |
| `mintdrivers.md` | 35 | Grup I |
| `mintupdate.md` | 26 | Grup J |
| `mintinstall.md` | 12, 41, 23 | Grup G |
| `virtualbox.md` | açılış deneyimi, 38, 35 | VirtualBox el testinden önce; Grup F (günlük tarama) |

## Kesişen bulgular (birden çok grubu etkileyenler)

- **Trixie'de olmayan paketler:** `ubuntu-drivers-common` (tespit Debian'da
  `nvidia-detect` + `isenkram` ile), `gamescope` (yalnız
  trixie-backports/contrib, 3.16.22), `bulky` (yerine `gprename`),
  `nemo-preview` (kendi önizleyicimiz `org.nemo.Preview` D-Bus adını
  sahiplenecek), scx zamanlayıcılar. `tools/check-packages.sh` yalnız ana
  arşive bakıyor; backports'tan paket alınacaksa araca istisna eklenmeli.
- **Recommends tuzağı yine:** nemo'nun `gvfs-backends`, `gvfs-fuse`,
  `nemo-fileroller`, `librsvg2-common` paketleri Recommends — paket
  listesine açıkça yazılmalı (CLAUDE.md'deki bilinen tuzağın yeni örneği).
- **polkit > sudoers:** Mint araçları yer yer sudoers NOPASSWD kestirmesi
  kullanıyor ve bu güvenlik issue'sı üretmiş; Kavis'te root gerektiren her
  iş polkit eylemi olacak (mintdrivers.md, mintupdate.md).
- **Sonsuz spinner yasağı:** üç Mint aracında da en çok şikâyet edilen
  davranış, zaman aşımı/hata sayfası olmayan async işler. Her async yola
  zaman aşımı + hata durumu baştan konacak.
- **Kaynak-bağımsız paket modeli:** mintinstall'ın "kaynak önekli tek
  PkgInfo + ince UI" katmanlaması, mağazanın (12/41) temel mimari kararı
  olarak alındı.
- **Snapshot işleme bağlanacak:** mintupdate güncelleme öncesi otomatik
  snapshot ALMIYOR (yaygın kanının aksine); madde 26'daki otomatik btrfs
  snapshot bizim ek değerimiz.
- **VM sınırları:** gamescope (Vulkan) ve picom blur (glx) QEMU'da
  çalışmaz/çalışmamalı; CI görsel testleri xrender yoluyla sınırlı, oyun
  modu yalnız gerçek donanımda test edilir.
- **Güvenli geri dönüş ilkesi:** bazzite issue'larının dersi — oturum/mod
  geçiş zincirinin herhangi bir halkası koptuğunda kullanıcı siyah ekranda
  kalmamalı; her mod geçişi (oyun modu, kurtarma) masaüstüne dönüş
  garantisiyle tasarlanacak.
