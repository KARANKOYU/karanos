# Grup C — sorun önleme taraması (madde 59)

Tarih: 2026-09-01. Konu: görev çubuğunun C/Vala'ya taşınması. Referans
listemizde doğrudan bir panel projesi yok; en yakın akraba olarak
**polybar** (C++/X11 çubuk) tarandı (`gh api`, en çok yorumlanan 25
issue). tint2 GitLab'da olduğu için taranamadı.

## polybar'da tekrar eden şikâyetler → bizde karşılığı

- **Şeffaflık/kompozitör aksaklıkları** ("transparency not working",
  "graphical glitch with fullscreen", "polybar completely invisible"):
  şeffaf çubuk + kompozitör etkileşimi kırılgan bölge. ÖNLEM: panel
  OPAK (paletten düz renk); şeffaflık/blur işi picom'a ve madde 38'e
  bırakıldı, çubuk kendisi alfa kullanmıyor.
- **Tepsi simgelerinin taşması / tam ekran üstünde kalması**: XEmbed
  tepsisi en sorunlu parça. ÖNLEM: tepsi bu grupta bilerek YOK (madde
  37'yle birlikte, StatusNotifier tarafında ele alınacak; XEmbed'e
  yatırım yapılmayacak).
- **Çoklu monitör** ("Set polybar on multiple screens"): çubuğun hangi
  monitörde duracağı sürekli sorun. Bizde bugün birincil monitör +
  strut tüm ekran genişliğinde; madde 5'te (sağ tık > hangi ekran)
  monitör başına konum gelecek — bu tarama o maddeye not.
- **RAM/CPU aşımı** ("RAM / CPU overuse"): sonsuz döngü/yoklama
  kaynaklı. ÖNLEM: pencere olayları Wnck sinyalleriyle (yoklama yok);
  yoklanan yalnız saat (30 sn), klavye (2 sn) ve pil (30 sn).
- **Başlangıç sırası donmaları** ("freeze at startup of programs in
  i3"): WM ile yarış. ÖNLEM: autostart'taki 3 denemeli yeniden başlatma
  korunuyor; panel WM'siz de çökmeden açılıyor.

## Karara bağlananlar

1. Panel opak kalır; görsel yumuşaklık kompozitörden gelir.
2. XEmbed tepsisi hiçbir aşamada yazılmayacak; doğrudan
   StatusNotifier'a gidilecek (madde 37).
3. Olay tabanlı mimari korunur; yeni gösterge eklerken yoklama aralığı
   30 sn'nin altına indirilmez (klavye göstergesindeki 2 sn, Ayarlar
   entegrasyonunda olaya çevrilecek — madde 10/34 notu).
