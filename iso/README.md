# iso/ — ISO yapılandırması

Debian trixie tabanlı Karan OS ISO'sunun `live-build` yapılandırması.

## ⚠️ Bu klasörde yerelde derleme YAPMA

ISO **GitHub Actions'ta** derlenir. Codespace'te derlemenin üç sorunu var:

1. 2 çekirdek — debootstrap + squashfs sıkıştırma 40+ dakika sürer
2. Disk — chroot + squashfs + ISO aynı anda ~15 GB ister, elimizde 20 GB boş var
3. Sonuçta çıkan 1+ GB'lık ISO'yu 470 Kbps ile indirmek 6-7 saat sürer

Bunun yerine: **derleme + QEMU testi Actions'ta**, sonuç seri konsol
günlüğü olarak geri gelir. ISO'yu sadece gerçek USB testine hazır olduğunda
indirirsin.

## Derlemeyi başlatma

GitHub → **Actions** sekmesi → **"ISO derle ve test et"** → **Run workflow**
→ (isteğe bağlı sürüm gir) → **Run workflow**

`iso/` altında bir şey değiştirip `main`'e push ettiğinde de kendiliğinden çalışır.

Sonuç:
- **Summary** bölümünde ISO boyutu ve sha256
- **Artifacts** altında `karanos-iso` (14 gün saklanır)
- Her boot modu için `serial-bios`, `serial-uefi`, `serial-secureboot` günlükleri

## Push etmeden önce yerelde çalıştırılacak kontroller

```bash
# Paket adları Debian trixie arşivinde gerçekten var mı? (~2 saniye)
tools/check-packages.sh

# Script'lerin sözdizimi
tools/check-config.sh
```

Bu ikisi geçmeden push etme — CI derlemesi 40 dakika, yazım hatası için beklemeye değmez.

## Yapı

```
iso/
├── auto/
│   ├── config          ← TÜM lb config parametreleri burada (elle lb config verme)
│   ├── build
│   └── clean
└── config/
    ├── package-lists/
    │   ├── 01-base.list.chroot       çekirdek, init, ağ, dosya sistemleri, önyükleyici
    │   ├── 02-x11.list.chroot        X11 + Openbox + terminal + Python/GTK
    │   └── 03-firmware.list.chroot   Wi-Fi/ses/grafik firmware'i (prompt 16)
    ├── includes.chroot/              ISO'ya olduğu gibi kopyalanan dosyalar
    │   ├── etc/lightdm/lightdm.conf.d/60-karanos-live.conf   canlı otomatik giriş (geçici)
    │   ├── etc/xdg/openbox/autostart                          oturum başlangıcı
    │   ├── etc/systemd/system/karanos-boot-check.service      CI duman testi
    │   └── usr/lib/karanos/boot-check                         "boot ettim mi" script'i
    └── hooks/normal/
        ├── 0100-karanos-services.hook.chroot   servisleri etkinleştir
        ├── 9990-apt-recommends.hook.chroot     kurulu sistemde Recommends'i aç
        └── 9995-cleanup.hook.chroot            boyut temizliği
```

## Bilerek verilmiş kararlar

| Karar | Neden |
|---|---|
| `--apt-recommends false` | Hafiflik (prompt 20). Bedeli: gereken her paketi listede açıkça yazmak. Kurulu sistemde `9990` hook'u ile geri açılıyor. |
| `--firmware-chroot false` + elle liste | live-build'in tüm `firmware-*` paketlerini gelişigüzel eklemesini istemiyoruz; prompt 16'daki listeyi kontrollü veriyoruz. |
| `--uefi-secure-boot enable` | Debian'ın imzalı `shim` + `grub`'unu kullanır. Kendi çekirdeğimizi derlemiyoruz, bu yüzden Secure Boot açık kalabiliyor (prompt 2, 18). |
| `--debian-installer none` | Kurulum Calamares ile (prompt 14). Debian Installer ISO'ya gömülmüyor. |
| `console=ttyS0` açılış satırında | CI'daki QEMU testinin boot günlüğünü okuyabilmesi için. Seri portu olmayan gerçek donanımda etkisi yok. |
| `quiet splash` **kapalı** | 1. aşamada boot mesajlarını görmek istiyoruz. 3. aşamada (Plymouth) açılacak. |
| lightdm otomatik giriş | Geçici. 5. aşamada `karanos-greeter` gelince kalkacak; kurulan sistemde Calamares bu dosyayı siliyor. |

## Bir sonraki aşamaya geçince değişecekler

- **2. aşama:** `karanos-theme` paketi listeye girer, `/etc/os-release` değişir
- **3. aşama:** `plymouth` + `karanos-boot` girer, açılış satırına `quiet splash` eklenir
- **4. aşama:** `openbox/autostart` içine `karanos-panel` eklenir
- **5. aşama:** `lightdm` yerine `karanos-greeter`, `60-karanos-live.conf` silinir
