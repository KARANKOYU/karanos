# Tuval — nesne düzenleme ve bağlamsal üst çubuk (13b-EK)

3 Eyl 2026 kararı. Bu belge "önceki tasarımın üstüne" verilen ek;
önceki Tuval tasarımı depoda yazılı değil (oturum sıfırlanmasında
kayboldu) — bulunduğunda bu dosyanın başına eklenecek. Kod Grup F
sonrası; şimdilik yalnız karar kaydı.

## 1. Her nesne sonradan düzenlenir — istisna yok
- Fırça darbesi, fosforlu, şekil, metin, resim, not, damga, ölçü, grup:
  hepsi seçilebilir nesne. Hiçbir şey tuvale yapışıp kaybolmaz. Fırça
  darbesi de seçilip taşınır/ölçeklenir/rengi değişir (vektör olarak
  saklanır, PNG'ye yalnız dışa aktarırken dönüşür).
- Tıkla → seçilir; boş yere tıkla → seçim kalkar; Esc → seçim kalkar;
  Tab → sonraki nesne.

## 2. Seçim çerçevesi ve tutamaklar (Word/PowerPoint davranışı)
- Turkuaz ince çerçeve + 8 tutamak: 4 köşe (daire) + 4 kenar ortası
  (kare) + üstte döndürme tutamağı (çerçeveden 24 px yukarıda, çizgiyle
  bağlı, daire içinde ↻).
- Köşe: ORANI KORUYARAK büyüt/küçült (varsayılan); Shift oran serbest;
  Ctrl merkezden. İmleç çapraz çift ok.
- Kenar: yalnız o yönde ger/sık; imleç ↔/↕; Alt ile merkezden.
- Döndürme: sürükleyince döner, Shift 15° adım; dairesel ok imleci;
  açı balonu ("37°"); merkez Alt+sürükle ile taşınır.
- Çerçeve içinden sürükle: taşı; Shift eksene kilit; ok tuşları 1 px,
  Shift+ok 10 px; yapışma kılavuzları (kırmızı çizgi) ve ızgara.
- Tutamak tooltip'i: "Köşeden: oranlı büyüt · Shift: serbest · Ctrl:
  merkezden" — ilk kullanımda bir kez, sonra hover'da 1 sn gecikmeyle.
- Metin kutusu kenardan gerilince satır kırılır, köşeden ölçeklenince
  yazı boyutu büyür (font alanı güncellenir).
- Çoklu seçim: ortak çerçeve; Ctrl+G grup; grup içine çift tık.
- Çokgen/eğri/ok: ikinci katman tutamaklar (köşe noktaları, Bezier
  kolları); çift tık nokta düzenleme (ekle: çizgi üstüne çift tık,
  sil: Delete).
- Kilitli nesne: gri çerçeve, tutamak yok, kilit bağlamsal çubuktan.

## 3. Çift tık
Metin/not/balon → metin düzenleme (Ctrl+B/I/U); şekil → içine metin
(şekille taşınır); resim → kırpma; grup → içine gir; fırça darbesi →
nokta düzenleme.

## 4. Bağlamsal üst çubuk (Word gibi seçime göre değişir)
- Seçim yokken: seçili ARACIN ayarları (sonraki çizimin varsayılanı).
- Nesne seçiliyken aynı yerde o nesnenin ayarları, anında uygulanır:
  - Şekil: dış çizgi rengi/kalınlığı (0-50, kaydırıcı + kutu)/stili,
    köşe yarıçapı, dolgu (renk/gradyan/yok), opaklık, gölge, ok uçları,
    "şekli değiştir" (boyut korunur).
  - Fırça darbesi: renk, kalınlık, opaklık, yumuşatma, uç türü.
  - Metin: font, boyut, K/I/U/üstü çizili, renk, hizalama, satır
    aralığı, arka plan kutusu/rengi, kenarlık, dikey hizalama, otomatik
    sığdır.
  - Resim: opaklık, köşe yuvarlat, kırp, aynala, 90° döndür, orijinale
    sıfırla, filtre (gri/parlaklık/kontrast).
  - Not: renk, font. Grup: ortak alanlar toplu değişir.
  - Ortak sağ blok: X/Y/W/H/açı kutuları, katman, kilit, öne/arkaya,
    çoğalt, sil, hizala/dağıt (2+ seçim), stil kopyala/yapıştır.
- Çubuk taşarsa "…" ile ikinci satır; küçük pencerede ikonlar metinsiz.
- Aynı özellikler sağ tık menüsünde ve sağ panelde "Özellikler".

## 5. Stil tutarlılığı
"Varsayılan yap"; stil kopyala Ctrl+Shift+C / yapıştır Ctrl+Shift+V;
biçim boyacısı (Esc ile çık); tema değişince "tema rengi" işaretli
nesneler uyar, sabit renkliler kalır.

## 6. Geri al
Her tutamak hareketi ve özellik değişikliği tek adım; metinde kelime
bazlı.

## 7. Selftest ekleri
Dikdörtgen çiz → köşeden büyüt (oran korunuyor mu) → kenardan ger →
45° döndür → dış çizgi rengi → çift tıkla metin → kaydet-aç → aynı
değerler. Metin nesnesi: çift tık düzenle → kutu genişlet → font büyüt.
