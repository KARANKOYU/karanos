<p align="center">
  <img src="assets/logo/k-logo.svg" width="120" alt="Karan OS">
</p>

<h1 align="center">Karan OS</h1>

<p align="center">
  Debian tabanlı, Windows benzeri masaüstüne sahip kişisel Linux dağıtımı.<br>
  <i>made by Karan</i>
</p>

---

## Nedir

x86_64 mimarisinde, Debian trixie tabanlı bir masaüstü dağıtımı. Kendi açılış
ekranı, giriş ekranı, görev çubuğu, ayarlar uygulaması ve uygulama mağazası
var. Kendi çekirdeğimizi derlemiyoruz — Debian'ın imzalı çekirdeğini
kullanıyoruz, böylece Secure Boot açık kalabiliyor.

| Konu | Karar |
|---|---|
| Taban | Debian stable (trixie), `live-build` |
| Görüntü sunucusu / WM | X11 + Openbox |
| Kendi yazılımlarımız | Python 3 + GTK3 (PyGObject) |
| Kök dosya sistemi | btrfs (`@` + `@users`) |
| Kurulum aracı | Calamares |
| Hedef ISO boyutu | 1.5 GB altı |
| Boşta RAM | 1 GB altı hedef, en fazla 1.5 GB |

## Depo yapısı

```
karanos/
├── assets/       elle konulan kaynak dosyalar (logo, açılış görseli/müziği)
├── docs/         kurulum ve tasarım notları
├── iso/          live-build yapılandırması
├── packages/     karanos-* .deb paketlerinin kaynağı
├── installer/    Calamares yapılandırması + ön kontrol modülü
├── tools/        geliştirme yardımcıları (kontroller, QEMU testi)
└── .github/workflows/   ISO derleme + paket üretimi
```

## Derleme

**ISO yerelde derlenmez.** Derleme ve QEMU testi GitHub Actions'ta yapılır:

GitHub → **Actions** → **"ISO derle ve test et"** → **Run workflow**

Ayrıntılar: [`iso/README.md`](iso/README.md)

Push etmeden önce:

```bash
tools/check-config.sh      # sözdizimi, izinler, YAML
tools/check-packages.sh    # paket adları Debian arşivinde var mı
```

Kendi paketlerimiz yerelde derlenebiliyor (ISO'nun aksine hızlı):

```bash
tools/build-packages.sh          # packages/* → out/packages/*.deb
tools/theme-screenshot.sh        # temayı Xvfb'de çizip PNG'ye al
```

## Kurulum (GitHub tarafı)

Depolar, GitHub Pages, GPG anahtarı ve secret'lar için:
[`docs/github-kurulumu.md`](docs/github-kurulumu.md)

## Elle konulacak dosyalar

| Dosya | Durum |
|---|---|
| `assets/logo/k-logo.svg` | ✅ hazır |
| `assets/boot/boot-image.png` | ⏳ [özellikler](assets/boot/README.md) |
| `assets/boot/boot-sound.mp3` | ⏳ [özellikler](assets/boot/README.md) |

## Geliştirme sırası

| # | Aşama | Durum |
|---|---|---|
| 1 | Boot eden çıplak ISO (X11 + Openbox + terminal) | ✅ BIOS/UEFI/Secure Boot üçü de açılıyor |
| 2 | Tema paketi (renkler, logo, imleç, GTK) | 🔨 paket hazır, masaüstü oturumu düzeltildi, CI doğrulaması bekliyor |
| 3 | Açılış ekranı (görsel + parlama + mp3) | 🔨 paket hazır, CI doğrulaması bekliyor |
| 4 | Panel: görev çubuğu + başlat menüsü | ⏳ |
| 5 | Giriş ekranı + kilit ekranı | ⏳ |
| 6 | Kullanıcı/dizin yapısı + bind mount koruması | ⏳ |
| 7 | Kurulum sihirbazı | ⏳ |
| 8 | Ayarlar uygulaması | ⏳ |
| 9 | Karan OS Mağaza | ⏳ |
| 10 | Görev yöneticisi + küçük araçlar | ⏳ |
| 11 | Calamares kurulum aracı + canlı mod | ⏳ |
| 12 | Kurtarma ortamı | ⏳ |
| 13 | APT deposu + GitHub Actions | ⏳ |
| 14 | Gerçek donanımda test | ⏳ |

Karar günlüğü: [`docs/durum.md`](docs/durum.md) ·
Tam görev tanımı: [`docs/karanos-claude-code-prompt.md`](docs/karanos-claude-code-prompt.md) ·
Arayüz metinleri (TR/EN): [`docs/karanos-arayuz-metinleri.md`](docs/karanos-arayuz-metinleri.md) ·
GitHub kurulumu: [`docs/github-kurulumu.md`](docs/github-kurulumu.md)
