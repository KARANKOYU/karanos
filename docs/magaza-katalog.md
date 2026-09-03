# Kavis Mağaza — katalog taslağı (Grup G hazırlığı)

Üretildi: 2026-09-03. Okunabilir sürüm; mağazanın okuduğu veri
`data/store-catalog.json` (ISO'ya girer — çevrimdışı tam liste,
çevrimiçi kendini günceller; bağlantı yokken Yükle düğmesi gri +
"İnternet gerekli"). Kurallar docs/kararlar.md 1'de: apt +
Flathub + Resmî üçü de varsa üçü de listelenir, aynı anda tek
kaynaktan kurulu olunur. Resmî girdilerin sha256 alanları şimdilik
boş; sürüm kontrol adresleri JSON'da.

Kaynak doğrulaması: apt adları Debian trixie arşiv indeksinden
(tools/check-packages.sh önbelleği), Flathub id'leri
flathub.org/api/v2/appstream listesinden doğrulandı. Debian'da ve
Flathub'da olmayan + resmî kurucusu olmayan girdiler Toolbox'ta.

| Özet | Değer |
|---|---|
| Uygulama sayısı | 128 |
| apt kaynağı olan | 88 |
| Flathub kaynağı olan | 58 |
| Resmî kurucusu olan | 27 |
| Toolbox (1.0 sonrası) | 8 |

## İnternet

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| Firefox | Web tarayıcısı | `firefox-esr` | `org.mozilla.firefox` | — | öne çıkan |
| Google Chrome | Google'ın web tarayıcısı | — | `com.google.Chrome` | deb | — |
| Chromium | Açık kaynak web tarayıcısı | `chromium` | `org.chromium.Chromium` | — | — |
| Brave | Gizlilik odaklı tarayıcı | — | `com.brave.Browser` | sh | — |
| Thunderbird | E-posta istemcisi | `thunderbird` | `org.mozilla.thunderbird` | — | — |
| qBittorrent | BitTorrent istemcisi | `qbittorrent` | `org.qbittorrent.qBittorrent` | — | — |
| FileZilla | FTP/SFTP istemcisi | `filezilla` | `org.filezillaproject.Filezilla` | — | — |
| Transmission | Hafif BitTorrent istemcisi | `transmission-gtk` | `com.transmissionbt.Transmission` | — | — |

## İletişim

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| Discord | Sesli ve yazılı sohbet | — | `com.discordapp.Discord` | deb | öne çıkan |
| Telegram | Mesajlaşma uygulaması | — | `org.telegram.desktop` | tar | — |
| Zoom | Görüntülü toplantı | — | `us.zoom.Zoom` | deb | — |
| Signal | Gizlilik odaklı mesajlaşma | — | `org.signal.Signal` | deb | — |
| Slack | Ekip iletişimi | — | `com.slack.Slack` | deb | — |
| Teams for Linux | Resmî olmayan Microsoft Teams sarmalayıcısı | — | `com.github.IsmaelMartinez.teams_for_linux` | — | — |
| Element | Matrix sohbet istemcisi | — | `im.riot.Riot` | — | — |

## Ofis

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| LibreOffice | Ofis paketi | `libreoffice` | `org.libreoffice.LibreOffice` | — | öne çıkan |
| OnlyOffice | MS Office uyumlu ofis paketi | — | `org.onlyoffice.desktopeditors` | deb | — |
| Obsidian | Markdown not ve bilgi tabanı | — | `md.obsidian.Obsidian` | deb | — |
| Joplin | Not ve yapılacaklar | — | `net.cozic.joplin_desktop` | sh | — |
| Xournal++ | El yazısı ve PDF işaretleme | `xournalpp` | `com.github.xournalpp.xournalpp` | — | — |
| Okular | Belge görüntüleyici | `okular` | `org.kde.okular` | — | — |

## Medya

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| VLC | Her formatı oynatır | `vlc` | `org.videolan.VLC` | — | öne çıkan |
| mpv | Sade video oynatıcı | `mpv` | `io.mpv.Mpv` | — | — |
| Spotify | Müzik akışı | — | `com.spotify.Client` | deb | öne çıkan |
| Audacity | Ses düzenleyici | `audacity` | `org.audacityteam.Audacity` | — | — |
| OBS Studio | Ekran kaydı ve yayın | `obs-studio` | `com.obsproject.Studio` | — | — |
| Kdenlive | Video düzenleyici | `kdenlive` | `org.kde.kdenlive` | — | — |
| Shotcut | Basit video düzenleyici | `shotcut` | `org.shotcut.Shotcut` | — | — |
| HandBrake | Video dönüştürücü | `handbrake` | `fr.handbrake.ghb` | — | — |

## Grafik

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| GIMP | Görsel düzenleyici | `gimp` | `org.gimp.GIMP` | — | öne çıkan |
| Inkscape | Vektör çizim | `inkscape` | `org.inkscape.Inkscape` | — | — |
| Krita | Dijital boyama | `krita` | `org.kde.krita` | — | — |
| Blender | 3B üretim paketi | `blender` | `org.blender.Blender` | — | öne çıkan |
| darktable | RAW fotoğraf işleme | `darktable` | `org.darktable.Darktable` | — | — |

## Geliştirme

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| Visual Studio Code | Kod editörü | — | `com.visualstudio.code` | deb | öne çıkan |
| VSCodium | Telemetrisiz VS Code | — | `com.vscodium.codium` | deb | — |
| Kate | Gelişmiş metin editörü | `kate` | `org.kde.kate` | — | — |
| Neovim | Modern Vim | `neovim` | `io.neovim.nvim` | — | — |
| Git | Sürüm denetimi | `git` | — | — | — |
| Docker | Konteynerler | `docker.io` | — | — | — |
| Python 3 | Python yorumlayıcısı | `python3` | — | — | — |
| Node.js | JavaScript çalışma ortamı | `nodejs` | — | — | — |
| Java (OpenJDK) | Java geliştirme kiti | `default-jdk` | — | — | — |
| Arduino IDE | Mikrodenetleyici programlama | `arduino` | `cc.arduino.IDE2` | — | — |
| PlatformIO | Gömülü geliştirme platformu | — | — | sh | — |
| Godot | Oyun motoru | `godot3` | `org.godotengine.Godot` | — | — |
| Unity Hub | Unity motor yöneticisi | — | `com.unity.UnityHub` | deb | — |

## Oyun

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| Steam | Oyun mağazası ve başlatıcısı | `steam-installer` | `com.valvesoftware.Steam` | deb | öne çıkan |
| Lutris | Tüm mağazalar için oyun yöneticisi | `lutris` | `net.lutris.Lutris` | — | — |
| Heroic | Epic ve GOG başlatıcısı | — | `com.heroicgameslauncher.hgl` | — | — |
| Minecraft Launcher | Resmî Minecraft başlatıcısı | — | — | deb | — |
| Prism Launcher | Minecraft örnek yöneticisi | — | `org.prismlauncher.PrismLauncher` | — | — |
| RetroArch | Emülatör arayüzü | `retroarch` | `org.libretro.RetroArch` | — | — |
| Wine | Windows programlarını çalıştırır | `wine` | — | — | — |
| ProtonUp-Qt | Proton sürümleri yönetimi | — | `net.davidotek.pupgui2` | — | — |

## Eğitim

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| GeoGebra | Etkileşimli matematik | `geogebra` | `org.geogebra.GeoGebra` | — | — |
| Anki | Kartlarla ezber | — | `net.ankiweb.Anki` | tar | — |
| Stellarium | Gökyüzü simülatörü | `stellarium` | `org.stellarium.Stellarium` | — | — |
| Kalzium | Periyodik tablo (KDE Edu) | `kalzium` | — | — | — |
| Marble | Sanal yerküre (KDE Edu) | `marble` | — | — | — |
| KStars | Astronomi (KDE Edu) | `kstars` | — | — | — |
| GCompris | Çocuklar için eğitici oyunlar | `gcompris-qt` | `org.kde.gcompris` | — | — |
| Scratch | Çocuklar için görsel programlama | — | `edu.mit.Scratch` | — | — |
| TurboWarp | Hızlandırılmış Scratch | — | `org.turbowarp.TurboWarp` | — | — |

## Sistem araçları

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| GParted | Bölüm düzenleyici | `gparted` | — | — | — |
| Timeshift | Sistem anlık görüntüleri | `timeshift` | — | — | — |
| htop | Süreç görüntüleyici | `htop` | — | — | — |
| btop | Kaynak izleyici | `btop` | — | — | — |
| BleachBit | Disk temizleyici | `bleachbit` | — | — | — |
| GNOME Disks | Disk yönetimi | `gnome-disk-utility` | — | — | — |
| balenaEtcher | ISO'yu USB'ye yazar | — | — | appimage | — |
| Ventoy | Çok ISO'lu USB bellek | — | — | tar | — |
| CPU-X | Donanım bilgisi | `cpu-x` | `io.github.thetumultuousunicornofdarkness.cpu-x` | — | — |

## Güvenlik araçları

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| Nmap | Ağ tarayıcı | `nmap` | — | — | — |
| Wireshark | Paket çözümleyici | `wireshark` | `org.wireshark.Wireshark` | — | — |
| tcpdump | Komut satırı paket yakalama | `tcpdump` | — | — | — |
| masscan | Hızlı port tarayıcı | `masscan` | — | — | — |
| netcat | TCP/UDP çakısı | `netcat-openbsd` | — | — | — |
| Burp Suite Community | Web güvenlik testi | — | — | sh | — |
| ZAP | Web uygulama tarayıcısı | — | `org.zaproxy.ZAP` | sh | — |
| sqlmap | SQL enjeksiyon testi | `sqlmap` | — | — | — |
| Nikto | Web sunucu tarayıcısı | `nikto` | — | — | — |
| Gobuster | Dizin/DNS kaba kuvvet | `gobuster` | — | — | — |
| ffuf | Web fuzz aracı | `ffuf` | — | — | — |
| Wfuzz | Web fuzz aracı | `wfuzz` | — | — | — |
| John the Ripper | Parola denetimi | `john` | — | — | — |
| hashcat | GPU ile parola kurtarma | `hashcat` | — | — | — |
| Hydra | Oturum kaba kuvvet | `hydra` | — | — | — |
| hashID | Hash tanımlayıcı | `hashid` | — | — | — |
| Aircrack-ng | Wi-Fi güvenlik denetimi | `aircrack-ng` | — | — | — |
| Kismet | Kablosuz dinleyici | — | — | deb | — |
| Reaver | WPS saldırı aracı | `reaver` | — | — | — |
| Wifite | Otomatik Wi-Fi denetimi | `wifite` | — | — | — |
| Ghidra | Tersine mühendislik paketi | — | — | tar | — |
| radare2 | Tersine mühendislik çatısı | — | — | deb | — |
| Binwalk | Firmware analizi | `binwalk` | — | — | — |
| GDB | GNU hata ayıklayıcı | `gdb` | — | — | — |
| strace | Sistem çağrısı izleyici | `strace` | — | — | — |
| ltrace | Kitaplık çağrısı izleyici | `ltrace` | — | — | — |
| Autopsy | Adli bilişim arayüzü | `autopsy` | — | — | — |
| The Sleuth Kit | Adli bilişim araç seti | `sleuthkit` | — | — | — |
| Foremost | Dosya kurtarma | `foremost` | — | — | — |
| TestDisk | Bölüm kurtarma | `testdisk` | — | — | — |
| Recon-ng | Keşif çatısı | `recon-ng` | — | — | — |
| Sherlock | Sitelerde kullanıcı adı arama | `sherlock` | — | — | — |
| Tor | Anonimlik ağı | `tor` | — | — | — |
| Tor Browser | Anonim gezinme | `torbrowser-launcher` | `org.torproject.torbrowser-launcher` | — | — |
| ProxyChains | Uygulamaları vekilden geçirir | `proxychains4` | — | — | — |
| VeraCrypt | Disk şifreleme | — | — | deb | — |
| KeePassXC | Parola yöneticisi | `keepassxc` | `org.keepassxc.KeePassXC` | — | öne çıkan |
| GnuPG | Şifreleme ve imzalama | `gnupg` | — | — | — |
| cryptsetup | LUKS disk şifreleme | `cryptsetup` | — | — | — |

## Sürücüler

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| NVIDIA sürücüsü | Kapalı kaynak NVIDIA sürücüsü | `nvidia-driver` | — | — | — |
| Broadcom Wi-Fi | Broadcom STA kablosuz sürücüsü | `broadcom-sta-dkms` | — | — | — |
| Realtek firmware | Realtek Wi-Fi/Ethernet firmware'i | `firmware-realtek` | — | — | — |
| Yazıcı temel paketi | Yazıcı sürücü tabanı | `cups-filters` | — | — | — |
| HP yazıcılar | HP yazıcı sürücüleri | `hplip` | — | — | — |
| Gutenprint | Geniş yazıcı desteği | `printer-driver-gutenprint` | — | — | — |
| Tarayıcı desteği | Tarayıcı sürücüleri (SANE) | `sane-airscan` | — | — | — |
| Xbox kolu | Xbox oyun kolu sürücüsü (xpadneo) | — | — | sh | — |

## Toolbox (1.0 sonrası)

| Uygulama | Açıklama | apt | Flathub | Resmî | Not |
|---|---|---|---|---|---|
| Volatility 3 | Bellek adli analizi | — | — | — | Toolbox (1.0 sonrası) |
| Metasploit | Sömürü çatısı | — | — | — | Toolbox (1.0 sonrası) |
| theHarvester | OSINT toplama | — | — | — | Toolbox (1.0 sonrası) |
| SpiderFoot | OSINT otomasyonu | — | — | — | Toolbox (1.0 sonrası) |
| Distrobox | Konteynerde başka dağıtımlar | `distrobox` | — | — | Toolbox (1.0 sonrası) |
| Kali konteyneri | Distrobox ile Kali araçları | — | — | — | Toolbox (1.0 sonrası) |
| Ubuntu konteyneri | Distrobox ile Ubuntu | — | — | — | Toolbox (1.0 sonrası) |
| Arch konteyneri | Distrobox ile Arch | — | — | — | Toolbox (1.0 sonrası) |

## Öne çıkanlar sekmesi

Firefox, Discord, LibreOffice, VLC, Spotify, GIMP, Blender, Visual Studio Code, Steam, KeePassXC.
