# Kavis — Grup G kararları (3 Eylül 2026)

Kullanıcının (Enes) Grup F sürerken verdiği kararların kaydı. Grup F
bitene kadar G'ye BAŞLANMAZ; bu dosya kapsam tartışmasını kurucu/mağaza
kodu yazılmaya başlamadan ÖNCE kapatmak için var. Roadmap 0.6 satırı ve
görev listesi bu kararlara göre güncellendi. Çelişki çıkarsa bu dosya
görev listesindeki eski madde metinlerini EZER.

## 1. Mağaza: apt + Flatpak (madde 11 arama, 12/41 mağaza, 56)

- İki kaynak: **apt deposu** ve **Flathub**. Uygulama sayfasında ayrı
  satırlar: "apt deposu — sürüm X" / "Flathub — sürüm Y", her satırın
  kendi Yükle düğmesi; kaynak tekse tek düğme.
- **Aynı anda iki kaynaktan yüklü OLAMAZ:** biri kuruluyken diğerinin
  düğmesi gri + tooltip "Önce apt/Flathub sürümünü kaldırın". Kaldırma
  bitene (ya da iptal edilene) kadar açılmaz.
- Ön sayfa GitHub'da barındırılan **JSON kataloğu** okur (öne çıkanlar,
  kategoriler, ikonlar) — mağaza sunucusu yazılmaz, statik dosya yeter.
- Arama apt + Flathub **birleşik**; sonuç satırında kaynak rozeti.
- **Sürücüler mağazada ayrı kategori** (nvidia-driver, broadcom-sta,
  yazıcı/tarayıcı sürücüleri...). ISO'ya sürücü KONMAZ; Ayarlar >
  Sürücüler bu kategoriye yönlendiren bir kapıdan ibaret.
- Flatpak istemcisi ISO'ya girer (~15 MB); runtime'lar ilk kurulumda
  iner. Gerekçe: ISO şişmez, ama kullanıcı mağazayı açtığında Flathub
  hazır.

## 2. Kurucu: kendi GTK3/Vala kurucumuz — Calamares YOK (madde 14→16)

- Qt/Calamares alınmıyor; kurucu panelle aynı dil (GTK3 + Vala), tam
  tasarım dili. Gerekçe: Calamares Qt yığını çeker (ISO + RAM),
  görünümü bize uymaz; bizim akış üç ekrandan ibaret değilken bile
  parted/sfdisk + mkfs çağrıları küçük ve test edilebilir kod.
- Bölümleme modları:
  - **"Tüm diski kullan"** ve **"Windows'un yanına kur"** → kendi
    kodumuz (parted/sfdisk + mkfs).
  - **"Elle bölümle"** → GParted açılır (ISO'da zaten var); kapanınca
    bizim ekranda hedef kök bölüm + EFI bölümü seçilir.
- Ekranlar: dil, klavye, kullanıcı, saat dilimi, özet, ilerleme, ilk
  açılış — hepsi bizim arayüz.
- Disk düzeni: **btrfs, @ ve @home altbirimleri**; EFI 512 MB FAT32;
  **swap dosyası** (RAM kadar, en fazla 8 GB). BIOS modunda GPT +
  bios_grub bölümü.
- **CI şartı:** QEMU'da boş sanal diske otomatik (kiosk/preseed)
  kurulum → kurulan sistemden yeniden önyükleme → boot-check. Bu test
  yeşil olmadan kurucu "bitti" SAYILMAZ. "Windows'un yanına kur" için
  önceden NTFS bölümlü sanal disk imajıyla ikinci senaryo.

## 3. Güncelleme: apt üstü Kavis güncelleyici (madde 12, 26)

- Bildirim + GUI (Ayarlar > Sistem > Güncelleme).
- Güncelleme ÖNCESİ otomatik **btrfs anlık görüntüsü**; kurtarma
  menüsünden (madde 16/20) tek tıkla geri alma. (mintupdate
  incelemesinin ana dersi: snapshot işleme bağlanır, öneri olmaz —
  docs/referans/mintupdate.md.)
- Kavis paketleri + Debian güvenlik güncellemeleri birlikte akar;
  kullanıcı "sadece güvenlik" seçebilir.

## 4. Yedekleme (madde 13, 56, 61)

- **Dosya yedeği:** harici disk/USB/flash'a rsync — zamanlanmış,
  artımlı. Hedef kullanıcı seçimi; hedef takılı değilse bekler,
  takılınca bildirir.
- **Sistem anlık görüntüleri:** btrfs, Timeshift benzeri arayüz;
  günlük/haftalık plan; kurtarma menüsünden geri alma.
- **Bulut yedeği (Google Drive vb.) 1.0 SONRASI** — şimdi kod
  yazılmaz, yalnız bu kayıt.

## 5. Dosya sistemi: btrfs varsayılan

- Kurucu varsayılanı btrfs (karar 2'deki düzen). **ext4 yalnız "Elle
  bölümle"de** seçilebilir; o zaman anlık görüntü özellikleri
  (güncelleme öncesi snapshot, sistem geri alma) KAPALI olur ve arayüz
  bunu açıkça söyler.

## 6. VirtualBox konuk desteği

- vboxvideo/vboxguest çekirdekte var (dkms yok → Secure Boot ile
  çakışmaz).
- Pano/paylaşımlı klasör için guest-utils Debian 13 depolarında
  (contrib/fasttrack) VARSA ISO'ya girer; yoksa
  docs/bilinen-sorunlar.md'ye not düşülür, dkms'li yol DENENMEZ.

## 7. Dil ve klavye (kurucu + Ayarlar > Klavye ve Dil)

- Sistem dili ve klavye düzeni **birbirinden tamamen bağımsız** iki
  liste.
- **Klavye:** xkeyboard-config'in TAM listesi (bütün düzenler +
  varyantlar), endonim ad + ülke ikonu, arama kutusu, canlı deneme
  kutusu.
- **Dil:** 78 dilin tamamı (po/LINGUAS); seçilince locale-gen + LANG;
  endonim + çeviri yüzdesi (dil-secici.md kuralları geçerli).
- **Her şey UTF-8; her yazı her yerde çalışır.** Dosya adı, kullanıcı
  adı, metin — seçilen dil/klavyeden bağımsız. Kullanıcı adı: Latin
  dışı KABUL; yalnız `/` ve boşluk yasak; Unix giriş adı otomatik
  ASCII'ye çevrilir, görünen ad olduğu gibi kalır.
- **Yazı tipi:** Noto Sans (tüm yazılar) + Noto Sans CJK + Noto Color
  Emoji ISO'ya girer. fontconfig zinciri: Kavis varsayılan fontu →
  Noto Sans → Noto Sans CJK. Ölçüt: Google'dan kopyalanan Japonca
  metin Notepad'e yapıştırılınca kutu (▯) görünmez.
- **CI (FONT-COVERAGE-OK):** her yazıdan (Kiril, Arapça, Çince,
  Japonca, Korece, Hintçe, Tay, İbranice, Yunanca) örnek dosya adı
  oluştur, nemo listesinin ekran görüntüsünde kutu/tofu olmadığını
  denetle; ayrıca her yazı için `fc-match` çıktısını log'a yaz.
- CJK giriş yöntemi (fcitx5) **1.0 SONRASI**.

## 8. ISO boyut sınırı: 1536 MB → 1900 MB

- GitHub Release dosya sınırı 2 GiB; 1900 MB pay bırakır. Gerekçe:
  Flatpak istemcisi + Noto CJK/emoji fontları + Firefox'la 1536 dar.
- CI ISO-SIZE denetimi: **1900 MB üstü HATA, 1700 MB üstü WARN**.
- Boyut takibi her etikette docs/durum.md'ye işlenir.

## 9. Sağlamlık denetimleri ve Kavis Selftest (3 Eyl 2026; madde 72)

Docs kararı şimdi, kod Grup F kapanışında; CI'ın küçük denetimleri
hemen (aynı gün iki commit).

### 9a. CI sağlamlık denetimleri

- **DPKG-VERIFY-OK:** `dpkg -V`; Kavis'in değiştirdiği Debian paket
  dosyası olmasın. Conffile'lar hariç (listelenir); 9995-cleanup
  hook'unun sildiği /usr/share/{doc,doc-base,man,locale} "missing"
  satırları sayılır, hata değil (3 Eyl kalibrasyonu: 9 conffile,
  değişmiş dosya 0, TCG'de 9,5 dk). Kural: Debian paketinin dosyasına
  dokunulmaz; override hep `/etc/kavis`, `/usr/share/kavis`, `/etc/xdg`
  altında.
  **5 Eyl:** md5'ler artık açılışta değil, `9997-dpkg-verify.hook.chroot`
  ile derleme sırasında bir kez hesaplanıyor
  (`/usr/share/kavis/dpkg-verify.txt`); boot-check hükmü o dosyadan
  veriyor. Sebep: 9,5 dakikalık iş, açılışın 300 sn'lik tavanına beş
  QEMU profilinde de sığmıyordu — hiç bitmeden beş dakika yiyor ve
  aynı bütçedeki selftest'i kestiriyordu. Denetim imajın özelliği,
  oturumun değil.
- **Haftalık zamanlanmış koşu:** pazartesi 03:00 UTC güncel trixie ile
  derle + 5 profil QEMU testi. Kırmızıysa otomatik GitHub issue
  ("trixie güncellemesi kırdı: <denetim>"), aynı issue açıksa yorum.
- **DEPS-RANGE-OK:** kavis-* paketlerinde picom, tilix, nemo, openbox,
  plymouth, lightdm, gtk3 için `>=` ve `<<` sınırı; CI ISO'daki gerçek
  sürümleri aralıkla karşılaştırır (`tools/check-deps-range.sh`).
- **Paket sürüm kilidi raporu:** her etikette ISO'daki tüm paket
  sürümleri `docs/surumler/<etiket>.txt`; iki etiket arası fark
  (ekleme/çıkarma/sürüm) release notlarına otomatik. (Grup F kapanışı)
- **Servis sağlığı:** QEMU'da `systemctl --failed` boş (SERVICES-OK);
  journal'da öncelik ≤ err satır sayısı eşiğin altında (JOURNAL-OK;
  **eşik 20** — 3 Eyl kalibrasyonu: QEMU'da test2 ISO'sunda 0 satır,
  failed birim yok, coredump yok; açılış 6 dk TCG'de, live-config
  3:24 en yavaş birim);
  coredump yok (COREDUMP-OK).
- **Açılış süresi:** `systemd-analyze` toplamı + en yavaş 5 birim
  seri günlüğe (BOOT-TIME / BOOT-BLAME); önceki etikete göre %20'den
  fazla yavaşsa WARN (karşılaştırma Grup F kapanışı).
- **Disk/RAM regresyonu:** MEM-USED ve ISO boyutu önceki etiketle
  karşılaştırılır, %10 artış WARN. (Grup F kapanışı)
- **Çeviri:** TR ve EN %100 değilse FAIL; diğer diller yalnız rapor.
- **Kaynak kod:** shellcheck 0 uyarı, vala 0 uyarı, her betik
  `set -eu`, her fonksiyonda açıklama, sabit yol / sihirli sayı grep'i.
  (Grup F kapanışı)
- **Kurtarma:** QEMU'da Shift ile güvenli/eklentisiz açılış ve F3
  menüsü öğeleri testi. (Grup F kapanışı)

### 9b. Kavis Selftest — sistem içi otomatik UI testi (46A'nın devamı, 46B ile birleşir)

Gerçek masaüstünde fare/klavye olaylarını simüle eden, her adımı
loglayan ve anormallikleri yakalayan araç. Hem CI QEMU'da hem
kullanıcının makinesinde (Ayarlar > Sistem > "Sistemi test et")
çalışır. Xvfb'de değil, gerçek oturumda.

**Mekanik.** İkili `kavis-selftest` (Vala; xdotool/XTest ile olay,
libwnck ile pencere durumu, import/xwd ile kare). Koşmadığında sıfır
maliyet: servis yok. Senaryolar YAML (`tests/ui/*.yaml`): her adım =
eylem + beklenti + zaman aşımı. Örnek:

```
- press: super              → expect: window "kavis-start-menu" visible <500ms
- press: super              → expect: window hidden
- click: taskbar "Files"    → expect: window class nemo appears <2s, focused
- drag: window nemo to edge left → expect: geometry = left half ±4px
- key: super+Left           → expect: geometry = left half
- type: "test.txt" in dialog → expect: file exists
- click: quick-settings > brightness 50 → expect: xrandr brightness 0.5
```

rc.xml'deki her keybind otomatik senaryoya dönüşür. Her adımda:
öncesi/sonrası kare + fark yüzdesi, pencere listesi, journal'daki yeni
satırlar, CPU/RAM ölçümü, süre. Beklenti tutmazsa kare + journal +
xprop dökümüyle HATA kaydı. Anormallik yakalama (beklentiden bağımsız,
her adımda): yeni coredump; "critical"/"assertion"/"segfault" satırı;
2 sn'den uzun donma; pencere ekran dışına çıkma; panel/picom/openbox/
snap sürecinin ölmesi; RAM sıçraması >100 MB; bilinmeyen pencere.

Kullanıcı modu: "Sistemi test et" → uyarı "5 dk sürer, pencereler
açılıp kapanır, dokunmayın" → koşar → "Raporu aç" ve "Hata bildir"
(46B: log topla, kişisel veri temizle, GitHub issue/pano). Kayıt modu:
"Kaydı başlat" → kullanıcının tıklama/tuşları xdotool olaylarına
dönüşür, YAML olarak kaydedilir → yeni senaryo. CI'da: DESKTOP-READY
sonrası tüm senaryolar; SELFTEST-OK / SELFTEST-FAIL (<n> hata); rapor
artifact.

**Kapsam — her şey.** gorev-listesi.md'deki her madde için en az bir
senaryo: `tests/ui/<madde-no>-<ad>.yaml`. CI madde → senaryo tablosunu
üretir (`docs/test-kapsami.md`); senaryosu olmayan madde "kapsam dışı"
diye kırmızı. Yeni madde eklenince senaryo eklenmeden "bitti"
sayılmaz. Başlangıç seti (her biri ayrı YAML): açılış; panel (Başlat
tık/Win/Ctrl+Esc, sabitliler, Win+1..9, takvim, hızlı ayarlar, klavye
göstergesi, sanal masaüstü +/✕/Ctrl+Win+ok, dört konum + üç boyut,
otomatik gizle, dış tıklama); pencere (snap 4 kenar + Win+ok,
büyütülmüşü sürükle, ekran dışına çıkamama, Alt+Tab, Alt+F4, Win+D,
başlık düğmeleri); başlat menüsü (arama, kategori, sağ tık, güç
diyaloğu); Ayarlar (8 bölüm, her ayar değiştir-geri al, kavis.conf'a
yazıldı mı); Görev Yöneticisi; Nemo (gezinme, şablonlar, kopyala/taşı/
geri al, çöp, önizleme, arşiv, sağ tık, USB tak → bildirim → güvenle
çıkar, onarım, sekme/ikili panel, Ctrl+tekerlek); Terminal; Notepad;
Kate; emoji seçici + pano geçmişi; hesap makinesi, ekran görüntüsü,
ses OSD, bildirim; Diskler/GParted/Baobab/yazıcı; Firefox; güç
diyaloğu; çok dillilik (TR'ye geç → 20 rastgele metin, tarih biçimi);
kısayol tablosu; kurtarma (Shift, F3); dayanıklılık (30 dk monkey
test → çökme/kaçak yok, RAM sabit).

**Günlükleme.** Her koşu tek klasör
`~/.local/share/kavis/selftest/<tarih-saat>/` (CI'da artifact):
run.log (her adım zaman damgalı), journal.log, xsession.log, kareler
(hata ve seçili adımlarda tam png, diğerlerinde küçük resim),
windows-<adım>.txt, processes-<adım>.txt (kavis-* RSS/USS), coredump
kopyası, sysinfo.txt, report.html + report.json. run.log tek satır,
grep'lenebilir:

```
2026-09-03 16:41:07.213 [12-snap/left-drag] ACTION drag nemo 640,300 → 2,300 | EXPECT geometry=left-half | RESULT FAIL got 0,0 1280x800 | 1.84s | RAM +0 MB | shot=012-fail.png
```

Koşu sonu özeti: toplam/geçti/kaldı/atlandı, en yavaş 5 adım, RAM
başlangıç→bitiş, yeni journal hata sayısı. Saklama: son 10 koşu,
toplam 200 MB'ı geçince en eskiden sil. Görev Yöneticisi >
Günlükler'de "Selftest" süzgeci. "Hata bildir": klasörü zip'ler,
kullanıcı adı/IP/Wi-Fi adı/hostname temizler, GitHub issue ya da
panoya.

**Sıra (3 Eyl güncellemesi: selftest hemen başladı, Grup F sonu
beklenmedi).** CI'ın küçük denetimleri girdi; kavis-selftest çekirdeği
+ ilk 5 senaryo (tests/ui: 01-boot, 03-panel, 06-window-snap,
09-settings-theme, 39-task-manager) + run.log/report.json/html
yazıldı; boot-check DESKTOP-READY sonrası `kavis-selftest --all`
koşturur (SELFTEST-OK/FAIL). Henüz yok: Ayarlar > Sistem "Sistemi test
et" düğmesi, kayıt modu, docs/test-kapsami.md üretimi, rapor
artifact'ı (seri günlükte yalnız run.log satırları; klasörün dışarı
çıkması virtfs ister), rc.xml kısayollarından otomatik senaryo.
**4 Eyl:** Ayarlar > Sistem "Sistemi test et" düğmesi (uyarı → koşu →
"Raporu aç") ve `docs/test-kapsami.md` üretimi
(`tools/gen-test-coverage.py`, lint iş akışında `--check`) girdi.
Kapsam denetimi şimdilik UYARI: 5/71 madde senaryolu, hepsi kırmızı
yanarsa denetim öğrenilmiş körlüğe dönüşür; başlangıç seti tamamlanınca
`--strict` varsayılan olacak. Kısayol senaryosu
(`tools/gen-keybind-scenario.py` → `tests/ui/06-shortcuts.yaml`) ve
rapor artifact'ı da girdi: senaryo düşerse boot-check koşu klasörünü
(küçük resimler hariç, 512 KB sınırı) base64 olarak seri günlüğe
basıyor, duman testi çözüp `selftest-<mode>.tar.gz` olarak teşhis
yapıtına koyuyor. **Kalan tek parça: kayıt modu.** Senaryo
biçimi YAML alt kümesi: `name/title/madde/allowed` + `steps:` listesi,
adım = `do` / `expect` / `timeout` / `note` / `shot`.

## 10. "App Files" — uygulama verileri klasörü (4 Eyl 2026, F maddesi)

Karar kullanıcıdan, tasarım burada. **Kod Grup G'de** (mağaza ile aynı
turda; mağaza kurulumu bağı kuran taraf).

### Sorun

"Minecraft dünyalarım nerede?" sorusunun bugünkü cevabı yok. Veri
`~/.config`, `~/.local/share`, `~/.var/app` (Flatpak) ve bazen
`~/.<uygulamaadı>` arasına dağılıyor; hepsi gizli, hepsi ayrı yerde.
Windows'ta karşılığı `Belgeler\<Oyun>` — kullanıcı oraya bakar.

### Çözüm: `/users/karan/apps`, görünen adı **App Files**

Gerçek bir dizin; içinde **uygulama başına bir sembolik bağ**, hedefi o
uygulamanın XDG'ye uygun veri dizini:

```
/users/karan/apps/
├── Minecraft      -> ../.local/share/minecraft
├── Firefox        -> ../.mozilla/firefox
└── GIMP           -> ../.config/GIMP
```

### Neden bağ, neden bookmark değil

- **XDG bozulmuyor.** Uygulama kendi dizinini kendi yerinde tutar;
  Kavis hiçbir uygulamanın veri yolunu değiştirmez, `XDG_DATA_HOME`
  gibi değişkenlerle oynamaz. Bağı silmek veriyi silmez.
- **Bookmark yetmez.** Nemo yer imi yalnız Nemo'da görünür; dosya
  seçme diyaloğunda, terminalde, başka bir dosya yöneticisinde yok.
  Sembolik bağ dosya sisteminin kendisinde, her yerde çalışır.
- **Kopya/taşıma yok.** Veriyi taşımak uygulamayı bozar ve güncelleme
  ile geri gelir; bağ hiçbir şeyi taşımaz.

### Hangi uygulama, hangi hedef

Bağı **mağaza kurar**, tahmin etmez. Kaynak sırası:

1. Kavis mağaza kataloğundaki `AppFiles=` alanı (bizim eklediğimiz
   alan, uygulama başına elle doğrulanmış yol).
2. Flatpak ise `~/.var/app/<app-id>` — sabit ve garanti.
3. Hiçbiri yoksa **bağ kurulmaz.** Yanlış klasöre bağ, klasörün hiç
   olmamasından kötüdür.

Bağ adı uygulamanın `.desktop` `Name=` alanı (yani menüde ve görev
çubuğunda yazan ad — D1 kuralıyla aynı ad). Kaldırıldığında bağ
silinir, veri dizini olduğu gibi kalır.

### Görünürlük

- Nemo kenar çubuğunda "App Files" (`~/.config/gtk-3.0/bookmarks`
  değil — `nemo` XDG kullanıcı dizinlerini okur; klasör
  `user-dirs.dirs` benzeri bir Kavis girdisiyle değil, **doğrudan yer
  imi** olarak eklenir; ilk oturumda `kavis-session-autostart` yazar).
- Klasör ikonu ayrı (`folder-apps`), boşken açıklayıcı bir README ile
  gelir: "Mağazadan kurduğun uygulamaların verileri burada görünür."
- Yalnızca `/users/karan` altında; sistem genelinde bir karşılığı yok.

### Sınırlar (bilinçli)

- apt ile terminalden kurulan uygulamalar bağ almaz — mağaza kurulumu
  bağı kuran tek yer. (Sonradan "tara ve ekle" düğmesi eklenebilir.)
- Bir uygulamanın verisi birden fazla dizine dağılmışsa tek bağ ana
  dizine gider; ikincil dizinler için kural yazılmaz (kataloğa `AppFiles`
  ikinci satır eklemek gerekirse o zaman değerlendirilir).
- Windows'taki gibi "Belgeler altında" DEĞİL: ev dizini kökü, çünkü
  `/users/karan/Belgeler` kullanıcının kendi belgeleri; uygulama verisi
  onunla karışmamalı.


## 11. Kavis Paylaş — dosya ve pano (8 Eylül 2026)

**Temel ilke: sunucusuz, hesapsız, bulutsuz.** Kavis hiçbir kullanıcı
verisini kendi sunucusunda saklamaz. Dosya, mesaj ve pano içeriği yalnız
iki cihaz arasında gider; geçmiş yalnız iki cihazın kendi diskinde
durur. İnternet üzerinden bağlantıda kullanılan tek dış hizmet
**buluşma (signaling)** sunucusudur ve o da sadece adres değişimini
görür, içeriği göremez.

**Kapalı ekosistem yok.** Dosya aktarımı **LocalSend protokolüyle
uyumlu** olacak; Android/iOS/Windows/macOS'taki LocalSend uygulamaları
Kavis'i görebilecek. Kendi protokolümüzü icat etmenin bedeli, karşı
tarafta Kavis olmayan herkesi dışarıda bırakmaktır.

### Keşif ve bağlantı (yakın)

- mDNS/DNS-SD yayını: cihaz adı, tür, açık anahtar parmak izi.
  **Gerçek hostname ve kullanıcı adı yayılmaz** — varsayılan ad
  `Kavis-<iki rastgele kelime>`, kullanıcı değiştirebilir.
- İlk eşleşmede 6 haneli PIN. Eşleşen cihaz "güvenilir" listesine girer,
  sonraki aktarımlar PIN'siz (kullanıcı "her seferinde sor" diyebilir).
- Aktarım doğrudan TCP + TLS, kendi imzalı sertifika + **parmak izi
  sabitleme**. Aracı sunucu yok.

### Taşıyıcı

- Birincil: Wi-Fi / yerel ağ.
- Aynı ağda değilken **"Doğrudan bağlan"**: biri geçici hotspot açar ya
  da Wi-Fi Direct (wpa_supplicant P2P). Kullanıcıya tek düğme.
- Bluetooth: keşif, eşleşme el sıkışması, pano ve kısa mesaj için.
  Dosyada yalnız Wi-Fi yoksa ve kullanıcı hız uyarısını onaylarsa
  (OBEX — telefonlar da görsün).

### Görünürlük (Ayarlar > Paylaş)

| Kip | Ne olur |
|---|---|
| Kapalı | Hiç yayın yok, cihaz dışarıdan görünmez; kendi göndermek serbest. |
| Sadece güvenilenler (**varsayılan**) | Yayın var, yalnız eşleşmiş cihazlar bağlanır. Ek seçenek **"yayını da gizle"**: mDNS kaydı yayılmaz, güvenilen cihazlar son bilinen adres + parmak iziyle bulur. |
| Herkes | Yakındaki tüm LocalSend uyumlu cihazlar görür; her aktarım yine onay ister. |

Panelde tek tık **"30 dakika görünür ol"**.

### Dosya

- Nemo sağ tık > **Paylaş** → yakındaki cihazlar → gönder. Çoklu dosya
  ve klasör, **akış hâlinde** (zip yok).
- Panelde Paylaş ikonu: alıcı modu anahtarı, aktarım ilerlemesi.
- Gelen dosya: bildirim + kabul/ret → `~/downloads/kavis-share`;
  bildirimde "Klasörü aç".
- Kesilirse **kaldığı yerden devam**; hız ve kalan süre gösterilir.
- Masaüstündeki cihaz ikonuna sürükle-bırak ile gönderme.
- Gelen dosya çalıştırılabilirse (`.sh`/`.AppImage`/`.deb`/ELF)
  **Güvenlik Merkezi'nin indirme kontrolü** devreye girer.

### Pano

- Ayarlar > Paylaş > "Pano paylaşımı": **kapalı (varsayılan)** /
  güvenilen cihazlarla.
- Kavis'te kopyalanan metin ve resim diğer Kavis'te Ctrl+V ile yapışır.
  Boyut sınırı ayarlanabilir (varsayılan 1 MB).
- Tek seferlik "panoyu şu cihaza gönder" seçeneği.
- **Gizlilik:** pano sahibi bilinen bir parola yöneticisiyse içerik hiç
  gönderilmez; kullanıcıya bir kez açıklanır.

### Onay kuralı (v0.5-test1 VM turu eki)

- **Uzak bağlantıda kod girmek yeterli değildir.** Kod doğru olsa bile
  karşı tarafa "X sana bağlanmak istiyor" isteği gider; kabul edilmeden
  bağlantı kurulmaz.
- **Aynı yerel ağda bu istek gerekmez** — fiziksel yakınlık zaten bir
  doğrulamadır; yalnız ilk eşleşmede PIN sorulur.
- **"Rahatsız etme" açıkken hiç kimse mesaj ve dosya gönderemez** — ne
  uzaktan ne aynı ağdan. Gönderen tarafta "alıcı rahatsız edilmek
  istemiyor" bilgisi çıkar. Bildirim birikmez, kuyruğa da alınmaz.

## 12. Kavis Messenger — ayrı uygulama (8 Eylül 2026)

`kavis-messenger`, Vala/GTK3, Kavis tasarım diliyle. İçinde gömülü küçük
HTTPS + WebSocket sunucusu taşır — **Node ya da ayrı bir sunucu yazılımı
gerekmez**, libsoup yeterli.

- Sol sütun cihaz listesi: "Yakındakiler" ve "Uzak cihazlar" başlıkları;
  her satırda ad, çevrimiçi noktası, son mesaj. Sağda sohbet.
- Sohbet: düz metin + bağlantı + dosya. Dosya sohbetin içinden gönderilir
  (yakınsa doğrudan, uzaksa WebRTC veri kanalı).
- **Grup sohbeti YOK** (1.0 sonrası değerlendirilir).

### Yakın mod

Kavis Paylaş'ın keşif ve güvenilir cihaz altyapısını kullanır. Aynı
ağdaki eşleşmiş cihazla ek onay istemez.

### Uzak mod (WebRTC + oda kodu)

Referans mimari Enes'in TurboWarp çoklu oyuncu eklentisinden alınan
YAPIDIR; **kodun tek satırı kopyalanmaz** (değişmez kural).

1. **Yedekli buluşma sunucusu listesi**, sırayla denenir: Kavis'in
   ücretsiz katman sunucusu → genel PeerJS bulutu → kullanıcının
   Ayarlar'a girdiği adres. Herkes aynı sırayı denediği için taraflar
   yine aynı sunucuda buluşur.
2. **ICE:** birden çok STUN + isteğe bağlı TURN. **Kavis TURN
   barındırmaz**; katı NAT'ta kullanıcı kendi TURN bilgisini girer.
3. **Oda modeli:** bir taraf oda kurar ve bir **oda kodu** üretir; diğer
   taraf kodu (varsa şifreyi) girerek katılır. Oda sahibi yöneticidir.
4. **Uygulama imzası:** her bağlantıda sabit `kavis-messenger-v1` dizesi
   aranır; tutmayan bağlantı reddedilir, aynı buluşma sunucusundaki
   alakasız istemciler karışmaz.
5. **Katılma isteği:** kod doğru olsa bile bağlantı otomatik kurulmaz —
   oda sahibine "X katılmak istiyor" düşer. Kabul edilirse eşleşme
   kalıcıdır, sonraki seferlerde kod istenmez.
6. **Moderasyon:** engelleme/engel kaldırma listesi, engellenen kimliğin
   tekrar katılamaması, katılan-ayrılan olayları, bağlı taraf listesi.
7. **Durum:** bağlandı / koptu / son hata, gecikme (ping) — arayüzdeki
   çevrimiçi noktası bunlardan beslenir.
8. **Paket düzeni:** her ileti "ad + kimlik + veri"; alıcıda ada göre
   ayrıştırılır (mesaj, dosya parçası, okundu, yazıyor ayrı adlar).
   Belirli bir tarafa yönlendirilmiş paket de gönderilebilir.
9. **WebRTC kütüphanesi ISO'ya gömülü gelir; CDN'den indirme YOK** — dış
   servis kapanırsa özellik ölmesin.

### Geçmiş ve bildirim

- Sohbet geçmişi yalnız yerelde:
  `~/.local/share/kavis/messenger/<cihaz-id>.jsonl`. Sunucuda kopya yok.
- Çevrimdışı cihaza gönderilen mesaj **yerel kuyrukta** bekler.
- Sohbet başına "geçmişi temizle", genel "tümünü sil".
- Gelen mesaj panelde bildirim; **bildirimden satır içi cevap**.
- Uygulama kapalıyken de dinleyici çalışır — `kavis-share` daemon'ının
  parçası, **ayrı süreç değil** (USS < 8 MB hedefi).

### Tarayıcı köprüsü (Windows / telefondan cevap)

- Kavis'ten gönderilen mesaj LocalSend uyumlu cihazlarda metin bildirimi
  olarak görünür ve içinde bağlantı taşır:
  `https://<ip>:<port>/m/#<64 karakter anahtar>`
- **`#` sonrası tarayıcıda kalır:** sunucuya gitmez, ağda görünmez. Bu
  anahtar hem erişim hakkı hem şifreleme anahtarıdır; bilmeyen ne okur
  ne yazar.
- Tıklayınca **tek dosyalık (~20 KB, framework yok)** sohbet sayfası
  açılır: son 50 mesaj, cevap yazma, dosya gönderme. Sayfayı Kavis'in
  gömülü sunucusu servis eder.
- Kendi imzalı sertifika olduğu için tarayıcı bir kez uyarı verir;
  kullanıcıya bunun beklenen olduğu açıklanır.
- Kavis ekranında ve tarayıcı sayfasında **parmak izinin ilk 4 hanesi**
  gösterilir; aynıysa doğru kişiyle konuşuluyordur.
- Anahtar süreli: varsayılan 1 saat sessizlikten sonra ölür, Kavis
  kapanınca geçersiz.
- **AÇIK SORU (Enes karar verecek):** tarayıcıda "beni hatırla" olsun mu
  (anahtarı saklayıp aynı linkle sonra da giriş), yoksa link tek
  seferlik mi kalsın. **Karar verilene kadar tek seferlik varsayılır.**

### Güvenlik (her iki mod)

- Uçtan uca şifreleme: ilk eşleşmede X25519 anahtar değişimi, sonrası
  kimliği doğrulanmış şifreli kanal (Noise ya da TLS + parmak izi
  sabitleme).
- Her mesaj gönderenin anahtarıyla imzalı; **parmak izi değişirse
  bağlantı reddedilir** ve kullanıcı uyarılır.
- Engelleme listesi: engellenen cihaz ne mesaj ne dosya gönderebilir.
- Aktarım ve bağlantı günlüğü Görev Yöneticisi > Günlükler'de.
- Güvenlik Merkezi'nde durum satırı: paylaşım açık mı, kaç güvenilen
  cihaz, uzak mod açık mı.
- Kilit ekranındayken gelen aktarım kabul edilmez; bildirim birikir
  (rahatsız etme kapalıysa).

### Yapılmayacaklar (karar)

- **Kavis hesabı, bulut depolama, sunucuda mesaj saklama, TURN sunucusu
  barındırma: YOK.** Sebep: maliyet, gizlilik sorumluluğu, KVKK ve tek
  kişilik projenin bakım yükü.
- Uzaktan senkron isteyen kullanıcı mağazadan Syncthing/Nextcloud kurar.
- Telefon entegrasyonu (bildirim aktarımı, SMS, uzaktan kumanda) için
  kendi çözümümüzü yazmıyoruz: 1.0 sonrası **KDE Connect** paketlenip
  Kavis temasına uydurulacak — ayrı madde.

### Selftest kapsamı

- Aynı makinede iki örnek: keşif, PIN eşleşme, 10 MB dosya aktarımı,
  pano gönderimi, mesaj gidiş-geliş, kesinti sonrası devam.
- Uzak mod: sahte buluşma sunucusuyla oda kodu, katılma isteği
  kabul/ret, engellenen cihazın reddedilmesi.
- Rahatsız etme açıkken gönderimin reddedildiğinin doğrulanması.
- Tarayıcı köprüsü: anahtarsız erişim ve süresi dolmuş anahtar
  reddediliyor mu.
