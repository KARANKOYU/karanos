# VirtualBox'ta Kavis — grafik denetleyicisi notları

Kavis'i VirtualBox'ta deneyen herkesin karşılaşacağı davranışlar.
(Açılış deneyimi işleri sırasında, v0.3-test1 el testinden çıkarıldı.)

## Hangi grafik denetleyicisi?

| Denetleyici | Çekirdek sürücüsü | Durum |
|---|---|---|
| **VMSVGA** (VirtualBox'ın Linux için varsayılanı) | vmwgfx → probe başarısız → simpledrm | Çalışıyor. vmwgfx her açılışta `*ERROR* ... unsupported hypervisor` yazar (aşağıda), sürücü kendini geri çeker, ekran simpledrm ile sürülür. 3B ivme yok. |
| **VBoxSVGA** | vboxvideo | Çalışması beklenir ve vmwgfx uyarısı hiç oluşmaz — vboxvideo initramfs'imizde var. Henüz elle doğrulanmadı; doğrulanınca burası güncellenecek. |
| VBoxVGA | vboxvideo / vesa | Eski uyumluluk seçeneği, tercih etme. |

**Öneri (belgelere/duyurulara yazılacak hâli):** VirtualBox'ta varsayılan
VMSVGA ile açılır; sorun yaşanırsa ya da günlükte vmwgfx hatası
istenmiyorsa denetleyiciyi **VBoxSVGA** yapın.

## vmwgfx "unsupported hypervisor" hatası

```
vmwgfx 0000:00:02.0: [drm] *ERROR* vmwgfx seems to be running on an
unsupported hypervisor. This configuration is likely broken.
```

- Sebep: VMSVGA, VMware'in SVGA aygıtının VirtualBox taklidi; vmwgfx
  sürücüsü gerçek VMware imzasını bulamayınca kendini durduruyor.
- Zararsız: probe başarısız olunca simpledrm (EFI/VESA framebuffer)
  devrede kalıyor, splash ve masaüstü çalışıyor.
- Gerçek donanımda hiç oluşmaz; QEMU'da da oluşmaz (virtio-gpu/bochs).
- Konsolda artık görünmez (`loglevel=3`, iso/auto/config) ama
  `journalctl -k` içinde durur. **Sistem sağlığı aracı (Grup F) günlük
  tararken bu satırı hata saymamalı** — bilinen hypervisor uyarıları
  listesine girecek (docs/bilinen-sorunlar.md).

## Diğer VirtualBox notları

- Açılışta görünen `BdsDxe: failed to load Boot0002 ...` satırı BİZİM
  hatamız değil: VM'in BOŞ sabit diskini önce denemesinden geliyor.
  Çözüm: VM ayarlarında önyükleme sırasını optik sürücü önce yapın
  (ya da diski listeden çıkarın); kurulumdan sonra sıra normale döner.

- Pano paylaşımı / otomatik çözünürlük Guest Additions ister; DKMS
  modülleri Secure Boot açıkken imzasız oldukları için yüklenmez.
  Karar (MOK imzalama mı, "Secure Boot'u kapatın" belgesi mi) Grup
  F/G'de (docs/bilinen-sorunlar.md).
- CI, QEMU (virtio-gpu/bochs) üzerinde test ediyor; VirtualBox'taki
  splash zamanlaması CI'da birebir ölçülmüyor — el testi gerekiyor.
