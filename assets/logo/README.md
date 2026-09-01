# assets/logo/ — Kavis logoları

```
assets/logo/koyu-k-logo.svg   ← ✅ hazır — koyu tema logosu
assets/logo/acik-k-logo.svg   ← ✅ hazır — açık tema logosu
```

**Dosya adları sabittir, değiştirilmez** — paket derlemeleri ve panel bu
adlara göre çalışır.

Kullanım kuralı (görev listesi madde 1):

| Bağlam | Logo |
|---|---|
| Açılış ekranı (boot splash) | HER ZAMAN `koyu-k-logo.svg` |
| GRUB menü arka planı | HER ZAMAN `koyu-k-logo.svg` |
| Başlat düğmesi, görev çubuğu, hakkında | etkin temaya göre otomatik |

Tema seçimini yapan tek yer `kavis-panel` içindeki `src/logic/brand.vala`; sistem
bugün tek temalı (koyu) olduğu için pratikte koyu logo görünür.

Tüm ikon boyutları SVG'lerden türetilir (`rsvg-convert` ile), elle PNG
koyulmaz. Üretilen boyutlar ve gittikleri yerler:

| Boyut | Nerede kullanılıyor |
|---|---|
| 16, 22, 24, 32 | görev çubuğu, pencere ikonu, tepsi |
| 48, 64 | başlat düğmesi, masaüstü kısayolları |
| 128, 256 | Ayarlar > Hakkında, karşılama ekranı |
| 512 | Calamares kurulum aracı, GitHub Releases görseli |

**Logoyu değiştirirsen:** aynı ada sahip yeni SVG'yi buraya koy, `viewBox`
`0 0 100 100` ve kare kalsın. Türetilen tüm PNG'ler bir sonraki derlemede
kendiliğinden güncellenir.
