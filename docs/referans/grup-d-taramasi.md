# Grup D — madde 59 sorun önleme taraması (2026-09-02)

Kapsam: openbox snap, bildirim daemon'ları (dunst), X11 pano
yöneticileri, flameshot. Süre sınırı gereği en çok görünen şikâyetler;
kaynaklar en altta.

## Openbox + Aero snap

- Openbox'ta sürükle-kenara-yapıştır YOK; topluluk üç yolla çözmüş:
  openbox'ı yamalamak (openbox-with-windows-snapping, emilypeto/
  openbox-window-snap), ayrı daemon (opensnap), ya da yalnız klavye
  (Custom-keybinds gist'leri). Yama yolu bize kapalı (Debian imzalı
  paketini kullanıyoruz, kendi openbox derlemeyiz).
- opensnap'in bilinen dertleri: geri-çıkarma (unsnap) yok; ekran
  düzeni değişince (monitör tak/çıkar) düzeni algılamıyor; çoklu
  monitörde yalnız ana monitörde tam çalışıyor.
- DERS: kendi kenar-yapıştırma yardımcımız (1) unsnap'i baştan
  yapmalı (snap öncesi geometriyi saklayıp kenardan çekilince geri
  vermeli), (2) ekran düzenini her olayda yeniden okumalı (önbellek
  yok), (3) çoklu monitörü baştan hesaba katmalı (monitör
  geometrisine göre kenar tespiti).
- Klavye snap'i openbox'ın kendi aksiyonlarıyla güvenli
  (UnmaximizeFull + MoveResizeTo yüzdeli değerler) — yama gerekmiyor.

## Bildirim daemon'u (dunst'un dertleri → kendi daemon'ımızın kuralları)

Kendi panel-içi daemon'ımızı yazacağız (madde 37); dunst'ta en çok
şikâyet edilenler bizim tasarım kurallarımız olsun:

- `org.freedesktop.Notifications` adı TEK sahiplik: başka daemon
  (notify-osd vb.) kuruluysa ad alınamıyor ve bildirimler sessizce
  kayboluyor. Panel adı alamazsa günlüğe açık hata yazmalı; ISO'ya
  başka bildirim daemon'u SOKULMAMALI (Recommends ile gelebilir —
  paket listelerinde dikkat).
- Uzun süre çalışınca bellek şişmesi + bildirimlerin kesilmesi:
  geçmiş listesi SINIRLI tutulmalı (örn. 50 kayıt), kapatılan
  bildirimlerin GTK pencereleri gerçekten yok edilmeli.
- Tıklamada üç bildirimin birden kapanması gibi hedefleme hataları:
  her bildirim kendi penceresi/objesi olmalı, ortak pencerede satır
  boyama yapılmamalı.
- Ekran kapan/açılınca bildirimlerin görünmez olması: konum her
  gösterimde monitör geometrisinden yeniden hesaplanmalı.
- Aciliyet seviyeleri (low/normal/critical) baştan ayrışmalı;
  critical DND'de bile gösterilir (spec böyle).

## X11 pano geçmişi (Win+V) tuzakları

- X11'de panonun sahibi KOPYALAYAN uygulamadır: uygulama kapanınca
  pano boşalır. Pano yöneticisi içerik değişir değişmez içeriği
  KENDİNE kopyalamalı (yalnız olay dinlemek yetmez).
- PRIMARY (seçim) ve CLIPBOARD (Ctrl+C) ayrı; geçmişe yalnız
  CLIPBOARD alınmalı — PRIMARY'yi de kaydetmek her seçimi geçmişe
  doldurur (kalabalık + gizlilik).
- Yarış koşulları: sahiplik alma/isteme döngüsünde kendi set
  ettiğimiz içeriği tekrar yakalayıp sonsuz döngüye girmemek için
  "son yazdığımız" içerik işaretlenmeli.
- Şifre yöneticileri panoya "geçici" içerik koyar; x-kde-passwordManagerHint
  / clipboard manager hint MIME'ları görülürse geçmişe ALINMAMALI.

## Flameshot

(A2'deki flameshot.md'nin üstüne, güncel issue'lardan:)

- En gürültülü sorunlar Wayland + çoklu monitör kaynaklı — biz X11
  olduğumuz için ana akım dertlerin çoğu bizi ısırmıyor.
- X11 çoklu monitörde DPI/yerleşim hataları hâlâ bildiriliyor;
  "monitörü tek tek çek" davranışına geçiş (PR #4498) izlenmeli.
  Bizim ayarlarda "aktif pencere / monitör / hepsi" seçenekleri
  monitör bazlı çekimle uyumlu tasarlanmalı.
- Gecikme (delay) seçeneği önizlemeyi geciktiriyor, çekimi değil —
  kendi hızlı-yakalama akışımızda flameshot'un delay'ine güvenme.

## Kaynaklar

- https://github.com/BeanGreen247/openbox-with-windows-snapping
- https://github.com/lawl/opensnap
- https://github.com/emilypeto/openbox-window-snap
- https://github.com/dunst-project/dunst/issues/1355 (birlikte kapanma)
- https://github.com/dunst-project/dunst/issues/1396 (ekran aç/kapa)
- https://github.com/dunst-project/dunst/issues/1186 (bellek/uzun süre)
- https://github.com/dunst-project/dunst/issues/1313 (daemon adı çakışması)
- http://www.uninformativ.de/blog/postings/2017-04-02/0/POSTING-en.html (X11 pano)
- https://jameshunt.us/writings/x11-clipboard-management-foibles/
- https://github.com/flameshot-org/flameshot/issues/3073 ve PR #4498
