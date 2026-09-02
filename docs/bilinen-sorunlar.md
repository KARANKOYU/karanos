# Bilinen sorunlar — şimdi not, sonra iş

Açılış deneyimi işleri sırasında (2026-09-02) görülüp BİLEREK
düzeltilmeyen şeyler. Her biri ilgili grup başlarken bu listeden
düşülür; çözülen madde silinmez, "çözüldü" işaretlenir ki aynı tartışma
tekrar açılmasın.

## 1. vmwgfx hatası günlükte durmaya devam edecek → Grup F

VirtualBox VMSVGA'da `vmwgfx ... *ERROR* unsupported hypervisor` her
açılışta dmesg'e düşer. Konsoldan gizlendi (`loglevel=3`) ama
`journalctl -k` içinde durur. **Sistem sağlığı aracı (madde 44, Grup F)
günlük tararken bunu "hata" saymamalı** — hypervisor kaynaklı bilinen
uyarılar için bir istisna listesi gerekiyor (vmwgfx bu listenin ilk
üyesi; ayrıntı docs/referans/virtualbox.md).

## 2. Splash zamanlaması CI'da VirtualBox'ı temsil etmiyor → sürekli

CI QEMU'da virtio-gpu/bochs kullanıyor; VirtualBox'ta vmwgfx/vboxvideo.
CI'da geçen splash zamanlaması (SPLASH-TIMING, SPLASH-HANDOFF)
VirtualBox'ta farklı çıkabilir. İkisini de kapsayan otomatik test yok.
Şimdilik VirtualBox el testi; ileride belki VirtualBox'lı bir CI koşucusu.

## 3. GDK_GL=disable yalnız panelde → Grup D/E (ilk GTK uygulamasında)

llvmpipe/libLLVM tuzağının (~50 MB) çözümü `GDK_GL=disable` şimdilik
yalnız kavis-panel'in main.vala'sında. Ayarlar, mağaza ve diğer GTK
uygulamaları aynı tuzağa düşecek. **Ortak bir başlangıç noktası gerekli**
(tüm kavis-* GTK uygulamaları için wrapper ya da ortak kütüphane) —
Grup D/E'de ilk yeni GTK uygulaması yazılırken çözülecek; o güne kadar
yeni GTK uygulaması eklenirse aynı satır elle konur.

## 4. Guest Additions ↔ Secure Boot çelişkisi → karar Grup F/G

VirtualBox'ta pano paylaşımı/otomatik çözünürlük için Guest Additions
gerekiyor; DKMS modülleri imzasız olduğundan Secure Boot açıkken
yüklenmiyor. Karar bekliyor: belgede "VirtualBox'ta Secure Boot'u
kapatın" mı denecek, yoksa MOK ile imzalama mı sunulacak.
