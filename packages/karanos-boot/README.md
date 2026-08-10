# karanos-boot

Açılış ekranı: Plymouth teması, açılış müziği ve splash'i müzik bitene
kadar tutan systemd mekanizması.

## Davranış (bölüm 5)

1. Görsel ekranın ortasında **%15 opaklıkla** belirir, ~1,5 saniyede
   %100'e çıkar ve hafif bir parlama alır (parlama sonrasında yavaşça
   nefes alır — donmuş ekran izlenimi vermesin diye)
2. Altında italik **made by Karan**
3. Aynı anda açılış müziği çalar
4. Splash müzik bitip **0,5 saniye** geçince kapanır; sistem daha erken
   hazır olsa bile bekler, müzik yarıda kesilmez. Kapanmadan önce görsel
   ve ses birlikte söner
5. Ses aygıtı yoksa ya da çalma takılırsa en fazla **10 saniye** beklenir
   ve açılış devam eder. Müzik bir kez çalar, döngüye girmez

## Splash'i müzik bitene kadar ne tutuyor

`karanos-boot-sound.service` `Type=oneshot`. Müzik çalıp kısa fade-out'u
bekleyene kadar "başlıyor" sayılıyor. `plymouth-quit.service` ve
`plymouth-quit-wait.service` için konan drop-in'ler bu servisi
bekletiyor:

```
plymouth-quit.service.d/karanos.conf → After=karanos-boot-sound.service
```

Ses servisi başarısız olsa bile sonlandığı için açılış kilitlenmiyor.
Servisin `TimeoutStartSec=20` değeri, script'in kendi 10 saniyelik
sınırının üstünde bir güvenlik ağı.

## Verilen kararlar

**İtalik yazı PNG olarak gömülü.** Plymouth bitmap font kullanıyor,
italik desteği yok. Yazıyı kendi framebuffer programımızla çizmek
Plymouth'u ikinci kez yazmak olurdu. `src/made-by-karan.svg` paket
derlenirken `rsvg-convert` ile PNG'ye çevriliyor — açılışta yazı tipi
bağımlılığı kalmıyor ve sonuç her makinede birebir aynı.

**Müzik WAV olarak gömülüyor, mp3 olarak değil.** İki sebep: mp3
çalarların çoğunda fade-out yok ve bölüm 5 "görsel ve ses birlikte
yumuşakça söner" diyor; ayrıca açılışta mp3 çözücüye gerek kalmıyor,
`aplay` yetiyor. Dönüştürme `ffmpeg` ile paket derlenirken yapılıyor,
sonuna 0,4 saniyelik fade ekleniyor. Bedeli ~1 MB ISO alanı.

**Tema initramfs'e ayrı hook'la giriyor.** `plymouth-set-default-theme -R`
tek adımda yapardı ama her paket kurulumunda initramfs üretmek live-build
chroot'unda derlemeye dakikalar ekliyor. `postinst` yalnızca temayı
seçiyor, `iso/config/hooks/normal/0300-plymouth.hook.chroot` initramfs'i
bir kez üretip **temanın gerçekten içine girdiğini doğruluyor** —
girmezse derleme durur, çünkü aksi hâlde açılışta siyah ekran görünür ve
sebebi ISO açılmadan anlaşılmaz.

**Görsel tek kopya.** Aslı tema dizininde (`logo.png`), bölüm 5'in
istediği `/usr/share/karanos/boot/boot-image.png` ona giden bir bağ.
Tersi olsaydı tema dizini initramfs'e kopyalanırken bağ kırılırdı.

## Derleme

```bash
tools/build-packages.sh karanos-boot
```

Kaynaklar `assets/boot/` altından `src/boot/` içine kopyalanır (kopya
`.gitignore`'da). `ffmpeg`, `librsvg2-bin` ve `fonts-dejavu-core`
derleme bağımlılığı.

## Nasıl görülür

Splash yalnızca açılış sırasında ekranda ve `plymouth-x11` Debian'da
yok, yani yerelde çizdirilemiyor. Duman testi bu yüzden çekirdek
başladıktan 10 saniye sonra ayrı bir kare alıyor:
`tani-<mod>` yapıtındaki **`screen-<mod>-acilis.png`**.

## VirtualBox notu — vmwgfx hatası

VirtualBox'ın **VMSVGA** ekran denetleyicisiyle çekirdek şu hatayı
veriyor:

```
vmwgfx: [drm] *ERROR* vmwgfx seems to be running on an unsupported hypervisor
```

Sebep VirtualBox'ın VMware'i tam taklit etmemesi; `vmwgfx` sürücüsü
bağlanıyor ama çalışmıyor. Sonuç KMS'in devre dışı kalması olabilir ve
Plymouth DRM yerine metin kipine düşer — splash görünmez.

Karan OS tarafında yapılanlar:
- `simpledrm` initramfs'te; vmwgfx başarısız olsa da UEFI framebuffer
  üstünde bir DRM aygıtı kalıyor.
- `boot-check` her açılışta `DRM-DEVICES` satırıyla `/dev/dri` içeriğini
  ve Plymouth'un hangi çiziciyi seçtiğini bildiriyor.

VirtualBox tarafında yapılabilecek: makine ayarlarında **Ekran →
Grafik Denetleyici** değerini `VBoxSVGA` yapmak. O zaman `vboxvideo`
sürücüsü devreye giriyor (initramfs'te var) ve hata kayboluyor.

**Doğrulandı:** VBoxSVGA'ya geçildiğinde hem `vmwgfx` hatası hem de
splash sonrası konsol metni kayboldu.
