# Kavis — yol haritası ve sürüm planı

Bu belge olmadan proje sonsuza kadar "bitmemiş" kalır. Kural: her grup
bitiminde bu belge güncellenir — biten grubun durumu işaretlenir,
kapsam değiştiyse sürüm eşlemesi düzeltilir.

Madde numaraları görev listesindeki numaralardır (Grup A talimatı,
2026-09-01). Gruplar sırayla yapılır; her grubun sonunda durulur, özet
verilir ve onay beklenir.

## Sürüm eşlemesi

| Sürüm | Gruplar | İçerik (özet) | Durum |
|---|---|---|---|
| 0.2 | A, A2, B | CI iyileşti, Kavis markası, picom, yeni boot splash + F3, autologin + `/users/karan`, güvenlik sertleştirme, CI test altyapısı | ✅ A, A2, B (v0.2-test3 koşusunda doğrulandı; VirtualBox el testi bekliyor) |
| 0.3 | C, D | C/Vala panel, görev çubuğu görünümü + sağ tık, pencere yönetimi/snap/Alt+Tab, sanal masaüstleri, takvim + bildirim, görev yöneticisi + küçük araçlar, ekran görüntüsü/kaydı | 🔨 C ✅ (Vala panel v0.2-test3'te ISO'da doğrulandı), D bekliyor |
| 0.4 | E | Dosya yöneticisi (nemo), hızlı önizleme, terminal + editörler, disk/USB araçları, yazıcı, terminal kolaylıkları | ⏳ |
| 0.5 | F | Ayarlar iskeleti + ekran + kişiselleştirme + çok dillilik + güç + ağ + hakkında + sistem sağlığı + donanım testi | ⏳ |
| 0.6 | G | İndirme yöneticisi, Mağaza, Flatpak, Windows karşılıkları, güvenlik taraması, arama çubuğu | ⏳ |
| 0.7 | H | Oyun Modu, GPU offload, ağ önceliklendirme, cihaz desteği, sanallaştırma | ⏳ |
| 0.9 (RC) | I | Sürücü yardımcısı, kurulum sihirbazı, ilk açılış uygulama seçimi, Calamares (A/B bölümlü disk düzeni + hibernate swap), ilk adımlar rehberi, salt-okunur /usr | ⏳ |
| 1.0 | J | Güncelleme sistemi, APT deposu, USB'den güncelleme (A/B), snapshot arayüzü, otomatik yedekleme, sorun giderici, kurtarma ortamı (F8), hata bildirme | ⏳ |
| 1.x / 2.0 | K + ertelenenler | Giriş + kilit ekranı, çoklu kullanıcı, kavis-gameopt (X3D donanım gelince) | ⏳ |

## 1.0'ın halka açılması için MİNİMUM

Görev listesindeki tanım — bunlar olmadan 1.0 yok:

1. Açılan sistem (BIOS/UEFI/Secure Boot, boot splash, masaüstü)
2. Panel (görev çubuğu + başlat menüsü, C/Vala, RAM hedefi içinde)
3. Dosya yöneticisi
4. Ayarlar
5. Mağaza (indirme yöneticisiyle)
6. Kurulum aracı (Calamares, A/B bölüm yapısı kurulmuş)
7. Güncelleme (snapshot'lı, kesintiye dayanıklı)
8. Kurtarma (F8 + F3)

Gerisi 1.x'e kalabilir.

## 2.0'a ertelenebilecekler

- 18: Giriş ekranı + kilit ekranı + çoklu kullanıcı (0. madde gereği
  şimdilik tek kullanıcı "karan", otomatik giriş)
- 21: kavis-gameopt — X3D CCD pinleme (gerçek donanım şart)
- 33D: Uzaktan yardım (SSH'li kurtarma) — temel kurtarma 1.0'da,
  uzaktan yardım sonra
- 34: TR/EN dışındaki dillerin taslak çevirileri
- 54B: telefon kablosuz eşleşme (KDE Connect benzeri) — kablolu MTP
  1.0'da yeter

## Değişmez hedefler

| Ölçü | Hedef | Mutlak sınır |
|---|---|---|
| ISO boyutu | 1.5 GB altı | GitHub release sınırı |
| Kendi bileşenlerimizin RAM'i | 1 GB altı | 1.5 GB |

ISO şişmemesi için uygulamalar ISO'ya gömülmez; ilk açılışta seçilir ve
indirme yöneticisiyle iner (madde 24).
