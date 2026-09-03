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
