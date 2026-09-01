# Kavis — güncel görev listesi

Kullanıcının 2026-09-01'de verdiği tam yönerge. `docs/kavis-claude-code-prompt.md`
(Karan OS dönemi) ile çelişen her yerde BU liste geçerlidir. Madde
numaraları her yerde (roadmap, durum.md, commit mesajları) bu listeye
göre anılır.

## Genel ilkeler

**MARKA:** Projenin adı artık KAVİS (eski adı Karan OS). Tüm "karanos" /
"Karan OS" geçen yerler güncellenir: paket adları (kavis-panel,
kavis-theme, kavis-store, kavis-settings), sistem dizinleri
(/var/lib/kavis-*, /etc/kavis, ~/.config/kavis, /var/cache/kavis-*),
systemd servisleri, .desktop dosyaları, ikon adları, hostname (kavis),
ISO adı (kavis-<sürüm>-amd64.iso), /etc/os-release.
İSTİSNALAR: sistem kullanıcısı "karan" KALIR; logo dosya adları
koyu-k-logo.svg / acik-k-logo.svg KALIR; git deposu adına dokunulmaz.
İSİM BİR DAHA SABİTLENMEZ: görünen ad tek kaynakta (/etc/os-release +
tek sabit), her yer oradan okur. Sürüm ve depo adresi de aynı kaynaktan.

**PERFORMANS:** İşi abartılı zorlaştırmadığı sürece HER ZAMAN en hızlı ve
en az RAM yiyen yol. Python ve shell yerine C/C++ tercih:
- Sürekli çalışan bileşenler (panel, servisler): C, C++ veya Vala.
- Kullanıcının açıp kapattığı uygulamalar: C/C++ tercih, iş 3 katına
  çıkıyorsa Python kabul.
- ISO derleme scriptleri ve tek seferlik hook'lar: shell yeterli.
- Hazır ve hızlı araç varsa (aria2c, plocate, flameshot, picom, p7zip,
  nemo, kate, gparted, memtest86+) KUR ve AYARLA, sıfırdan yazma.
Basit olan seçildiyse nedeni tek cümleyle söylenir.

**GÖRÜNÜM:** Her yerde tutarlı "yumuşak ve yuvarlak" dil: yuvarlak
köşeler, hafif blur/akrilik saydamlık, 150-200 ms yumuşak geçişler.
Değerler sabit kodlanmaz, Ayarlar'dan değiştirilebilir (madde 38).

**DİL:** Tüm arayüz metinleri Türkçe ve İngilizce, ikisi de eksiksiz.
Varsayılan TR. Altyapı baştan çok dilli (madde 34).

**LİSANS:** Başka projelerden KOD KOPYALANMAZ — yaklaşım öğrenilir, kod
sıfırdan yazılır. Hazır programları apt ile kurup ayarlamak serbest.

**KOD KALİTESİ:**
- Her fonksiyonun üstünde açıklama (ne yapar, parametreler, dönüş, hata).
  C/C++ için Doxygen, Python için docstring. Açıklamalar İNGİLİZCE;
  kullanıcıya görünen metinler TR+EN.
- Her paketin kökünde README.md; docs/ altında mimari belgesi.
- Karmaşık yerlerde NEDEN yazılır, ne yapıldığı değil.
- Sihirli sayı ve sabit kodlanmış yol yok.
- Hata sessizce yutulmaz: ya loglanır ya kullanıcıya gösterilir.
- HER GRUBUN SONUNDA öz gözden geçirme: mantık hatası, kaynak sızıntısı,
  yarım iş, ele alınmamış hata, çift iş. Bulunanlar düzeltilir ve söylenir.
- Derlenmemiş/test edilmemişse "yaptım" denmez.

## Maddeler

0. **Kullanıcı sistemi ERTELENDİ.** Tek sabit kullanıcı "karan", şifresiz
   otomatik giriş. Giriş ekranı ve setup sihirbazı atlanır, doğrudan
   masaüstü. AMA dizin yapısı kurulur: /users/karan/desktop, downloads,
   documents, pictures, videos, music — tüm bileşenler bu yolları
   kullanır. Kilit ekranı ve kullanıcı ekleme kodu yazılmaz. Geçici
   olduğu docs/ altına not düşülür.
1. **Logo referansları.** assets/logo/ altında koyu-k-logo.svg ve
   acik-k-logo.svg. Boot splash ve GRUB: HER ZAMAN koyu-k-logo.svg.
   Başlat düğmesi, görev çubuğu, hakkında: aktif temaya göre OTOMATİK.
2. **picom compositor.** Sorun: compositor olmadığı için menü/pencere
   kapanınca siyah/gri dikdörtgen kalıyor (VM'de doğrulandı). picom hem
   bunu çözer hem yuvarlak köşe/blur/animasyonun ön şartı.
3. **Paneli C veya Vala'ya taşı.** Ölçüldü: 117 MB RAM (ps -o rss=, VM).
   Hedef 1 GB, kabul edilemez. Aynı görünüm ve davranış korunur. İş
   mantığı ile arayüz ayrı dosyalarda. Bitince RAM tekrar ölçülür.
4. **Görev çubuğu görünümü:** Windows 11 tarzı ama daha yumuşak —
   yuvarlak köşe, hafif blur/akrilik, ortalanmış ikonlar, 150-200 ms.
5. **Görev çubuğu sağ tık menüsü:** Konum (Alt/Üst/Sol/Sağ — dikeyde
   ikonlar dikey), Boyut (İnce/Orta/Kalın), çoklu monitörde hangi ekran,
   Otomatik gizle, Ekran ayarları, Görev yöneticisi.
6. **Pencere yönetimi:** masaüstü simgeleri, snap (Win+ok), kenara
   yapıştırma, hazır düzenler, Alt+Tab, genel kısayol altyapısı.
7. **Görev yöneticisi + küçük araçlar:** görev yöneticisi (işlemler,
   CPU/RAM/disk, sonlandır), pano geçmişi (Win+V: liste, tıkla-yapıştır,
   sabitleme, temizleme, öğe sayısı ayarı), hesap makinesi, emoji
   seçici, Bluetooth ayarları, ses OSD'si.
8. **Güvenlik sertleştirme:** algif_* kara liste,
   kernel.unprivileged_userns_clone=0, kptr_restrict=2, dmesg_restrict=1,
   yama.ptrace_scope=1 — ISO'ya gömülü. earlyoom. (/usr salt-okunur
   madde 17'de.)
9. **Ayarlar iskeleti:** bölümler, gezinme, arama, ayar okuma/kaydetme.
10. **Ekran ayarları:** çözünürlük, DRM'den okunan yenileme hızları,
    %100-200 fractional scaling, yönlendirme, çoklu monitör, gece ışığı
    (otomatik zamanlama: gün batımı/doğumu veya saat).
11. **Arama çubuğu (Everything mantığı):** plocate + inotify/fanotify.
    Tek kutuda dosya (fuzzy), uygulama, ayar, mağaza, hesaplama, web.
    ext:/folder:/size:>/path: filtreleri, kategorili sonuçlar, klavye
    gezinme, Enter aç, Ctrl+Enter konum aç.
12. **Kavis Mağaza:** kategoriler, arama, uygulama sayfası, kur/kaldır/
    güncelle, kurulu uygulamalar.
13. **Oyun Modu (SteamOS tarzı):** gamescope + GameMode + MangoHud.
    Başlat menüsü ve masaüstünde düğme — panel durur, gamescope Big
    Picture açar, çıkınca masaüstü. MangoHud ayarlardan. Proton:
    vm.max_map_count yüksek, split-lock kapalı, kalıcı shader cache.
    Lutris + Heroic mağazaya.
14. **GPU offload:** hibritte sağ tık "Ekran kartıyla çalıştır"
    (DRI_PRIME=1 / __NV_PRIME_RENDER_OFFLOAD). Tek GPU'da görünmez.
    Ayarlarda varsayılan GPU.
15. **Kurulum sihirbazı (ilk açılış):** dil, klavye, saat dilimi, ağ,
    tema. DÜRÜST UYUMLULUK EKRANI: "Şunlar çalışmıyor: Valorant,
    Fortnite, Rocket League, Adobe, MS Office masaüstü." Kurulumdan ÖNCE.
16. **Calamares + canlı mod.** Disk düzeninde 27C'nin A/B yapısı ŞİMDİDEN
    hesaba katılır; hibernate swap alanı da (51).
17. **/usr salt-okunur btrfs subvolume.** EN SONA — apt'ı bozabilir.
18. **Giriş ekranı + kilit ekranı** (0'da ertelenen), kullanıcı ekleme.
19. **Kendi APT depomuz:** reprepro, GitHub Pages, Actions ile otomatik.
    GPG zorunlu — özel anahtar secret'ta, açık anahtar ISO'da
    /etc/apt/keyrings altında.
20. **Kurtarma ortamı** (33 ile birlikte).
21. **kavis-gameopt:** cache'li CCD'yi sysfs'ten bul, amd_pstate prefcore
    ile en iyi çekirdekler. Oyunlar cache CCD'ye, derleme tüm
    çekirdeklere. Uygulama başına, GameMode kancasıyla otomatik. sysfs
    yolları esnek, bulunamazsa sessizce devre dışı. SADECE gerçek AMD
    X3D donanım gelince.
22. **CI iyileştirmesi (build-iso.yml):** apt önbelleği actions/cache
    ile; her push'ta derleme YOK (workflow_dispatch + tag yeter);
    "Releases'e yükle" adımının neden çalışmadığını incele ve düzelt.
23. **İndirme yöneticisi (Store içinde), aria2c tabanlı:**
    --save-session/--input-file ile daemon (kesintiye dayanıklı). Durum
    sqlite: /var/lib/kavis-store/downloads.db. Play Store tarzı halka
    gösterge (çevre=ilerleme, ortada durdur/devam, yanda yüzde). Store'da
    "İndirme Yöneticisi" bölümü: her durumda liste + duraklat/devam/
    iptal/tekrar dene. Açılışta kesik indirme bildirimi. .deb'ler
    /var/cache/kavis-store'a iner, indirme ve kurulum AYRI adımlar.
    sha256 + boyut doğrulama. Ayarlarda hız sınırı ve eşzamanlılık.
24. **İlk açılış uygulama seçimi.** ISO'ya uygulama GÖMÜLMEZ. Setler:
    Minimal / Günlük (tarayıcı, ofis, medya) / Oyun (Steam, Lutris,
    Heroic) / Geliştirici (VS Code, git, derleyiciler) / İçerik Üretimi
    (OBS, Blender, DaVinci Resolve, GIMP, Kdenlive). Set veya tek tek,
    "Sonra hallederim" var. Seçilenler 23'e devredilir, arka planda
    iner. NOT: DaVinci'nin resmi .deb'i yok — zorsa mağazada yönlendirme
    sayfası.
25. **Ağ önceliklendirme.** Hız artırma VAAT EDİLMEZ; hedef gecikme:
    cake qdisc (yoksa fq_codel). Oyun Modu'nda Store indirmeleri otomatik
    duraklar, apt güncellemesi ertelenir; çıkınca devam. Ayarlarda
    "Oyun oynarken indirmeleri duraklat" (varsayılan açık). Etkiyi
    göster: Oyun Modu açık/kapalı ping farkını ölç.
26. **Güncelleme sistemi.** Temel apt, kendi güncelleyici yazılmaz.
    Ayarlar'da "Sistem Güncellemesi": bekleyenler, boyut, notlar;
    kaynaklar ayrı (Debian güvenlik/normal, Kavis, Flatpak). "Şimdi
    kontrol et", "Tümünü güncelle", geçmiş, "önceki snapshot'a dön".
    İndirme 23'ü kullanır. "kavis-release" meta paketi. Günde bir sessiz
    kontrol, rozet; sormadan HİÇBİR ŞEY kurulmaz. GÜNCELLEMEDEN ÖNCE
    OTOMATİK BTRFS SNAPSHOT (GRUB'da görünür, son 5). Çekirdek/systemd
    sonrası "yeniden başlat" bildirimi. Kesilirse açılışta
    dpkg --configure -a.
27. **USB'den güncelleme (offline).** A) Yeni ISO'lu flash'tan boot →
    diskteki kurulum tespit: "1.0 bulundu, yeni 1.2 — Güncelle / Canlı /
    Diske boot (varsayılan, 15 sn)". B) /users/karan'a dokunulmaz.
    C) A/B bölüm: güncelleme pasif subvolume'e yazılır, sha256 geçerse
    GRUB TEK ATOMİK ADIMLA çevrilir; 3 başarısız açılışta otomatik geri;
    ekranda yüzde + "kapatmayın". D) İnternet zorunlu değil.
28. **Mağazada "Windows karşılığı":** Windows adları arama terimi
    ("Photoshop" → GIMP/Krita + not). Eşleştirme ayrı json/yaml'da.
    Başlangıç: Photoshop→GIMP/Krita, Illustrator→Inkscape,
    Premiere→Kdenlive/DaVinci, MS Office→LibreOffice/OnlyOffice,
    Notepad++→Kate, WinRAR→Ark, Paint→Drawing/Pinta, Media Player→VLC/mpv,
    Explorer→dosya yöneticisi, Visual Studio→VS Code, ".bat"→".sh"
    (açıklamalı). Karşılığı olmayanlara dürüst uyarı (Valorant, Fortnite,
    Rocket League, Adobe: "Linux'ta çalışmıyor").
29. **Ekran görüntüsü ve kaydı.** A) Ctrl+C+PrtScreen: hızlı yakalama,
    sormaz; ne yakalanacağı Ayarlar'dan (aktif pencere / monitör /
    hepsi); Ctrl+C çakışması çözülemiyorsa söyle. B) PrtScreen: ARAÇ
    MENÜSÜ — ekran donar ve kararır; [📷 Görüntü] | [🔴 Video] sekmeleri;
    yuvarlak/dikdörtgen/pencere/tam ekran seçici; pencere seçiminde
    üstünden geçen olsa da SADECE o pencere; "Atlamak için boşluk".
    Görüntü: kaydet/panoya/düzenle (ok, kutu, yazı, bulanık)/iptal.
    Video: donmuş kare kalkar, oynat/duraklat/bitir + sayaç.
    C) Kayıt yeri seçilebilir, varsayılan /users/karan/pictures/screenshots,
    ad tarih-saat. D) Bildirim: önizleme + klasörü aç + panoya.
    E) İki kısayol da değiştirilebilir. F) flameshot temel; yetmezse yaz.
30. **Açılış ekranı.** Ortada koyu-k-logo.svg + "KAVİS". Duvar kâğıdı yok,
    sade zemin. Altta "F3 — Gelişmiş menü" ve "Atlamak için boşluk".
    Müzik bitene kadar ekrandan ÇIKILMAZ (tek istisna: boşluk). Ayarlar:
    müzik aç/kapa, "müziği bekleme" aç/kapa. Geçişler fade.
    **F3 gelişmiş menü** (sağlamken "bu sefer nasıl açılsın"): Normal /
    Güvenli mod / Önceki sürüm (A/B) / Snapshot listesi / Eski çekirdek /
    RAM testi (memtest86+) / Kurtarmaya geç (F8) / Canlı mod / Detaylı
    kayıtlar / Çekirdek parametresi / UEFI ayarları. GRUB'un çirkin metin
    menüsü DEĞİL: Kavis temalı, açıklamalı, Türkçe.
31. **Snapshot geri alma (Time Machine mantığı):** tarih listesi, "o güne
    dön"; tek dosya kurtarma ("geçmişe bak"); elle nokta alma; ayarlarda
    sıklık/adet/boyut.
32. **Sorun giderici (iyi yapılacak):** internet yok (arayüz/DHCP/DNS/
    kablo/ping), ses yok, ekran/sürücü, UYKUDAN DÖNMEME, Bluetooth,
    yazıcı, uygulama çöküyor (son çökme + sade açıklama), pil, disk
    doluyor, yavaşlık, çökme sonrası "geçen sefer beklenmedik kapandı,
    bakalım mı?". Akış: kontrol → SADE TÜRKÇE anlat → öner → onayla
    düzelt. Terminal komutu yazdırılmaz.
33. **Kurtarma ortamı (F8) — WinRE karşılığı.** F3 ≠ F8; birbirine
    geçilebilir; açılmazsa F8 otomatik. A) Tıklanabilir onarımlar:
    snapshot'a dön, GRUB onar, fs kontrol (btrfs scrub/check), şifre
    sıfırla, ağ onar, sistem dosyalarını doğrula, disk yedeği, kurulumu
    onar (veri korunur), kayıtları göster. B) GRAFİK kurtarma: tam
    masaüstü + dosya yöneticisi + tarayıcı + terminal (USB'ye dosya
    çekilebilir). C) Kurtarma konsolu: tam kabuk, disk bağlı. D) Uzaktan
    yardım: SSH, OPSİYONEL ve ELLE, tek kullanımlık şifre.
34. **Çok dilli altyapı + Türkçe.** gettext; kodda sabit metin YOK. TR ve
    EN eksiksiz ve elle. HATA MESAJLARI da çevrilir. Diğer diller için
    altyapı hazır; taslak çeviriler "topluluk düzeltmesi bekliyor"
    işaretli. Weblate'e bağlanabilir. Ayarlarda tek tık dil; gerekiyorsa
    "şimdi yeniden başlat". Klavye düzeni dille birlikte ama ayrıca da
    seçilebilir.
35. **Sürücü yardımcısı:** donanım tara, NVIDIA/AMD/Intel sürücü tespit,
    tek tık kur + yeniden başlat öner. Açık kaynak/tescilli seçimi sade
    açıklamalı. Wi-Fi/BT firmware dahil. NVIDIA + Wayland pürüzlü —
    tespit edilirse uyar, X11 seçeneği sun.
36. **Hızlı önizleme (Quick Look):** boşluk tuşu → önizleme; tekrar
    boşluk/Esc kapat; sağ tıkta "Önizle". Resim, video, ses, pdf,
    metin/kod, ofis, arşiv listesi. Hızlı — tam uygulama açılmaz.
37. **Takvim + bildirim paneli:** saate tıklayınca panel — aylık takvim,
    bildirim listesi (uygulama bazlı grup, temizleme), hızlı ayarlar
    (wifi, bt, ses, parlaklık, gece ışığı, oyun modu, odaklanma, güç
    profili). Bildirim altyapısı sistem geneli. Yumuşak animasyon,
    yuvarlak + blur.
38. **Ayarlar → Kişiselleştirme:** köşe yuvarlaklığı kaydırıcısı (her yer
    bu değeri kullanır), animasyon hızı (kapalı/hızlı/normal/yavaş),
    saydamlık ve blur miktarı, açık/koyu/"sistemle uyumlu", duvar kâğıdı,
    vurgu rengi. TEK yapılandırma dosyası, sabit kodlama yok.
39. **DOSYA YÖNETİCİSİ — Nemo'yu kur ve uyarla, sıfırdan yazma.**
    Görünüm/gezinme: Ctrl+tekerlek kademesiz simge boyutu (ÖNEMLİ),
    görünüm modları, klasör başına ayar hatırlama, gizli dosyalar
    (Ctrl+H), sol ağaç, tıklanabilir yol çubuğu (boşluğa tıkla → metin),
    sekmeler + ikili panel, fare geri/ileri, küçük önizlemeler.
    Seçme/işlem: Ctrl+A, Shift/Ctrl+tık, sürükle (Ctrl=kopya),
    kes/kopyala/yapıştır, F2 + TOPLU yeniden adlandırma, CTRL+Z GERİ AL
    (sil/taşı/ad değiştir), kopyalama ilerleme + duraklat + çakışma
    ekranı (boyut/tarih karşılaştırmalı), klasör boyutu hesapla.
    Sıralama: ad/boyut/tür/tarih, klasörler önce, yazınca ANINDA filtre,
    özelleştirilebilir sütunlar.
    Sağ tık: terminal aç / editörde aç / yönetici olarak aç, yolu
    kopyala, sıkıştır/çıkart, sağlama toplamı (48), tara (48), masaüstüne
    kısayol, "şununla aç" + varsayılan değiştir, ekran kartıyla çalıştır
    (14), önizle (36).
    Arşiv TAM: zip, 7z, rar, tar[.gz/.xz/.bz2/.zst], gz, xz, bz2, zst,
    iso, cab — açma + oluşturma; p7zip-full, unrar, zstd kurulu. EN HIZLI
    yöntem: çok çekirdekli (zstd, pigz, 7z -mmt). "Arşive ekle"de format
    + seviye.
    Diğer: çöp kutusu (geri yükleme + masaüstü simgesi), SMB/SFTP/NFS,
    yer imleri, son kullanılanlar, yeni dosya şablonları, izinleri BASİT
    değiştirme ("sadece ben"/"herkes okur"/"herkes yazar"), iki dosya
    karşılaştırma, arama 11'in plocate altyapısıyla.
40. **Terminal ve editörler.** Terminal: Kavis teması, sekmeler, bölünmüş
    pencere, yazı tipi ayarı, Ctrl+Shift+C/V. Metin editörü: hızlı, sade.
    Kod/JSON editörü: renklendirme (json, yaml, xml, html, css, js, py,
    c, cpp, sh, md, ini, conf), satır no, girinti, parantez eşleme, JSON
    biçimlendir + hata, katlama, ara-değiştir. Kate'i kur ve ayarla.
41. **Flatpak:** mağaza apt + Flatpak; kaynak görünür, ikisi varsa seçim.
    Flathub ekli. Güncellemeler 26'nın ekranında.
42. **Disk ve USB:** otomatik bağlama + bildirim, NTFS okuma/yazma
    (ntfs-3g), güvenli çıkar. Biçimlendirme: NTFS/FAT32/exFAT/ext4/btrfs,
    tek cümle açıklamalı. ISO yazma aracı (Rufus karşılığı). SMART +
    doluluk. DİSK ALANI HARİTASI (WinDirStat). GParted kurulu.
43. **Yazıcı sihirbazı:** ağ + USB otomatik bul, sürücü kur, test sayfası.
    CUPS arka planda, web arayüzü görünmez. Tarayıcı desteği.
44. **Terminal kolaylıkları:** command-not-found ("neofetch yok, X
    paketinden — kurayım mı?"); "dnf install X"/"pacman -S X" →
    "Kavis'te 'apt install X' — çalıştırayım mı?" (yum, zypper, snap
    de); Windows'tan gelene dir/cls/ipconfig ipuçları.
45. **Hakkında ekranı:** sürüm, çekirdek, masaüstü, CPU, RAM, GPU, disk,
    hostname. "Bilgileri kopyala". Güzel görünsün.
46. **TEST ALTYAPISI.** A) CI: QEMU bios/uefi/secureboot (koru), donanım
    profilleri (2/4 GB RAM, tek/çok çekirdek, farklı sanal GPU'lar),
    masaüstü + panel gerçekten açıldı mı (ekran görüntüsü boş değil),
    BOŞTA RAM ölçümü (1 GB üstü UYARI), ISO > 1536 MB HATA, paketler
    kuruldu mu, servisler başladı mı, job summary'ye tablo. B) HATA
    BİLDİRME ARACI: Ayarlar + sorun gidericide "Sorun bildir"; sistem
    bilgisi + log toplanır, NE GÖNDERİLECEĞİ GÖSTERİLİR, onayla GitHub
    issue veya panoya; kişisel bilgi otomatik temizlenir. C) Test
    edilmiş donanım listesi docs/ altında.
47. **REFERANS İNCELEME (Grup A2).** /tmp/referans altına --depth 1 klon:
    mintdrivers (35), mintupdate (26), mintinstall (12/41), nemo (39),
    calamares (16), bazzite (13 + strateji), gamescope (13), flameshot
    (29), picom (2). Her biri için: mimari, dil, boyut, kullandığı sistem
    arayüzleri (D-Bus, polkit, sysfs, udev), bizden farkı, tuzaklar
    (tekrar eden issue şikâyetleri), hangi maddemizde işe yarar.
    Özetler docs/referans/*.md. Sonra /tmp/referans silinir.
    KESİN KURAL: KOD KOPYALANMAZ.
48. **Güvenlik taraması + dosya doğrulama.** A) ClamAV: sağ tık tara;
    Ayarlar > Güvenlik; Windows bölümü taraması; indirilenler otomatik
    (kapatılabilir). SÜREKLİ ARKA PLAN TARAMASI YOK. Veritabanı
    güncellemesi 26'ya bağlı. B) Her .deb'in sha256 + GPG doğrulaması;
    sağ tık sağlama hesapla/doğrula. C) Dürüst mesaj: Linux'ta virüs
    riski düşük; araç çoğunlukla Windows bölümü ve indirilenler için.
49. **SİSTEM SAĞLIĞI:** güvenilirlik zaman çizelgesi (apt geçmişi +
    journald çökmeleri TEK çizelgede, snapshot'a geçiş), olay
    görüntüleyici (sade journald: "şu çöktü", filtre, arama), açılış
    süresi analizi (systemd-analyze blame grafikli, kapatılabilir
    gereksizler), kaynak geçmişi (7 gün CPU/RAM/disk/ağ), otomatik
    başlayanlar yönetimi (kapatma + kaç saniye eklediği).
50. **DONANIM TESTİ VE BENCHMARK:** SSD sağlığı (SMART sade dille), disk
    hız (fio, beklenenle karşılaştır), RAM testi (memtest86+ GRUB'dan;
    ayarlardaki düğme yeniden başlatıp oraya gider), CPU stres
    (stress-ng + sıcaklık/frekans + throttle uyarısı), GPU (glmark2),
    ağ hızı, pil sağlığı (tasarım vs şimdiki kapasite, döngü, aşınma).
    Kendi motorunu yazma; hazır araçları çağır, güzel göster. SONUÇLAR
    KAYDEDİLİR (zaman içi karşılaştırma).
51. **GÜÇ VE PİL:** A) uyku + hibernate düzgün (btrfs swap + resume —
    Calamares'te ayarlanır, 16). B) Kapak: prizde/pilde/harici monitörde
    AYRI seçenekler. C) Süre bazlı: karart/kapat/uyku/hibernate/kilitle,
    prizde-pilde ayrı, "asla" var. D) Güç/uyku düğmeleri ayrı ayarlanır.
    E) Kritik pil eşiği + eylemi. F) Profiller: performans/dengeli/
    tasarruf; Oyun Modu → performans. G) %80 şarj sınırı (destekleyende).
    H) Uygulama bazlı tüketim. I) Kalan süre, parlaklık/klavye ışığı
    tuşları.
52. **AĞ ARAÇLARI:** WireGuard + OpenVPN (dosya içe aktar, tek tık,
    panel göstergesi), hotspot (QR ile), ağdaki cihazlar, Wi-Fi listesi/
    kayıtlı ağlar/gizli ağ, hız testi (50 ile ortak).
53. **SANALLAŞTIRMA:** QEMU/KVM + virt-manager tek tık (Windows VM
    Adobe/Office'i kısmen çözer; Valorant'ı çözmez — söylenir). Docker +
    Podman mağazadan. VT-x/AMD-V kapalıysa tespit + BIOS tarifi.
54. **CİHAZ DESTEĞİ:** A) Oyun kolları: DualSense, DualShock 4, Xbox,
    Switch Pro, XInput; USB + BT; otomatik tanıma, tuş testi,
    kalibrasyon, titreşim, pil; DualSense ışık rengi; adaptif tetik/
    haptik çalışmaz — söylenir. B) Android: MTP, KDE Connect tarzı
    öneri; iPhone: libimobiledevice foto/dosya; iTunes yedeği/müzik
    senkronu ÇALIŞMAZ — net söylenir. C) USB aygıtlar, kart okuyucu,
    harici disk otomatik.
55. **SANAL MASAÜSTLERİ + ODAKLANMA:** geçiş animasyonu + GENEL BAKIŞ
    (Win+Tab: hepsi tek ekranda, tıkla git, sürükle taşı), Ctrl+Alt+ok
    kaydırmalı, ODAKLANMA MODU (bildirim sustur, uygulama engelle, süre,
    bitince bildir), Rahatsız Etmeyin (sonra toplu göster).
56. **OTOMATİK YEDEKLEME (snapshot'tan AYRI):** harici disk/ağ; klasör
    seçimi (varsayılan: belgeler, resimler, videolar, masaüstü);
    günlük/haftalık/disk takılınca; artımlı + saklama süresi; geri
    yükleme (tarih seç, tek dosya/hepsi); disk yoksa sessiz bekle.
57. **İLK ADIMLAR REHBERİ:** 5 dk interaktif tur (dosya yöneticisi,
    mağaza, ayarlar, ekran görüntüsü, sorun çıkarsa); adım adım, "atla",
    sonradan tekrar açılabilir; Windows'tan gelene kısayol karşılıkları.
58. **YOL HARİTASI:** docs/roadmap.md — grup→sürüm eşlemesi, 1.0 minimumu,
    2.0 ertelemeleri. Her grup bitiminde güncellenir.

## Yapılış sırası (gruplar)

Numara sırasıyla DEĞİL, gruplar hâlinde. Her grubun sonunda DUR: özet,
ayrı commit, onay bekle. "Devam" denmeden sonraki gruba geçilmez.

- **GRUP A** — engel kaldıran ucuz işler: 22, marka değişikliği, 1, 58
- **GRUP A2** — referans inceleme: 47
- **GRUP B** — mevcut aşamaları kapat: tema/boot CI doğrulaması, 2, 30,
  0, 8, 46A
- **GRUP C** — panel altyapısı: 3
- **GRUP D** — masaüstü deneyimi: 4, 5, 6, 55, 37, 7, 29
- **GRUP E** — temel uygulamalar: 39, 36, 40, 42, 43, 44
- **GRUP F** — ayarlar ve sistem: 9, 10, 38, 34, 51, 52, 45, 49, 50
- **GRUP G** — mağaza ve arama: 23, 12, 41, 28, 48, 11
- **GRUP H** — oyun ve cihazlar: 13, 14, 25, 54, 53 (VM'de tam test
  edilemez)
- **GRUP I** — kurulum akışı (27C A/B + 51A swap baştan hesaba katılır):
  35, 15, 24, 16, 57, 17
- **GRUP J** — güncelleme/yedek/kurtarma: 26, 19, 27, 31, 56, 32,
  33 + 20, 46B
- **GRUP K** — en son: 18, 21

## Değişmez kurallar

- Kendi bileşenlerimizin toplam RAM'i 1 GB altı (en fazla 1.5 GB).
- ISO şişmez: uygulamalar ilk açılışta iner, ISO'ya servis + config.
- Tüm arayüz metinleri TR + EN eksiksiz, varsayılan TR, kodda sabit
  metin yok (çeviri anahtarı).
- Varsayılan tema koyu. Dosya sistemi btrfs.
- Kod kopyalanmaz; yaklaşım öğrenilir, sıfırdan yazılır.
- Aynı işlemin iki kez çalışması gibi hatalardan kaçınılır.
- Hızlı yol varsa o seçilir, yavaş dil kullanılmaz.
- Her grubun sonunda öz gözden geçirme yapılır ve bulunanlar söylenir.
