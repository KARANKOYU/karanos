# Kavis — çalışma kuralları

Debian trixie tabanlı, Windows benzeri masaüstüne sahip, tek
geliştiricili **açık kaynak olacak** dağıtım. Kavis adı global paylaşım
için seçildi; r/linux'ta duyuruldu, çeviri/test/kod katkıcısı aranıyor;
depo Vala taşıması bitince public olacak.
Belgeler (docs/) ve Türkçe çeviri (po/tr.po) Türkçe; kod tabanı,
yorumlar, commit mesajları ve CI çıktıları **İngilizce** (aşağıdaki
dil kuralı).

## Dil kuralı — kod tabanı TAMAMEN İngilizce (3 Eyl 2026)

Değişken/fonksiyon/sınıf/dosya adları, yorumlar, commit mesajları, log
satırları, hata mesajları (kullanıcıya görünenler gettext üzerinden,
msgid İngilizce), CI çıktıları (KAVIS-CHECK satırları dahil), betik
adları, config anahtarları — hepsi İngilizce. Türkçe YALNIZ `po/tr.po`
ve `docs/` altındaki belgelerde (bu dosya dahil). packages/, iso/,
tools/, tests/, .github/ altında Türkçe kalmaz; CI satırı değişirse
onu okuyan betik de güncellenir. Commit mesajları İngilizce.

## Marka — Kavis (eski adı Karan OS)

Ürün adı KODA GÖMÜLMEZ. Tek kaynak:
`packages/kavis-theme/src/os-release` (kurulu sistemde `/etc/os-release`).
Ad, sürüm ve adresler yalnızca oradan okunur — shell tarafında
`. /etc/os-release`, panelde `src/logic/brand.vala`,
derlemede `iso/auto/config` ve iş akışının "Sürüm bilgisi" adımı.
İsim yine değişirse iş, o dosya + `assets/logo/` görsellerinden ibaret
olmalı.

Değişmeyenler: sistem kullanıcısı `karan`, logo dosya adları
(`koyu-k-logo.svg` / `acik-k-logo.svg`), git deposunun adı (`karanos`)
ve `KARANKOYU/karanos` adresleri.

Logo kuralı (madde 1): açılış ekranı ve GRUB **her zaman koyu logo**;
başlat düğmesi/hakkında etkin temaya göre (`marka.logo_yolu()`).

## Mimari — çok-mimarili hazırlık

Bugün yalnız **amd64** ISO'su üretilir ama kod baştan çok mimarili yazılır
(hedef: ileride arm64). Kurallar `docs/gorev-listesi.md` MİMARİ ilkesinde;
kısaca: "amd64" dizesi koda gömülmez (`KAVIS_ARCH` değişkeni /
`dpkg --print-architecture`), paketler `all`/`any`, x86'ya özgü her şey
mimari kontrolüyle sarılıp diğer mimarilerde sessizce ve açıklamalı
kapanır, donanım çalışma anında tespit edilir. arm64 derlemesi istenene
kadar CI'a eklenmez.

## Kaynak belgeler

| Dosya | Ne için |
|---|---|
| `docs/tasarim-dili.md` | Köşe/animasyon/boşluk kuralları (test8 J) — her yeni widget buna uyar. |
| `docs/gorev-listesi.md` | GÜNCEL görev listesi: 58 madde + grup sırası + değişmez kurallar. Asıl yönerge bu. |
| `docs/roadmap.md` | Hangi grup bitince hangi sürüm çıkacak; her grup sonunda güncellenir. |
| `po/` | Arayüz çevirileri (gettext, alan adı `kavis`): `kavis.pot` + `tr.po` + üretilen `xx.po` (sahte uzun test dili). Kaynak metinler koddaki İngilizce msgid'ler. |
| `docs/kavis-claude-code-prompt.md` | ESKİ görev tanımı (Karan OS dönemi). Tarihsel bağlam; yeni listeyle çelişirse yeni liste kazanır. |
| `docs/github-kurulumu.md` | GitHub tarafında ne oluşturulacağı (depolar, Pages, GPG, secret'lar). |

**Arayüz metinleri (gettext, 2 Eyl 2026'dan beri):** koddaki İngilizce
msgid kaynak metindir; Türkçesi `po/tr.po`'da. Yeni metin eklerken üç
adım ZORUNLU: `_("English text")` yaz → `tools/gen-pot.sh` →
`po/tr.po`'ya çeviriyi ekle ve `tools/gen-xx-po.py` çalıştır
(`tools/check-i18n.sh` yerelde geçmeli; CI aynı denetimi koşar).
Kullanıcının onayladığı bir metin varsa birebir onu kullan; kararsız
kaldığın kullanıcıya görünür metinlerde uydurmak yerine sor. GRUB ve
Plymouth .mo okuyamaz: oradaki metinler derlemede gömülür (9600/9601
hook'ları, kavis-boot SVG'leri) ve İngilizce yazılır.

## Renk kimliği

**İki tema: KOYU (varsayılan) + AÇIK.** Geçiş Ayarlar > Görünüm'deki
"Tema: Açık/Koyu" seçeneğiyle yapılacak (Ayarlar Grup F'de geliyor).
Şu an kodda yalnız koyu tema var; açık temanın kaynağı (`gtk-light.css`)
ve logosu (`acik-k-logo.svg`) hazır bekliyor.

| Rol | Değer |
|---|---|
| Ana vurgu | `#2DD4BF` turkuaz |
| İkincil | `#4F92F7` mavi |
| Zemin (masaüstü) | `#0D141B` |
| Panel / görev çubuğu | `#121C26` |
| Yüzey (pencere, menü) | `#17222C` |
| Yüzey (hover) | `#1D2C38` |
| Kenarlık | `#233A45` |
| Ana metin | `#E6EDF3` |
| İkincil metin | `#8B9BA8` |
| Başarı / uyarı / hata | `#22C55E` / `#F59E0B` / `#EF4444` |

Turkuaz açık bir renk: üstüne gelen yazı **koyu** olmalı (`#0D141B`),
beyaz değil.

`packages/kavis-theme/src/gtk-3.0/gtk-light.css` depoda duruyor ama
**pakete henüz girmiyor**; açık tema devreye alınırken (Grup F)
kullanılacak kaynak bu. (Açık temada turkuaz `#0D9488`, mavi `#2563EB` —
beyaz zeminde kontrast için koyulaştırılmış değerler, dosyada hazır.)

Renk değiştirmek gerekirse tek kaynak `packages/kavis-theme/` — CSS
dosyalarındaki `@define-color` blokları ve `tools/gen-*.py` başındaki
sabitler.

## Derleme ortamı — en önemli kısıt

Geliştirme GitHub Codespaces'te yapılıyor: Debian konteyner, **2 çekirdek**,
~20 GB boş disk.

- **ISO'yu yerelde derleme.** `lb build` yalnızca GitHub Actions'ta çalışır
  (`.github/workflows/build-iso.yml`). Sebep çekirdek sayısı ve disk;
  Codespace'te sadece yapılandırma yazılır ve tek tek bileşen testi yapılır.
- İlk doğrulama yine CI'da: QEMU duman testi ve `diag-<mode>` yapıtı (seri
  günlük + otomatik PNG ekran görüntüleri). Bir şey bozulduğunda önce oraya bak
  — 40 dakikalık koşuyu tahminle harcama.
- Kullanıcının bağlantısı ~1 MB/s. ISO'yu indirip **VirtualBox'ta elle test
  edebiliyor**; "bunu gözünle görmen lazım" diyebileceğin durumlarda
  `kavis-iso` yapıtını indirmesini istemek makul.

## Push etmeden önce

CI koşusu 5–40 dakika sürüyor; yazım hatasını oraya kadar taşıma:

```bash
tools/check-config.sh      # sözdizimi, çalıştırma izinleri, YAML
tools/check-packages.sh    # paket adları Debian trixie arşivinde var mı (~2 sn)
tools/check-picom.sh       # compositor yapılandırması gerçek picom 12.5'te açılıyor mu
tools/check-visual.sh      # yazı, DPI, başlık çubuğu eşleşmesi, köşe yarıçapı
tools/gen-test-coverage.py --check   # bitmiş grupta senaryosuz madde var mı
shellcheck -S warning tools/*.sh iso/auto/* iso/config/hooks/normal/*.hook.*
```

## Hedefler (bölüm 20)

| Ölçü | Hedef | Mutlak sınır |
|---|---|---|
| ISO boyutu | 1700 MB altı | 1900 MB (kararlar.md 8; GitHub Release 2 GiB sınırına pay) |
| Boşta RAM | 1 GB | 1.5 GB |

Canlı (live) oturumda ölçülen RAM kurulu sistemden yüksek çıkar — squashfs
üstünde RAM overlay var. Bu yüzden sınır aşılırsa CI uyarır, testi
başarısız saymaz.

## Yöntem

- Geliştirme `docs/gorev-listesi.md` sonundaki GRUP sırasına göre yürür
  (A → A2 → B → ... → K). Her grubun sonunda DUR: özet ver, commit et,
  kullanıcıdan onay bekle; "devam" denmeden sonraki gruba geçme.
- Her grubun BAŞINDA sorun önleme taraması yap (madde 59): ilgili
  projelerin en çok oy/yorum almış issue'larından tekrar eden şikâyetleri
  çıkar, docs/referans/ altına işle, kullanıcıya kısa liste ver.
  Sınır: grup başına ~15 dk, ilk 20-30 issue.
- Performans kuralı: sürekli çalışan bileşenler C/C++/Vala; kullanıcı
  uygulamalarında C/C++ tercih (iş 3 katına çıkıyorsa Python kabul);
  ISO scriptleri shell. Hazır ve hızlı araç varsa kur-ayarla, yeniden
  yazma. Basit yolu seçtiysen nedenini tek cümleyle söyle.
- Başka projeden TEK SATIR kod kopyalama — yaklaşımı öğren, sıfırdan yaz.
  apt ile hazır program kurmak serbest.
- Her grubun sonunda kendi kodunu gözden geçir (mantık hatası, sızıntı,
  yarım iş, çift iş) ve ne bulduğunu söyle.
- Commit mesajları İngilizce (3 Eyl 2026 kuralı), ne yapıldığını değil
  **neyi neden düzelttiğini** anlatır.
- Commit mesajlarına `Co-Authored-By` satırı **ekleme**.
- Etiket (`v*`) konacak commit'in mesajına `[skip ci]` **yazma** —
  etiket koşusunu bulandırır; `[skip ci]` yalnız CI'ın kendi otomatik
  commit'inde (çeviri tablosu) olur.
- Yeni CI doğrulama adımını önce Codespace'te aynı komutlarla çalıştır;
  yerelde geçmeyeni push etme. Yeni bağımlılık → hem paketin `Depends`
  alanına hem iş akışının kurulum adımına.

## Codespace host'unda YASAK komutlar (4 Eyl 2026 kuralı)

Geliştirme konteynerinin kendisi bir kez kurban gitti: bir hook host'ta
çalıştı, `/home` ve kullanıcı hesabı bozuldu, konteyner yeniden
kurulmak zorunda kaldı. Bu yüzden host'ta ASLA çalıştırılmaz:

- `useradd` / `usermod` / `userdel` / `groupadd` / `groupmod` /
  `groupdel` / `passwd` / `chpasswd`,
- `/etc/passwd`, `/etc/group`, `/etc/shadow`, `/etc/sudoers*` düzenleme,
- `mount` / `umount`, `systemctl` (enable/disable/start dahil),
  `update-initramfs`, `plymouth-set-default-theme`, `dpkg-divert`,
- `/home` üzerinde herhangi bir değişiklik (silme, taşıma, sembolik bağ),
- Kavis paketlerini host'a kurmak (`dpkg -i`, `apt install ./kavis-*.deb`)
  — bakım betikleri host'un `/usr/lib/os-release`'ini saptırır ve
  systemd birimlerini etkinleştirir. Paket testi VM'de yapılır.

Bunların yeri: `iso/config/hooks/normal/*.hook.chroot` (live-build
chroot'u), `iso/config/includes.chroot/usr/lib/live/config/*` (canlı
sistem) ya da QEMU/VirtualBox VM'i. Her chroot hook'unun başında
**host koruması** var: `/usr/share/kavis/build-marker` yoksa hook
çalışmayı reddeder (marker yalnız includes.chroot ile chroot'a girer).
`tools/check-config.sh` her hook'ta bu korumayı arar; koruma silinirse
push öncesi denetim kırmızı yanar. Bir test betiği hook'u çalıştırmak
zorundaysa (örn. `tools/check-keybinds.sh`) hem yolları geçici dizine
çevirir hem korumayı sed ile atar — kopyanın dokunduğu her şey $TMP
altındadır.

## Bilinen tuzaklar

Bir kez ısırdıkları için burada duruyorlar:

- **live-build `set timeout` yazmaz.** GRUB'da timeout tanımsızsa menü
  sonsuza kadar tuş bekler ve ISO hiç açılmaz.
  `iso/config/hooks/normal/9500-grub-timeout.hook.binary` bunu ekler,
  iş akışındaki "ISO içi önyükleyici doğrulaması" adımı da ISO'nun içinden
  `config.cfg`'yi çıkarıp satırın gerçekten orada olduğunu doğrular.
- **binary hook'lar `binary/` dizininin İÇİNDE çalışır**, derleme kökünde
  değil. Yolları buna göre yaz.
- **`cmd | tee` tee'nin çıkış kodunu döndürür.** `iso/auto/build` bu yüzden
  `#!/bin/bash` + `set -eo pipefail` kullanır; olmazsa başarısız derleme
  CI'da yeşil görünür.
- **Chroot hook'ları host'ta çalıştırma.** `0230-home-users` `/home`'u
  siler ve `/users`'a bağlar, `9995-cleanup` `/usr/share/doc`'u siler,
  `0100-kavis-services` `systemctl enable` çağırır. Hepsinde artık host
  koruması var (yukarıdaki bölüm); korumayı kaldırmadan çalıştırmayı
  deneme.
- **`--apt-recommends false` derleme için**, kurulu sistem için değil.
  `9990-apt-recommends.hook.chroot` kurulan sistemde Recommends'i geri açar;
  ayrıca Recommends kapalıyken gelen paketler (`libpam-systemd` gibi) paket
  listelerinde açıkça yazılmalıdır.
