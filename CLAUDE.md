# Kavis — çalışma kuralları

Debian trixie tabanlı, Windows benzeri masaüstüne sahip kişisel dağıtım.
Proje dili **Türkçe**: commit mesajları, belgeler ve arayüz metinleri
Türkçe. Fonksiyon açıklamaları (Doxygen/docstring) ise **İngilizce**
(görev listesi "kod kalitesi" kuralı; eski dosyalarda Türkçe yorum
kalmış olabilir, yenilerde İngilizce).

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
kısaca: "amd64" dizesi koda gömülmez (`KAVIS_MIMARI` değişkeni /
`dpkg --print-architecture`), paketler `all`/`any`, x86'ya özgü her şey
mimari kontrolüyle sarılıp diğer mimarilerde sessizce ve açıklamalı
kapanır, donanım çalışma anında tespit edilir. arm64 derlemesi istenene
kadar CI'a eklenmez.

## Kaynak belgeler

| Dosya | Ne için |
|---|---|
| `docs/gorev-listesi.md` | GÜNCEL görev listesi: 58 madde + grup sırası + değişmez kurallar. Asıl yönerge bu. |
| `docs/roadmap.md` | Hangi grup bitince hangi sürüm çıkacak; her grup sonunda güncellenir. |
| `docs/kavis-arayuz-metinleri.md` | Arayüzde görünen **bütün** TR/EN metinler. |
| `docs/kavis-claude-code-prompt.md` | ESKİ görev tanımı (Karan OS dönemi). Tarihsel bağlam; yeni listeyle çelişirse yeni liste kazanır. |
| `docs/github-kurulumu.md` | GitHub tarafında ne oluşturulacağı (depolar, Pages, GPG, secret'lar). |

**Arayüzde görünecek hiçbir metni kendin uydurma.** Etiket, buton yazısı,
hata mesajı, bildirim — hepsi `docs/kavis-arayuz-metinleri.md` içindeki
tablolardan alınır. Tabloda karşılığı yoksa uydurmak yerine sor.

## Renk kimliği

**Kavis tek temalı: KOYU.** Açık tema yok — ne varsayılan olarak, ne
seçenek olarak. Ayarlar > Görünüm'de "Tema: Açık/Koyu" seçeneği
bulunmuyor. Yeni aşamalarda açık tema için ek iş yapılmaz.

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
**pakete girmiyor**; ileride istenirse diye kaynak olarak saklanıyor.

Renk değiştirmek gerekirse tek kaynak `packages/kavis-theme/` — CSS
dosyalarındaki `@define-color` blokları ve `tools/gen-*.py` başındaki
sabitler.

## Derleme ortamı — en önemli kısıt

Geliştirme GitHub Codespaces'te yapılıyor: Debian konteyner, **2 çekirdek**,
~20 GB boş disk.

- **ISO'yu yerelde derleme.** `lb build` yalnızca GitHub Actions'ta çalışır
  (`.github/workflows/build-iso.yml`). Sebep çekirdek sayısı ve disk;
  Codespace'te sadece yapılandırma yazılır ve tek tek bileşen testi yapılır.
- İlk doğrulama yine CI'da: QEMU duman testi ve `tani-<mod>` yapıtı (seri
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
shellcheck -S warning tools/*.sh iso/auto/* iso/config/hooks/normal/*.hook.*
```

## Hedefler (bölüm 20)

| Ölçü | Hedef | Mutlak sınır |
|---|---|---|
| ISO boyutu | 1.5 GB altı | GitHub release sınırı gereği aşılmamalı |
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
- Commit mesajları Türkçe, ne yapıldığını değil **neyi neden düzelttiğini**
  anlatır.
- Commit mesajlarına `Co-Authored-By` satırı **ekleme**.
- Yeni CI doğrulama adımını önce Codespace'te aynı komutlarla çalıştır;
  yerelde geçmeyeni push etme. Yeni bağımlılık → hem paketin `Depends`
  alanına hem iş akışının kurulum adımına.

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
- **`--apt-recommends false` derleme için**, kurulu sistem için değil.
  `9990-apt-recommends.hook.chroot` kurulan sistemde Recommends'i geri açar;
  ayrıca Recommends kapalıyken gelen paketler (`libpam-systemd` gibi) paket
  listelerinde açıkça yazılmalıdır.
