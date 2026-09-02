# Ayarlar uygulaması — sorun önleme taraması (madde 59, Grup F)

Tarih: 2026-09-02. Süre sınırı 15 dk — cinnamon (Mint ayarları) en çok
yorumlu açık issue'lar + xrandr/NetworkManager bilinen tuzakları.

## Başka masaüstlerinin en çok şikâyet aldığı yerler

- **Klavye düzeni İngilizce'ye takılıyor** (cinnamon #7792, 28 yorum;
  #13369): birden çok kaynak (setxkbmap, ibus, uygulama başına grup)
  aynı anda düzen değiştirince kazanan belirsiz. Çıkarım: TEK global
  düzen, per-window layout kapalı (VM listesi 2F ile aynı karar);
  Ayarlar yalnız setxkbmap + /etc/default/keyboard yazar, ibus'a
  bulaşılmaz.
- **Çoklu monitörde kilit/uyku pencereleri tek ekrana taşıyor**
  (#5487/#9659, 57+41): RandR olaylarında pencere kurtarma zor iş.
  Çıkarım: Grup F'de çözünürlük değiştirirken paneli kendi RandR
  dinleyicimizle yeniden konumlandır (panel zaten monitor izliyor);
  pencere taşıma işine hiç girme.
- **Kısayol yakalama** (#7124): Alt+PrintScreen gibi kombinasyonlar
  yakalanamıyor. Çıkarım: kısayol LİSTESİ göster (madde 34), düzenleme
  Grup F sonrasına — yakalama widget'ı ayrı, zor iş.

## xrandr / ekran tuzakları

- Mod listesi `xrandr` çıktısından değil XCB/RandR'dan da okunabilir;
  en hafif yol `xrandr` çıktısını parse etmek ama BİÇİM sürüme göre
  oynar → yalnız "WxH_hz" desenli satırlar alınır, gerisi atlanır.
- `--brightness` DONANIM parlaklığı DEĞİL (gamma çarpanı) — 3C kararı:
  backlight yoksa yazılım düşüşü, tooltip'te hangisi olduğu yazar.
- Çözünürlük değişiminde onay geri sayımı (15 sn "korunsun mu?")
  ŞART — yanlış mod siyah ekran bırakır, otomatik geri dönüş olmalı.
- VM'de tek çıkış (Virtual-1) + kvm/vbox mod listesi kısa; test планı
  buna göre.

## NetworkManager

- Liste `nmcli -t` (terse) ile okunur — insan biçimi sürümle oynar,
  terse alan sırası sözleşmeli. İlk adımda YALNIZ okuma (1A kapsamı);
  bağlan/şifre diyalogları sonra.
- Wi-Fi donanımı yokken `nmcli dev` boş "wifi" satırı döndürmez —
  4E'deki gösterge de aynı kaynaktan okumalı.

## Backlight / güç

- /sys/class/backlight yazımı root ister; pkexec her kaydırıcı
  hareketinde KABUL EDİLEMEZ → udev kuralı: backlight aygıtına
  `video` grubuna yazma izni (RUN+chmod g+w), kullanıcı `video`
  grubunda (bootappend'e eklenecek). 3C bunu kullanacak.
- Güç modları (51): CPU governor + planlar zaten logic/power.vala'da
  (Battery alt paneli B4'te geldi) — Ayarlar AYNI kodu kullanır, iki
  ayrı yazıcı olmaz.

## Bizim mimariye çıkarımlar

1. kavis.conf tek dosya; her bölüm kendi grubuna yazar, canlı yayılım
   TEK mekanizmayla (aşağıda karar) — cinnamon'daki "hangi süreç
   hangi anahtarı dinliyor" karmaşasına girilmez.
2. Ayarlar süreci hiçbir şeyi köke yazmaz; kök isteyen tek şey klavye
   varsayılanı (/etc/default/keyboard) → o da YAZILMAZ, oturum düzeyi
   setxkbmap yeter (canlı sistem tek kullanıcı).
3. RAM: tek pencere, sayfalar tembel kurulur (picker'daki
   ensure_glyph_page deseni) — 25 MB hedefi böyle tutar.
