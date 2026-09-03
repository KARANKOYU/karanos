# Bilinen sorunlar / teknik borç — şimdi not, sonra iş

Görülüp BİLEREK düzeltilmeyen şeyler (2026-09-02'de açılış deneyimi
işleriyle başladı; sonradan görülen teknik borçlar da buraya eklenir).
Her biri ilgili grup başlarken bu listeden düşülür; çözülen ya da görev
listesine maddeleşen kayıt silinmez, işaretlenir ki aynı tartışma
tekrar açılmasın.

## 1. vmwgfx hatası günlükte durmaya devam edecek → MADDELEŞTİ: 62

(2026-09-02: görev listesine madde 62 olarak girdi — liste Grup D'de
tanımlanacak, sistem sağlığı aracı Grup F'de kullanacak. Kayıt burada
tarihçe için duruyor.)

VirtualBox VMSVGA'da `vmwgfx ... *ERROR* unsupported hypervisor` her
açılışta dmesg'e düşer. Konsoldan gizlendi (`loglevel=3`) ama
`journalctl -k` içinde durur. **Sistem sağlığı aracı günlük tararken
bunu "hata" saymamalı** — hypervisor kaynaklı bilinen uyarılar için bir
istisna listesi gerekiyor (vmwgfx bu listenin ilk üyesi; ayrıntı
docs/referans/virtualbox.md).

## 2. Splash zamanlaması CI'da VirtualBox'ı temsil etmiyor → sürekli

CI QEMU'da virtio-gpu/bochs kullanıyor; VirtualBox'ta vmwgfx/vboxvideo.
CI'da geçen splash zamanlaması (SPLASH-TIMING, SPLASH-HANDOFF)
VirtualBox'ta farklı çıkabilir. İkisini de kapsayan otomatik test yok.
Şimdilik VirtualBox el testi; ileride belki VirtualBox'lı bir CI koşucusu.

## 3. GDK_GL=disable yalnız panelde → ÇÖZÜLDÜ (madde 61, Grup D)

(2026-09-02: packages/kavis-common/appinit.vala ortak başlangıcı —
kavis-panel, kavis-snap ve kavis-tools kullanıyor; bizim olmayan GTK
uygulamaları (nemo-desktop) autostart'ta ortam değişkeniyle alıyor.
Kayıt tarihçe için duruyor.)

llvmpipe/libLLVM tuzağının (~50 MB) çözümü `GDK_GL=disable` şimdilik
yalnız kavis-panel'in main.vala'sında. Ayarlar, mağaza ve diğer GTK
uygulamaları aynı tuzağa düşecek. **Ortak bir başlangıç noktası gerekli**
(tüm kavis-* GTK uygulamaları için wrapper ya da ortak kütüphane);
o güne kadar yeni GTK uygulaması eklenirse aynı satır elle konur.

## 4. Guest Additions ↔ Secure Boot çelişkisi → karar Grup F/G

VirtualBox'ta pano paylaşımı/otomatik çözünürlük için Guest Additions
gerekiyor; DKMS modülleri imzasız olduğundan Secure Boot açıkken
yüklenmiyor. Karar bekliyor: belgede "VirtualBox'ta Secure Boot'u
kapatın" mı denecek, yoksa MOK ile imzalama mı sunulacak. (Aynı kısıt
madde 68'in fan sürücülerini — msi-ec — de bağlıyor.)

## 5. picom use-damage=false CPU maliyeti → gerçek donanımda ölç (madde 13/38)

Hayalet pencere düzeltmesi (`use-damage=false` +
`unredir-if-possible=false`) her karede tam ekran yeniden çizim demek:
boşta maliyet ~sıfır, pencere sürükleme/video oynatmada CPU artışı var.
Gerçek donanımda (GPU'lu) ölçülecek; madde 38 (kişiselleştirme) ve
madde 13 (oyun modu) sırasında GPU varken yeniden değerlendirilecek.

## 6. Xorg VM'de ~110 MB RSS → gerçek donanımda ölç

Panel llvmpipe tuzağından kurtarıldı ama Xorg'un kendisi VM'de ~110 MB
gösteriyor — aynı llvmpipe/yazılım kipi etkisi olabilir. Kendi
bileşenimiz değil ama boşta RAM hedefini (1 GB) etkiliyor; gerçek
donanımda (GPU sürücülü) yeniden ölçülecek.

## 7. CI: actions/cache@v4 Node 20 uyarısı → @v5'e geçiş (madde 22)

build-iso.yml'deki actions/cache@v4 Node 20 uyarısı veriyor. Acil
değil; madde 22 (CI iyileştirmesi) kapsamında @v5'e geçilecek.

## 8. Reddit postundaki RAM rakamı eski (kod işi değil — hatırlatma)

Reddit'te paylaşılan 232-240 MB boşta RAM rakamı artık geçerli değil;
güncel ölçüm ~300 MB (canlı oturum, overlay dahil). Düzeltmeyi Enes
yapacak — bu satır yalnızca hatırlatma, kod/doküman işi çıkarmaz.

## 9. kavis-snap sürüklemesi Xvfb'de doğrulanamadı → ÇÖZÜLDÜ (3 Eyl, debug turu)

(3 Eyl 2026: iki kök sebep bulundu ve kapatıldı — (1) Wnck'nin
geometrisi openbox'ın etkileşimli taşıması sırasında donuk kalıyor,
daemon "çerçeve oynadı mı"yı hiç göremiyordu; çerçeve konumu artık
X'ten okunuyor. (2) libwnck + NorthWest gravity çerçeve payını iki kez
uygulatıyor, çerçeveli pencere bir başlık yüksekliği aşağı yerleşiyordu;
STATIC gravity'ye geçildi. Xvfb'de gerçek sürükleme ÇALIŞIYOR; eski
başarısızlık XTEST değil, `xdotool windowmove` taklidinin openbox
taşımasını hiç devreye sokmamasıydı. Şimdi `tools/check-snap.sh` CI'da
başlığa basıp fareyi sürükler (SNAP-OK); QEMU VM'de Tilix ve Nemo ile
sağ/sol/üst kenar + köşe doğrulandı. Kayıt tarihçe için.)

Xvfb+openbox, XTEST kaynaklı başlık çubuğu sürüklemesini işletmedi
sanılmıştı; kavis-snap testi `xdotool windowmove` taklidiyle yapıldı.

## 10. Hızlı yakalamanın pano kopyası 60 saniyeyle sınırlı → ÇÖZÜLDÜ (sonraki-isler 5)

(2 Eyl 2026: pano geçmişi kalıcı depoya taşındı — panel her kopyayı,
GÖRSELLER dahil, ~/.cache/kavis/clipboard'a yazıyor (7 gün/200 MB);
geç yapıştıran kullanıcı Win+V geçmişinden bulur. Kayıt tarihçe için.)

X panosu sahibi süreçle ölür; `kavis-tools capture --quick` görüntüyü
panoya koyup 60 sn yaşıyor, sonra çıkıyor — geç yapıştıran kullanıcı
panoda bulamaz (dosya her zaman kayıtlı). Kalıcı çözüm: panelin pano
geçmişine görüntü desteği eklemek (şimdilik yalnız metin) — Grup E/F
arasında değerlendirilecek.

## 11. ISO boyut artışı (Grup D paketleri) → ÖLÇÜLDÜ, İZLEMEDE

Grup D ISO'ya ffmpeg, nemo (bağımlılıklarıyla), flameshot, slop,
xdotool, fonts-noto-color-emoji, libglib2.0-bin, rfkill, xsct,
brightnessctl ekledi. Ölçüm: **645 MB (v0.3-test1'den test4'e kadar
sabitti) → 741 MB (v0.3-test5)**. Sebep: emoji fontu + kavis-tools +
görev yöneticisi/ekran kaydı paketleri (ffmpeg en büyüğü). Sınır 1536
MB — pay bol ama artış hızlı; **her ISO koşusunda boyut buradan
izlenecek**. Şişme sorun olursa ilk aday: ffmpeg'i ISO'dan çıkarıp
indirme yöneticisiyle tembel kuruluma almak (madde 23).

## 12. Emoji seçicide arama yok → ÇÖZÜLDÜ (Grup D düzeltmesi 4)

(2 Eyl 2026: küratörlü setin İngilizce adları Python unicodedata ile
bir kez üretilip depoya işlendi — tools/gen-emoji-adlari.py →
emoji_names.vala, 764 glif; arama + Tümü + son kullanılanlar geldi.
TR adlar istenirse üretilen tabloya sözcük eklenerek. Kayıt tarihçe
için duruyor.)

Aranabilirlik Unicode ad veritabanı (TR+EN adlar) ister; v1 bilerek
kategori+tıkla ile sınırlı. Veri seti kararıyla birlikte eklenecek.

## VirtualBox'ta Win (Super) kısayolları (3 Eyl 2026, v0.4-test1 C4)

Kavis'in W- (Win) bağları openbox'ta çalışıyor (CI KEYBIND tablosu +
Xvfb doğrulaması). VirtualBox'ta Windows ana makinesi Win tuşunu
klavye yakalanmadıysa kendine alır (Başlat menüsü açılır, konuk
görmez); "Giriş > Klavye > Klavye Otomatik Yakalama" açıkken ve VM
penceresi tıklanmışken konuğa geçer. Alternatif kanıt: VM içinde
`xev` ile Super_L basımının geldiğini görmek.

## VirtualBox'ta imleç şekli takılı kalıyor (C5 şüphesi)

Metin kutusundan çıkınca I-beam kalması VirtualBox'ın konuk imleç
şekli senkronunda (guest additions yokken) bilinen bir belirti.
Kavis tarafında alınan önlemler: XCURSOR_THEME/SIZE ortamı
(Xsession.d/55kavis-imlec), kök imlecin nemo-desktop sonrası yeniden
ayarlanması, GTK settings.ini imleç adı. Gerçek donanımda yeniden
görülürse konu Kavis'te demektir — kararlar.md 6 (guest-utils) da
bu belirtiyi kapatabilir.
