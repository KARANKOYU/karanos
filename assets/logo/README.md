# assets/logo/ — Karan OS logosu

```
assets/logo/k-logo.svg     ← ✅ hazır, sende bir şey yapmana gerek yok
```

Tüm ikon boyutları bu tek SVG'den türetilir (`rsvg-convert` ile), elle PNG
koyulmayacak. Üretilen boyutlar ve gittikleri yerler:

| Boyut | Nerede kullanılıyor |
|---|---|
| 16, 22, 24, 32 | görev çubuğu, pencere ikonu, tepsi |
| 48, 64 | başlat düğmesi, masaüstü kısayolları |
| 128, 256 | Ayarlar > Hakkında, karşılama ekranı |
| 512 | Calamares kurulum aracı, GitHub Releases görseli |

Logonun renkleri prompt 4. bölümdeki kimlikle birebir aynı:
turuncu `#FF8C1A` → sarı `#FFBF00` degrade, beyaz `#FFFFFF` çizgiler.

**Logoyu değiştirirsen:** aynı ada sahip yeni SVG'yi buraya koy, `viewBox`
`0 0 100 100` ve kare kalsın. Türetilen tüm PNG'ler bir sonraki derlemede
kendiliğinden güncellenir.
