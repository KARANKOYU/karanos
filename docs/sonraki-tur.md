# Sonraki tur — "devam" denince ilk iş bu

3 Eylül 2026 sonunda yazıldı. Kullanıcı gitti; oturum burada durdu.
Sıra yukarıdan aşağı. Her madde ayrı commit, commit mesajları
İngilizce (CLAUDE.md dil kuralı), push kullanıcı isteyince.

## 0a. 4 Eylül — konteyner kaybı ve wip'in kapanışı

- Codespace'in `/etc/passwd`'si bozulup konteyner yeniden kuruldu.
  Artık **her chroot hook'u** `/usr/share/kavis/build-marker` yoksa
  çalışmayı reddediyor (marker yalnız includes.chroot ile chroot'a
  girer); `tools/check-config.sh` korumayı denetliyor, CLAUDE.md'de
  host'ta yasak komut listesi var, `.devcontainer/` araç zincirini
  kaydediyor. Commit `cbc050c`.
- **wip commit'i (4027be2) kapandı:** yeni konteynerde derleme yeşil,
  eksik 9 çeviri eklendi (`5882212`), denetimler geçiyor —
  check-config, check-packages, check-i18n (375 msgid), KEYBIND 26/26,
  SNAP 4/4. Xvfb doğrulaması: Görev Yöneticisi (üstte CPU/RAM/süreç
  toplamı, USS Memory sütunu + "Advanced columns", CPU başlığında ▼,
  "Right-click a process for actions" — G2/G3/G4 ve RAM maddesi 1) ve
  emoji seçici (8 sütun, büyük glifler, sekmeler + kategori başlığı —
  madde I) çalışıyor.
- Kalan doğrulama: G5 (Performans çekirdek ızgarası), G6 (Başlangıç
  listesi kuralları), H4'ün canlı yarısı (`Apply.firefox_theme`), hepsi
  **VM turunda**.

## 0b. 4 Eylül ilerlemesi

Biten ve commit edilen maddeler: **F1, F2, F3, F4, F5, G1, G2, H1, H2,
H3, H4 (sistem yarısı), H5, H6, H7** + tema seçim rengi düzeltmesi +
boot-check SCHEMA-OK denetimi. Çalışan ajanlar: **G3-G6 + RAM maddesi 1**
(kavis-taskmanager), **I** (emoji seçici, kavis-panel). Elde yazılan ama
henüz derlenmemiş: H4'ün canlı yarısı (tema değişince Firefox
profillerine user.js yazılması, `Apply.firefox_theme`).

Kalan: I sonrası **VM turu** (F3 ölçek adımları, G/H maddeleri, 5
senaryo), RAM temizliği 2-6, sonra **v0.4-test3** etiketi.

## 0. Durum (3 Eyl sonu)

- **F1, F2, F4 bitti ve commit edildi** (`584281e`, `8015bf7`,
  `6400573` + çeviriler `70ff2c5`). Çalışma ağacı temiz, tüm denetimler
  geçiyor (derleme, shellcheck, check-config, check-packages,
  check-i18n 352 msgid, KEYBIND 25/25, SNAP 4/4).
- **Henüz VM'de görülmediler:** üçü de Xvfb'de doğrulandı; F1'in
  bellek satırları (dmidecode kök ister) ve F2'nin çoklu çıkış/Hz
  listesi gerçek makinede bir daha bakılmalı.
- F5, H2, H3 de bitti. Push yapılmadı: origin/main 20 commit geride.

## 1. Selftest eksikleri (madde 72)

- Ayarlar > Sistem'e "Sistemi test et" düğmesi (uyarı → koşu → "Raporu
  aç" / "Hata bildir").
- Kayıt modu: kullanıcının tıklama/tuşları YAML senaryosuna dönüşür.
- `docs/test-kapsami.md` üretimi (madde → senaryo tablosu); senaryosuz
  madde CI'da kırmızı.
- Rapor artifact'ı: koşu klasörünün VM dışına çıkması (virtfs ya da
  seri günlüğe base64 — karar verilecek).
- rc.xml'deki her kısayoldan otomatik senaryo üretimi.

## 2. A–J turunun kalanı

- **F3** ölçek (ilk sırada: F2'nin ekran görüntüsünde ölçek kutusu
  İngilizce arayüzde "%100" yazıyor — locale biçimi hatası doğrulandı): %125'te yazı devasa, hizalar kayıyor. GDK_SCALE tam
  sayı + GDK_DPI_SCALE/xrandr --scale; 100/125/150/175/200 VM'de tek
  tek denenecek. Yüzde biçimi locale'e uyacak (EN "125%", TR "%125").
- **G1–G6** Görev Yöneticisi: ayrı `kavis-taskmanager` ikilisi + kendi
  ikonu (turkuaz, düz, sütunlu); "End task" düğmesi yerine sağ tık
  menüsü + Delete/Shift+Delete; CPU yüzdesi tüm çekirdeklere göre
  normalize (toplam = süreçler toplamı); sıralanan sütunda ▲/▼;
  Performans > CPU çekirdek ızgarası, Memory DDR/MHz/CL/yuva;
  Başlangıç listesinde sistem zorunluları görünmeyecek, hepsi
  varsayılan kapalı.
- **H1** Nemo başlığı tam yol, yol çubuğunda "Home" + tooltip tam yol.
- **H4** Firefox koyu temada açılacak (policies.json/user.js), tema
  değişince Firefox da değişecek.
- **H5** "Tilix" adı hiçbir yerde görünmeyecek: WM_CLASS eşlemesi +
  .desktop + `com.gexperts.Tilix window-title/app-title`.
- **H6** Kate Kavis profili (araç çubuğu gizli, Kavis renk şeması,
  yazı tipi 11, kenar çubuğu kapalı, tek sekme, CSD başlık).
- **H7** Masaüstü varsayılan ikonları: Files, Firefox, Settings, Task
  Manager, Terminal (Trash yok).
- **I** Emoji seçici: glif en az 24 px, 8 sütun, kategoriler (Emoji
  alt grupları, Kaomoji, Semboller, Son kullanılanlar, Pano geçmişi),
  arama tüm sekmelerde, S/M/L boyut ayarı sağ üstte.
- **J** Her düzeltme VM'de doğrulanacak (Xvfb yetmez), docs/durum.md
  güncel, etiket **v0.4-test3** (etiket commit'inde `[skip ci]` YOK).
- H2/H3 (şablonlar) ve F5 (Windows sürüm adı yasağı + CI koruması)
  3 Eyl'de bitti.

## 3. RAM temizliği (A–J eki)

1. Görev Yöneticisi Memory sütunu **USS** (smaps_rollup Private_*)
   göstersin; RSS "Gelişmiş sütunlar"da. Toplam satırı `free`'nin
   "used" değeri.
2. lxpolkit, nemo-desktop, kavis-tools, kavis-osd, kavis-snap USS
   ölçülüp tablo raporlanacak. lxpolkit USS > 15 MB ise kavis-polkit
   (Vala/GTK, ~200 satır) yazılıp değiştirilecek. nemo-desktop USS >
   30 MB ise sebebi bulunacak.
   **3 Eyl ölçümü (QEMU, boşta):** kavis-panel 36 MB (RSS 64),
   nemo-desktop 43 MB (eşik aşıldı → sebep aranacak), lxpolkit 11 MB
   (eşik altında → kalıyor), kavis-snap 4, kavis-osd 4, openbox 4,
   picom 2, xcape 0. Boşta MEM-USED ≈ 570–600 MB (hedef < 380 MB).
3. kavis-tools 67 MB RSS: emoji seçici + hesap makinesi + ekran
   görüntüsü tek süreçte mi, kullanılmayan pencereler bellekte mi —
   lazy oluştur, USS hedefi < 10 MB.
4. Print applet olduğu gibi kalır (karar).
5. Hedef: masaüstü boşta `free` "used" < 380 MB (CI MEM-USED), tablo
   docs/durum.md'ye.
6. **Açık soru:** elle `pkill` + yeniden başlatma sonrası VM'de İKİ
   `kavis-panel` süreci görüldü (biri PPID 1). Ürün hatası mı, elle
   başlatmanın izi mi — bulunacak.

## 4. Yeni kararlar (3 Eyl akşamı, kullanıcı notu — henüz YAPILMADI)

- **Kısayollar gruplanacak.** (Not: Ayarlar > Klavye sayfasındaki
  kısayol listesi F4 ekran görüntüsünde zaten "System" / "Window"
  başlıklarıyla gruplu görünüyor — madde 74 bunun üstüne yeniden
  atama ve Fn kombinasyonlarını ekleyecek.) rc.xml ve Ayarlar'daki kısayol listesi
  düz liste olmayacak: "Sistem", "Pencere", "Masaüstü", "Uygulama",
  "Medya/Fn" gibi gruplar. Fn+F2 türü kombinasyonlar **varsayılan**
  olarak gelecek ama kullanıcı ne yaptığını değiştirebilecek
  (yeniden atama + varsayılana dön).
- **Ayarlar bölümleri hiyerarşik olacak.** Örnek: System > System
  info, System backup, System restore. Bu düzen yalnız System'de
  değil, TÜM bölümlerde geçerli (alt bölümler + katlanabilir gruplar).
  F1'in Hakkında hiyerarşisi bu düzenin ilk parçası.
- **Ayar araması gerçekten iyi olacak.** "light" yazınca System/dark/
  light gibi ilgili her ayar çıkacak: başlık + açıklama + alt bölüm
  adı + eşanlamlılar üzerinden arama, bulanık eşleşme, sonuçta hangi
  bölümde olduğu yazacak. (Bugünkü bulanık arama yalnız başlıklara
  bakıyor.)

## 5. Bugün biten işler (bağlam)

- Kod tabanı tamamen İngilizce (`7a382b9`, 229 dosya) + CLAUDE.md dil
  kuralı; Türkçe yalnız po/tr.po ve docs/.
- kavis-selftest çekirdeği + 5 senaryo + boot-check entegrasyonu.
- Madde 72 CI sağlamlık denetimleri (dpkg -V, servis/journal/coredump,
  DEPS-RANGE, haftalık cron + issue).
- Debug turu: snap gravity ve unsnap boyutu, Win toggle yarışı, picom
  SIGUSR1 yanlış dosya, flash zamanlayıcısı, ✕ ipucu, valac uyarıları
  26 → 2, preview oturum veri yolu olmadan pencere açmıyordu.
- Tuval (13b-EK) tasarımı `docs/tuval-tasarimi.md` + madde 73.
