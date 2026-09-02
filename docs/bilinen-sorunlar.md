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

## 3. GDK_GL=disable yalnız panelde → MADDELEŞTİ: 61

(2026-09-02: görev listesine madde 61 olarak girdi — Grup D'de ilk yeni
GTK uygulamasıyla birlikte çözülecek. Kayıt tarihçe için duruyor.)

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
