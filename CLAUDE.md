# Karan OS — çalışma kuralları

Debian trixie tabanlı, Windows benzeri masaüstüne sahip kişisel dağıtım.
Proje dili **Türkçe**: kod yorumları, commit mesajları, belgeler ve arayüz
metinleri Türkçe yazılır.

## Kaynak belgeler

| Dosya | Ne için |
|---|---|
| `docs/karanos-claude-code-prompt.md` | Tam görev tanımı. Bölüm 17 geliştirme sırası, bölüm 20 kurallar, bölüm 21 GitHub kurulumu. |
| `docs/karanos-arayuz-metinleri.md` | Arayüzde görünen **bütün** TR/EN metinler. |
| `docs/github-kurulumu.md` | GitHub tarafında ne oluşturulacağı (depolar, Pages, GPG, secret'lar). |

**Arayüzde görünecek hiçbir metni kendin uydurma.** Etiket, buton yazısı,
hata mesajı, bildirim — hepsi `docs/karanos-arayuz-metinleri.md` içindeki
tablolardan alınır. Tabloda karşılığı yoksa uydurmak yerine sor.

## Renk kimliği

**Varsayılan görünüm koyu.** Açık tema ikinci seçenek.

| Rol | Koyu (varsayılan) | Açık |
|---|---|---|
| Ana vurgu | `#2DD4BF` turkuaz | `#0D9488` |
| İkincil | `#4F92F7` mavi | `#2563EB` |
| Zemin (masaüstü) | `#0D141B` | `#EEF2F6` |
| Panel / görev çubuğu | `#121C26` | — |
| Yüzey (pencere, menü) | `#17222C` | `#FFFFFF` |
| Yüzey (hover) | `#1D2C38` | `#E2E9EF` |
| Kenarlık | `#233A45` | `#CBD6DF` |
| Ana metin | `#E6EDF3` | `#1B2732` |
| İkincil metin | `#8B9BA8` | `#5C6B78` |
| Başarı / uyarı / hata | `#22C55E` / `#F59E0B` / `#EF4444` | `#16A34A` / `#D97706` / `#DC2626` |

Açık temada turkuaz/mavi koyulaştırılıyor: `#2DD4BF` beyaz zeminde beyaz
yazıyı taşıyamayacak kadar açık (kontrast ~1.7).

Renk değiştirmek gerekirse tek kaynak `packages/karanos-theme/` — CSS
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
  `karanos-iso` yapıtını indirmesini istemek makul.

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

- Her aşamada **önce kısa bir plan sun, onay al, sonra kodla** (bölüm 20).
- Geliştirme sırası bölüm 17'deki 14 aşama. Sırayı atlama.
- Commit mesajları Türkçe, ne yapıldığını değil **neyi neden düzelttiğini**
  anlatır.
- Commit mesajlarına `Co-Authored-By` satırı **ekleme**.

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
