# Dil seçici — Grup F (Ayarlar) için bağlayıcı kurallar

Altyapı hazır (po/LINGUAS, tools/i18n-stats.sh,
`/usr/share/kavis/i18n-stats.json`); bu belge Ayarlar > Dil ekranı
yazılırken uygulanacak kuralları saklar. Kullanıcı kararıdır,
uygulama sırasında tartışılmaz.

## Liste içeriği ve sıralama

- `po/LINGUAS` içindeki **bütün** diller listelenir — .po dosyası
  olmasa da. gettext .mo bulamayınca msgid'e (İngilizce) düşer,
  yani her dil "seçilebilir" durumdadır.
- Her satır: dilin **kendi dilindeki adı** (endonym: "Türkçe",
  "Deutsch", "日本語") + çeviri yüzdesi.
- Sıralama: önce %100 olanlar, sonra yüzdesi azalan sırada kısmi
  diller, en sonda %0 olanlar **alfabetik**.

## Yüzde gösterimi

- Yüzdeler **çalışma anında hesaplanmaz**;
  `/usr/share/kavis/i18n-stats.json` dosyasından okunur (her paket
  derlemesinde tools/i18n-stats.sh yeniden üretir). Dosya biçimi:
  `{ "tr": {"translated": 161, "total": 161, "percent": 100}, ... }`
- %0 diller **soluk** (dimmed) gösterilir ama seçilebilir; seçilince
  tek satır uyarı:
  > Bu dil henüz çevrilmedi, arayüz İngilizce görünür.
  > Çeviriye katkı: &lt;Weblate linki&gt;
- Kısmi diller için satırda:
  > %68 çevrildi — eksikler İngilizce görünür

Bu iki metin de gettext'e girecek (Ayarlar yazılırken msgid'leri
İngilizce eklenir; İngilizce karşılıkları:
"This language is not translated yet; the interface will appear in
English. Contribute at %s" ve "%d%% translated — untranslated parts
appear in English").

## Diğer

- `en_GB` listede ayrı bir dildir: msgid'ler ABD İngilizcesi olduğu
  için en_GB gerçek bir çeviri hedefidir (colour/centre).
- Weblate depo public olunca bağlanacak; ekstra hazırlık gerekmiyor
  (`po/` standart gettext düzeni). Katkıcı yeni `<dil>.po` ekleyince
  başka hiçbir şey gerekmez: LINGUAS'ta dil zaten var, istatistik ve
  README tablosu sonraki derlemede kendiliğinden güncellenir.
- README'deki "Çeviri durumu" tablosu tools/gen-ceviri-tablosu.py ile
  CI'da güncellenir; dil seçiciyle aynı sıralama kuralını kullanır.
