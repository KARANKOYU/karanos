# Kavis — yol haritası ve sürüm planı

Bu belge olmadan proje sonsuza kadar "bitmemiş" kalır. Kural: her grup
bitiminde bu belge güncellenir — biten grubun durumu işaretlenir,
kapsam değiştiyse sürüm eşlemesi düzeltilir.

Madde numaraları görev listesindeki numaralardır (Grup A talimatı,
2026-09-01). Gruplar sırayla yapılır; her grubun sonunda durulur, özet
verilir ve onay beklenir.

## Sürüm eşlemesi

| Sürüm | Gruplar | İçerik (özet) | Durum |
|---|---|---|---|
| 0.2 | A, A2, B | CI iyileşti, Kavis markası, picom, yeni boot splash + F3, autologin + `/users/karan`, güvenlik sertleştirme, CI test altyapısı | ✅ A, A2, B (v0.2-test3 koşusunda doğrulandı; VirtualBox el testi bekliyor) |
| 0.3 | C, D | C/Vala panel, görev çubuğu görünümü + sağ tık, pencere yönetimi/snap/Alt+Tab, sanal masaüstleri, takvim + bildirim, görev yöneticisi + küçük araçlar, ekran görüntüsü/kaydı, GTK ortak başlangıç (61), hypervisor uyarı listesi (62) | 🔨 C ✅, D kod ✅ (v0.3-test5 5/5 yeşil) + VM geri bildirim turu ✅ (2 Eyl: sol hizalama vars., W11 bildirim merkezi + ayrı hızlı ayarlar, tepsi araçları USB/Wi-Fi, emoji arama, donmuş kare ekran görüntüsü — flameshot/slop çıktı, splash boşluk karşılığı; panel RSS 36 MB) + boot-sound/EN-varsayılan/gettext işleri ✅ + sonraki-isler.md 6 bölümü ✅ (2 Eyl: hover/gruplama, sabitleme+Win+sayı, W11 başlık çubuğu, Win+Z snap menüsü, Emoji-ve-daha-fazlası birleşik paneli + kalıcı pano + renk seçici, OSD süreci/sistem sesleri/Bununla aç/Ctrl+Alt+Del/Alt+F4/dosya bırakma/touchpad; debug turu: menü sızıntısı kapandı, panel 37 MB RSS) — v0.3-test7 CI + VirtualBox el testi bekliyor |
| 0.4 | E | Dosya yöneticisi (nemo), hızlı önizleme, terminal + editörler, disk/USB araçları + USB güvenli kullanım (63) ve onarım (64), yazıcı, terminal kolaylıkları. **test8 F notları:** nemo Gezgin gibi (ayrıntı sütunları Name/Modified/Type/Size, ince araç çubuğu, sol panel hızlı erişim + This PC + sürücüler); Ctrl+tekerlek görünüm değiştirir (büyük→küçük→liste→ayrıntı); arama Everything altyapısına (plocate + inotify); sağ tık 'Open as administrator' (pkexec nemo + kırmızı uyarı şeridi); sol ağaçta File System varsayılan kapalı, hızlı erişim üstte | 🔨 kod ✅ (2 Eyl, 8 commit): nemo kur-ayarla — gsettings override + action'lar, yamasız (File System satırı ve görünüm-modu Ctrl+tekerleği yama ister, ONAY BEKLEYEN); Boşluk önizlemesi org.nemo.Preview'u sahiplenen kavis-tools preview (resim/video/ses/pdf/metin/arşiv; ofis bilgi kartı); tilix + mousepad + kate; USB automount + bildirim, gnome-disks/gparted/baobab; sürücüsüz yazıcı/tarayıcı yığını; command-not-found + dnf/pacman çevirisi; gerçek yazma göstergesi + sync modu + meşgul uygulama adları; onarım penceresi (ext/FAT/exFAT/NTFS) + lxpolkit. ISO (v0.3-test10) + VirtualBox el testi bekliyor |
| 0.5 | F | Ayarlar iskeleti + ekran + kişiselleştirme + çok dillilik + güç + ağ + hakkında + sistem sağlığı (62'nin listesini kullanır) + donanım testi | 🔨 1A ✅ (3 Eyl): kavis-settings paketi — W11 yerleşim, kavis.conf tek dosya + canlı yayılım (inotify), 8 bölüm gerçek ayarlarla (canlı tema xsettingsd + Kavis-Light, xrandr + 15 sn geri sayım, dil seçici endonim+yüzde, 4 güç modu, nmcli okuma), bulanık arama, boot-check SETTINGS-OK; 1B ✅ karar: themerc (Seçenek A, CSD reddedildi); 2. ADIM ✅ (VM hataları: edge-warp kapandı, Alt+F4 tek örnek + tasarım dili güç diyaloğu tek bileşen, Tilix VTE uyarısı, tek global klavye düzeni) |
| 0.6 | G | İndirme yöneticisi, Mağaza, Flatpak, Windows karşılıkları, güvenlik taraması, arama çubuğu, CachyOS incelemesi (65) | ⏳ |
| 0.7 | H | Oyun Modu, GPU offload, ağ önceliklendirme, cihaz desteği, sanallaştırma | ⏳ |
| 0.8 | H2 | Sıcaklık izleme (66), kritik sıcaklık uyarısı (67), soğutma katmanı/fan kontrolü (68) — gerçek donanım ister | ⏳ |
| 0.9 (RC) | I | Sürücü yardımcısı, kurulum sihirbazı, ilk açılış uygulama seçimi, Calamares (A/B bölümlü disk düzeni + hibernate swap), yeniden kurulum "dosyalarımı koru" (69), ilk adımlar rehberi, salt-okunur /usr | ⏳ |
| 1.0 | J | Güncelleme sistemi, APT deposu, USB'den güncelleme (A/B), snapshot arayüzü, otomatik yedekleme, sorun giderici, kurtarma ortamı (F8), hata bildirme | ⏳ |
| 1.x / 2.0 | K + ertelenenler | Giriş + kilit ekranı, çoklu kullanıcı, kavis-gameopt (X3D donanım gelince) | ⏳ |

## 1.0'ın halka açılması için MİNİMUM

Görev listesindeki tanım — bunlar olmadan 1.0 yok:

1. Açılan sistem (BIOS/UEFI/Secure Boot, boot splash, masaüstü)
2. Panel (görev çubuğu + başlat menüsü, C/Vala, RAM hedefi içinde)
3. Dosya yöneticisi
4. Ayarlar
5. Mağaza (indirme yöneticisiyle)
6. Kurulum aracı (Calamares, A/B bölüm yapısı kurulmuş)
7. Güncelleme (snapshot'lı, kesintiye dayanıklı)
8. Kurtarma (F8 + F3)

Gerisi 1.x'e kalabilir.

## 2.0'a ertelenebilecekler

- 18: Giriş ekranı + kilit ekranı + çoklu kullanıcı (0. madde gereği
  şimdilik tek kullanıcı "karan", otomatik giriş)
- 21: kavis-gameopt — X3D CCD pinleme (gerçek donanım şart)
- 33D: Uzaktan yardım (SSH'li kurtarma) — temel kurtarma 1.0'da,
  uzaktan yardım sonra
- 34: TR/EN dışındaki dillerin taslak çevirileri
- 54B: telefon kablosuz eşleşme (KDE Connect benzeri) — kablolu MTP
  1.0'da yeter

## Değişmez hedefler

| Ölçü | Hedef | Mutlak sınır |
|---|---|---|
| ISO boyutu | 1.5 GB altı | GitHub release sınırı |
| Kendi bileşenlerimizin RAM'i | 1 GB altı | 1.5 GB |

ISO şişmemesi için uygulamalar ISO'ya gömülmez; ilk açılışta seçilir ve
indirme yöneticisiyle iner (madde 24).
