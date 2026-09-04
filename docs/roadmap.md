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
| 0.5 | F | Ayarlar iskeleti + ekran + kişiselleştirme + çok dillilik + güç + ağ + hakkında + sistem sağlığı (62'nin listesini kullanır) + donanım testi | 🔨 1A ✅ (3 Eyl): kavis-settings paketi — W11 yerleşim, kavis.conf tek dosya + canlı yayılım (inotify), 8 bölüm gerçek ayarlarla (canlı tema xsettingsd + Kavis-Light, xrandr + 15 sn geri sayım, dil seçici endonim+yüzde, 4 güç modu, nmcli okuma), bulanık arama, boot-check SETTINGS-OK; 1B ✅ karar: themerc (Seçenek A, CSD reddedildi); 2. ADIM ✅ (VM hataları: edge-warp kapandı, Alt+F4 tek örnek + tasarım dili güç diyaloğu tek bileşen, Tilix VTE uyarısı, tek global klavye düzeni); 3. ADIM ✅ (menü temizliği+adlar+3 kategori, parlaklık her makinede + tek veri, Battery 4 mod, dinamik masaüstleri); 4. ADIM ✅ (3 Eyl, CI işleri: Start genişlik denetimi I18N-WIDTH-WARN, saat/tarih locale, Firefox + Papirus-Dark ikon zinciri, SOUND-DELAY udev bağı kalktı, ağ göstergesi gerçek durum); 5. ADIM ✅ + debug taraması (3 Eyl: scrot/tekerlek/kök menü kanıtlandı — Alt+tekerlek kaçağı kapatıldı, dikey panel görüntülendi; sızıntı taraması temiz, etiket v0.4-test1); v0.4-test1 VM geri bildirim turu A–J ✅ (3 Eyl, 28 commit: CSD başlıklar, açık tema her yerde, dil değişimi, snap yeniden, 25 kısayol CI'da, sekmeli Görev Yöneticisi + Başlangıç + Günlükler, spinner; etiket v0.4-test2). v0.4-test2 VM turu A-J ✅ (3-4 Eyl): CI DESKTOP-READY, GRUB gizli, spinner, panel C1-C6, hızlı ayarlar D1-D2, snap kök sebebi (libwnck önbelleği + gravity) ve 46 px başlıklar, Ayarlar F1-F5, Görev Yöneticisi G1-G6 (ayrı kavis-taskmanager paketi), uygulamalar H1-H7, emoji seçici I; madde 72 selftest (çekirdek + 6 senaryo + Ayarlar düğmesi + kapsam tablosu) ve CI sağlamlık denetimleri; kod tabanı İngilizce; etiket v0.4-test4 (test3 tur ortasında elle atıldı). Kalan: madde 70 kilit ekranı, selftest kayıt modu, madde 74 (kısayol grupları + ayar hiyerarşisi + arama) |
| 0.6 | G | İndirme yöneticisi, Mağaza, Flatpak, Windows karşılıkları, güvenlik taraması, arama çubuğu, CachyOS incelemesi (65). **Grup G kararları (3 Eyl, docs/kararlar.md):** mağaza apt + Flathub çift kaynak — uygulama sayfasında kaynak başına satır/Yükle, aynı anda tek kaynaktan kurulu, diğeri gri + tooltip; ön sayfa GitHub'daki JSON kataloğundan; arama birleşik + kaynak rozeti; sürücüler mağazada AYRI kategori (ISO'ya sürücü konmaz, Ayarlar > Sürücüler oraya yönlendirir); Flatpak istemcisi ISO'ya (~15 MB), runtime'lar sonradan | ⏳ |
| 0.7 | H | Oyun Modu, GPU offload, ağ önceliklendirme, cihaz desteği, sanallaştırma | ⏳ |
| 0.8 | H2 | Sıcaklık izleme (66), kritik sıcaklık uyarısı (67), soğutma katmanı/fan kontrolü (68) — gerçek donanım ister | ⏳ |
| 0.9 (RC) | I | Sürücü yardımcısı, kurulum sihirbazı, ilk açılış uygulama seçimi, **kendi GTK3/Vala kurucumuz — Calamares YOK (kararlar.md 2):** "Tüm diski kullan" / "Windows'un yanına kur" kendi kodumuz, "Elle bölümle" GParted'a; btrfs @ + @home varsayılan (ext4 yalnız elle bölümlemede, snapshot özellikleri kapalı — kararlar.md 5), EFI 512 MB, swap dosyası (RAM kadar, ≤8 GB), BIOS'ta GPT + bios_grub; A/B düzeni + hibernate swap yine hesaba katılır; CI'da QEMU otomatik kurulum + kurulan sistemden boot-check ve NTFS'li diske Windows-yanı senaryosu yeşil olmadan kurucu bitmiş sayılmaz; yeniden kurulum "dosyalarımı koru" (69), ilk adımlar rehberi, salt-okunur /usr | ⏳ |
| 1.0 | J | Güncelleme sistemi — **apt üstü Kavis güncelleyici (kararlar.md 3):** bildirim + GUI, güncelleme öncesi otomatik btrfs snapshot'ı + kurtarma menüsünden tek tık geri alma, Kavis + Debian güvenlik birlikte, "sadece güvenlik" seçeneği; APT deposu, USB'den güncelleme (A/B), snapshot arayüzü (Timeshift benzeri, günlük/haftalık plan), **yedekleme (kararlar.md 4):** harici diske rsync — zamanlanmış + artımlı, hedef takılınca bildiren bekleme; sorun giderici, kurtarma ortamı (F8), hata bildirme | ⏳ |
| 1.x / 2.0 | K + ertelenenler | Giriş + kilit ekranı, çoklu kullanıcı, kavis-gameopt (X3D donanım gelince), **bulut yedeği (Google Drive vb.) ve fcitx5 CJK giriş yöntemi (kararlar.md 4/7 — 1.0 sonrası)** | ⏳ |

## 1.0'ın halka açılması için MİNİMUM

Görev listesindeki tanım — bunlar olmadan 1.0 yok:

1. Açılan sistem (BIOS/UEFI/Secure Boot, boot splash, masaüstü)
2. Panel (görev çubuğu + başlat menüsü, C/Vala, RAM hedefi içinde)
3. Dosya yöneticisi
4. Ayarlar
5. Mağaza (indirme yöneticisiyle)
6. Kurulum aracı (kendi GTK3/Vala kurucumuz — kararlar.md 2; A/B bölüm yapısı kurulmuş)
7. Güncelleme (snapshot'lı, kesintiye dayanıklı)
8. Kurtarma (F8 + F3)

Gerisi 1.x'e kalabilir.

## 2.0'a ertelenebilecekler

- 18: Giriş ekranı + çoklu kullanıcı (0. madde gereği şimdilik tek
  kullanıcı "karan", otomatik giriş). KİLİT EKRANI artık madde 70 —
  Grup F sonu (3 Eyl kararı), 2.0'a kalmıyor.
- 21: kavis-gameopt — X3D CCD pinleme (gerçek donanım şart)
- 33D: Uzaktan yardım (SSH'li kurtarma) — temel kurtarma 1.0'da,
  uzaktan yardım sonra
- 34: TR/EN dışındaki dillerin taslak çevirileri
- 54B: telefon kablosuz eşleşme (KDE Connect benzeri) — kablolu MTP
  1.0'da yeter

## Değişmez hedefler

| Ölçü | Hedef | Mutlak sınır |
|---|---|---|
| ISO boyutu | 1700 MB altı (üstü WARN) | 1900 MB (kararlar.md 8 — GitHub Release 2 GiB sınırına pay) |
| Kendi bileşenlerimizin RAM'i | 1 GB altı | 1.5 GB |

ISO şişmemesi için uygulamalar ISO'ya gömülmez; ilk açılışta seçilir ve
indirme yöneticisiyle iner (madde 24).
