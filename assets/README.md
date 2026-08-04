# assets/ — elle konulacak kaynak dosyalar

Bu klasördeki dosyalar **kodla üretilmez**, elle konur. Derleme sırasında
buradan alınıp `.deb` paketlerinin içine gömülür.

| Klasör | İçerik | Durum |
|---|---|---|
| `boot/` | Açılış görseli (PNG) + açılış müziği (MP3) | ⏳ **sen koyacaksın** |
| `logo/` | K logosu (SVG) | ✅ hazır |
| `wallpapers/` | Duvar kağıtları (PNG/JPG) | ⏳ isteğe bağlı |
| `cursor/` | İmleç teması kaynak PNG'leri | 🔧 kod üretecek |

Her klasörün kendi `README.md`'sinde tam dosya adı ve teknik sınırlar yazıyor.

## Kural

**Dosya adları birebir uyacak.** Derleme script'leri bu adları arar; farklı bir
ad koyarsan paket hatasız derlenir ama dosya ISO'ya girmez.
