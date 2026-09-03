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

- **DPKG-VERIFY-OK:** ISO'da `dpkg -V`; Kavis'in değiştirdiği Debian
  paket dosyası olmasın. Conffile'lar hariç (listelenir). Kural: Debian
  paketinin dosyasına dokunulmaz; override hep `/etc/kavis`,
  `/usr/share/kavis`, `/etc/xdg` altında.
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
  **eşik 60**, ilk koşuların JOURNAL-ERRORS değerine göre daraltılır);
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

**Sıra.** Docs şimdi; CI'ın küçük denetimleri (DPKG-VERIFY, SERVICES,
JOURNAL, COREDUMP, haftalık cron + issue, DEPS-RANGE) hemen; selftest
kodu ve ilk 5 senaryo (açılış, panel, pencere/snap, ayarlar tema,
görev yöneticisi) Grup F kapanışında.
