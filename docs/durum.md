# Kavis — durum ve karar günlüğü

Bu dosya "ne yapıldı" listesi değil, **neden öyle yapıldı** kaydı.
Kod okununca anlaşılmayan kararlar, denenip vazgeçilen yollar ve bir kez
ısırmış tuzaklar burada. En yeni en üstte.

NOT: 2026-09-01 öncesi kayıtlar "Karan OS" adını ve `karanos-*` paket
adlarını kullanır — tarihsel doğruluk için değiştirilmedi.

---

## Grup A — Kavis markası, CI iyileştirmesi, logolar, yol haritası

Yeni çalışma düzeni: `docs/gorev-listesi.md` (58 madde, grup sırası).
Grup A'nın kararları:

### Marka değişikliği nasıl yapıldı

- `karanos` → `kavis` her yerde: paket adları, dizinler, systemd
  servisleri, Plymouth teması, hostname, ISO adı, `KARANOS_VERSION` →
  `KAVIS_VERSION`, `KARANOS-CHECK` → `KAVIS-CHECK`. GTK/simge/imleç
  teması `Karan` → `Kavis`, duvar kağıtları `karan-*` → `kavis-*`.
- DOKUNULMAYANLAR: sistem kullanıcısı `karan`, `made-by-karan.svg`
  ("made by Karan" kişi imzası), logo dosya adları, depo adı ve
  `KARANKOYU/karanos` adresleri, paket imzalarındaki "Karan" kişi adı.
- `docs/durum.md` geçmişi ve `docs/kavis-claude-code-prompt.md` (eski
  görev tanımı) kasten YENİDEN YAZILMADI — tarihsel kayıt. Eski prompt
  dosyasının başına "tarihsel" notu kondu.
- Kullanıcı CI'ı yeşile çevirmek için web'den `koyu-k-logo.svg`'yi
  `k-logo.svg`'ye çevirmişti (commit 48c0a80); ad kurala göre
  `koyu-k-logo.svg`'ye geri alındı, derleme iki yeni ada bağlandı.

### İsim bir daha sabitlenmesin (tek kaynak)

Tek kaynak `packages/kavis-theme/src/os-release` (kurulu sistemde
`/etc/os-release`). Okuyanlar: `iso/auto/config` (`. os-release` ile
NAME/ID/HOME_URL), iş akışının "Sürüm bilgisi" adımı (ISO adı ID'den),
`9600-grub-marka.hook.binary` (menü adları chroot'un os-release'inden),
`kavis_panel/marka.py` (panel/hakkında; tek fallback sabiti orada).
Adı denetleyen kontroller de ada değil "Debian kimliği kalmış mı"ya
bakıyor (`ID=debian` görürsek devralma başarısız).

### Madde 22 — CI

- ISO artık push'ta DERLENMİYOR; yalnızca elle (workflow_dispatch) ve
  `v*` etiketi. `build-packages.yml`'nin push tetikleyicisi de kalktı
  (paketler her ISO koşusunda zaten derlenip doğrulanıyor). Push'ta
  yalnızca lint koşuyor.
- apt önbelleği: `iso/cache` (live-build'in debootstrap + .deb
  önbelleği) `actions/cache` ile saklanıyor; anahtar paket listelerinin
  hash'i. Bunun için `lb clean --purge` → `lb clean` yapıldı: purge
  cache'i de siliyor ve geri getirilen önbelleği çöpe atıyordu.
- "Releases'e yükle" neden hiç çalışmadı: adım yalnızca etiket push'unda
  koşuyordu ve depoya bugüne dek HİÇ `v*` etiketi atılmamış; üstelik
  `draft: true` idi (etiket olsaydı bile sürüm taslakta kalacaktı).
  Düzeltme: taslak kapatıldı; elle koşuda "release" kutusu işaretlenirse
  pre-release olarak da yayınlanabiliyor.

### Madde 1 — logolar

- `koyu-k-logo.svg` + `acik-k-logo.svg` tema paketiyle
  `/usr/share/kavis/logo/` altına kuruluyor.
- Boot splash ve GRUB: her zaman koyu logo. GRUB arka planı artık duvar
  kağıdı değil; `gen-wallpapers.py --grub` koyu logoyu düz zeminde, üst
  üçte birlik bölgede çiziyor (menü metni ortada — çakışmasın diye).
- Başlat düğmesi: `marka.logo_resmi()` etkin temaya göre seçiyor
  (bugün tek tema koyu olduğundan pratikte hep koyu logo).

### Kod dili kararı

Görev listesi gereği fonksiyon açıklamaları artık İNGİLİZCE (ilk örnek
`marka.py`). Eski dosyaların Türkçe yorumları yeniden yazılmadı —
çeviri uğruna churn yaratmamak için; dokunulan yerlerde kademeli geçiş.

---

## Üçüncü VirtualBox testi — siyah boşluk

VBoxSVGA'ya geçince `vmwgfx` hatası ve splash sonrası konsol metni
kayboldu. Yani teşhis doğruydu: vmwgfx bağlanıp çalışmayınca KMS devre
dışı kalıyor ve Plymouth framebuffer'a düşüyordu.

Kalan sorun: splash kapandıktan sonra masaüstünden önce ~3 saniye siyah
ekran.

### `After=display-manager.service` neden ÇÖZÜM DEĞİL

İlk akla gelen, `plymouth-quit`'i giriş yöneticisinden sonraya almaktı.
Debian'ın `lightdm.service` dosyasını okuyunca bunun döngü yaratacağı
görüldü:

```
# replaces plymouth-quit since lightdm quits plymouth on its own
Conflicts=plymouth-quit.service
After=plymouth-quit.service
OnFailure=plymouth-quit.service
```

lightdm zaten `plymouth-quit`'ten SONRA başlıyor. Ona `After=lightdm`
eklemek karşılıklı bağımlılık olur; systemd döngüyü rastgele bir yerden
kırar ve sonuç öngörülemez hâle gelir. Bu yol kapalı.

### Gerçek sebep: retain-splash boş kareyi tutuyordu

`plymouth quit --retain-splash` ekranda **son kareyi** bırakıyor. Ses
servisi çıkmadan hemen önce splash'i sıfıra kadar söndürdüğü için o son
kare bomboştu — tutulan şey siyahlıktı.

Çözüm: fade artık sıfıra değil **%35'e** iniyor (`SONME_HEDEF`). Görsel
soluk da olsa ekranda kalıyor, X ayağa kalkana kadar geçen süre
"kararmış açılış ekranı" gibi görünüyor, siyah bir hiçlik gibi değil.

Bölüm 5'in istediği "yumuşakça söner" korunuyor, yalnızca dibe
vurmuyor. Kendi giriş ekranımız geldiğinde (5. aşama) devir teslimi biz
yöneteceğiz; o zaman tam sönmeye dönülebilir.

### DRM sürücüsü kapsaması

Farklı hipervizörlerde aynı sorunun çıkmaması için initramfs'te bulunan
sürücüler: `bochs`, `bochs_drm`, `qxl`, `virtio_gpu`, `vmwgfx`,
`vboxvideo`, `simpledrm`. Gerçek donanımınkiler (`i915`, `amdgpu`,
`nouveau`) initramfs-tools'un `most` listesinden zaten geliyor.

`0300-plymouth.hook.chroot` artık hangilerinin gerçekten girdiğini
tek tek yazıyor ve sanal makine sürücülerinden biri eksikse uyarıyor —
"o hipervizörde splash görünmeyebilir" bilgisi derleme günlüğünde
kalıyor.

---

## İkinci VirtualBox testi — kalan iki sorun

Müzik artık splash ekrandayken başlıyor (ilk düzeltme tuttu) ama iki şey
kaldı.

### Müzik görselin ortasında başlıyordu

Script ses aygıtını (`/dev/snd/pcmC*D*p`) bekliyor; VirtualBox'ta ses
modülü kök dosya sistemi bağlandıktan sonra yükleniyor, yani aygıt geç
geliyor. İki taraflı düzeltildi:
- Ses modülleri initramfs'e alındı (`snd_hda_intel`, `snd_intel8x0`,
  `snd_ac97_codec`, `virtio_snd`) — aygıt çok daha erken hazır.
- Yoklama saniyede birden 0,2 saniyede bire çıkarıldı; eskisi aygıt
  hazır olduktan sonra ortalama yarım saniye daha bekletiyordu.

Ölçüm eklendi: `SOUND-DELAY` satırı müziğin splash'ten kaç saniye sonra
başladığını yazıyor, 3 saniyeyi geçerse uyarıyor. Ses servisinin kendi
günlüğü de (`BOOTSOUND-LOG`) aygıtı kaç saniye beklediğini bildiriyor —
gecikmenin kaynağı "servis geç başladı" mı "aygıt geç geldi" mi, ayırt
edilebiliyor.

### Splash → konsol → masaüstü sırası

Sıralama artık doğru çalışıyordu (müzik splash'i tutuyordu) ama düz
`plymouth quit` splash'i kapatıp sanal terminali bırakıyor; altında duran
çekirdek/systemd metni ortaya çıkıyor ve X başlayana kadar ekranda
kalıyor. Görülen konsol ekranı bu boşluk.

Çözüm `plymouth-quit.service` için `ExecStart=-/usr/bin/plymouth quit
--retain-splash`. Son kare framebuffer'da kalıyor, konsol metni yeniden
çizilmiyor, X doğrudan üstüne açılıyor.

**Tuzak:** drop-in aynı dosyadan hem `plymouth-quit.service.d/` hem
`plymouth-quit-wait.service.d/` altına kuruluyordu. `ExecStart`
değişikliği ikincisine de uygulanınca onun `plymouth --wait` komutunu
ezerdi. İki ayrı dosyaya bölündü; sıralama ikisinde de, ExecStart
yalnızca quit'te.

### VirtualBox vmwgfx hatası

VMSVGA denetleyicisiyle `vmwgfx` bağlanıyor ama çalışmıyor
("unsupported hypervisor"). KMS devre dışı kalırsa Plymouth metin
kipine düşer. `simpledrm` initramfs'te olduğu için UEFI framebuffer
üstünde yine bir DRM aygıtı kalıyor. `boot-check` artık her açılışta
`DRM-DEVICES` ve `SPLASH-RENDERER` satırlarını yazıyor, böylece hangi
çizicinin seçildiği kayda giriyor. VirtualBox tarafında Grafik
Denetleyici'yi `VBoxSVGA` yapmak hatayı tamamen kaldırıyor
(`vboxvideo` initramfs'te var).

---

## VirtualBox testi — açılış akışı bozuktu

Gerçek makinede (UEFI, ses etkin) görülen sıra: splash geldi (sessiz) →
söndü, konsol göründü → müzik ANCAK O ZAMAN başladı → splash ikinci kez
geldi → masaüstüne geçildi ama müzik çalmaya devam etti.

QEMU bunu yakalayamadı: ses arka ucu `none`, zamanlama farklı.

**Kök sebep: `After=sound.target`.** Servis, udev ses kartını bulup
`sound.target`'a ulaşılana kadar bekliyordu. Gerçek donanımda bu nokta
açılışın çok ilerisinde; servis splash'i tutamayacak kadar geç
başlıyordu. `plymouth-quit` çoktan koşmuş, splash sönmüş, konsol
görünmüş oluyordu.

**İkinci sebep: drop-in'deki `Wants=`.** `plymouth-quit.service` ses
servisini `Wants=` ile de çekiyordu. Servis erken başlayamayınca
plymouth-quit onu O ANDA başlatıyordu — müziğin splash'in sonunda
başlayıp masaüstüne taşmasının açıklaması bu.

Yapılanlar:

- Servis artık `After=systemd-udev-trigger.service plymouth-start.service`
  ile **erken** başlıyor; `Before=plymouth-quit.service
  plymouth-quit-wait.service` sıralaması unit'in kendisinde de yazılı
  (yalnızca drop-in'e güvenmiyoruz).
- **Ses aygıtını script bekliyor**, systemd değil: `/dev/snd/pcmC*D*p`
  belirene kadar en fazla 8 saniye. Başlama anı öngörülebilir oldu.
- Drop-in'den `Wants=` kaldırıldı. Ses servisi hiç başlamazsa `After=`
  etkisiz kalıyor ve splash normal zamanında kapanıyor: müziksiz ama
  düzgün açılış. Müziğin masaüstüne taşmasından iyi bir hata biçimi.

**Sıralama doğrulaması eklendi** (istenen kontrol): `boot-check` artık
systemd'nin monotonik zaman damgalarını okuyup
`plymouth-start ≤ ses başlangıcı ≤ ses bitişi ≤ plymouth-quit`
sırasını denetliyor, `SPLASH-TIMING` satırıyla dört değeri de yazıyor ve
`journalctl -b -u plymouth-start.service` üzerinden splash'in **kaç kez**
başlatıldığını sayıyor (`SPLASH-COUNT`). Birden fazlaysa arada konsola
düşülmüş demektir. Sıra bozuksa `RESULT=FAIL` ve ilgili unit'lerin
journal dökümü seri konsola yazılıyor.

### GRUB menüsü Karan OS markasına çevrildi

`9600-grub-marka.hook.binary`: menü girdisi adları ("Live system
(amd64)" → "Karan OS (amd64)"), turkuaz vurgulu renkler ve arka plan
olarak `karan-gece.png`. Debian logosu/arka planı kalıntıları siliniyor.

Bu hook **derlemeyi durdurmuyor** — 9500 (timeout) durduruyor çünkü o
olmadan ISO hiç açılmıyor; marka ise kozmetik. Bir dosya beklenen yerde
değilse uyarı yazıp devam ediyor ve ne bulduğunu günlüğe döküyor, ki
live-build yapısı değişirse bir sonraki koşuda görelim.

### Güç menüsü ve kompozitör

Başlat menüsündeki dört güç ikonu yan yana diziliydi ve hangisinin ne
olduğu ancak ipucu metniyle anlaşılıyordu. Yerine tek "Güç" düğmesi ve
üstünde açılan popup kondu: Kilitle, Uyku, Kapat, Yeniden başlat —
solda ikon, sağında metin, üzerine gelince satır vurgulanıyor.

**picom eklendi.** Yuvarlatılmış köşe ve gölge ancak bileşikleme varken
çiziliyor; kompozitörsüz Xvfb testinde kutunun etrafında **siyah bir
çerçeve** çıktı (şeffaf pay siyah çiziliyor). İki taraflı çözüldü:
picom autostart'tan başlıyor (`xrender` arka ucu — 3B gerektirmiyor,
RAM'i az) ve panel `Gdk.Screen.is_composited()` ile bileşikleme yoksa
kutuyu düz dikdörtgen çiziyor. Siyah çerçeve hiçbir durumda görünmüyor.

LibreOffice şartnamedeki setup program listesinde zaten var (bölüm 7 ve
bölüm 11 kategori listesi) — ek iş gerekmedi.

---

## Koşu #7 — masaüstü geldi, iki sorun kaldı

**Tuttu:** `USER-OK karan`, `WM-OK openbox calisiyor (10 saniyede)`,
`OSRELEASE-OK Karan OS 1.0`, `SPLASH-OK`, `BOOTSOUND-SERVICE=active`.
`screen-*-son.png` gerçek masaüstünü gösteriyor: duvar kağıdı ve turkuaz
vurgulu tema imleci. `user-setup` ve `os-release` düzeltmeleri doğrulandı.

### Sorun 1: Plymouth splash hiç çizilmiyordu

Ekranda açılış görseli yerine systemd yazıları akıyordu. `plymouth-start`
başlamıştı, `splash` çekirdek satırındaydı (`karanos-boot-sound.service`
`ConditionKernelCommandLine=splash` ile **active** oldu, yani kanıtlı).

İki sebep birleşiyor:

1. **`console=ttyS0` yüzünden Plymouth seri konsolu birincil sayıyor** ve
   grafik splash'i hiç çizmiyor. Seri konsolu bırakamayız — duman
   testinin tek çıktı kanalı o. Çözüm çekirdek satırına
   `plymouth.ignore-serial-consoles` eklemek.
2. **Splash DRM (KMS) aygıtına çiziliyor**; ekran sürücüsü initramfs'te
   yoksa Plymouth metin kipine düşüyor. initramfs-tools'un `most` listesi
   depolama sürücülerini alıyor, ekran sürücülerini garanti etmiyor.
   `/etc/initramfs-tools/modules` eklendi (bochs, qxl, virtio_gpu,
   vmwgfx, vboxvideo, simpledrm — sanal makine ekran kartları; gerçek
   donanımınkiler `most` içinde zaten var).

`0300-plymouth.hook.chroot` artık initramfs'te en az bir DRM sürücüsü
olduğunu da doğruluyor; yoksa derleme duruyor. Aynı disiplin: sessizce
bozuk bir ISO üretmektense derlemeyi durdur.

### Sorun 2: panel ISO'da başlamıyordu

Panelin çıktısı hiçbir yere yazılmıyordu; duman testi yalnızca
"çalışmıyor" diyebiliyordu. Üç şey yapıldı:

1. **En olası sebep zamanlama.** `boot-check` openbox'ı 60 saniye
   bekliyor ama paneli anında kontrol ediyordu. Panel Python + GTK
   yüklüyor, öykünmeli QEMU'da bu saniyeler sürüyor. Artık 45 saniye
   bekleniyor. (Pencere yöneticisinde daha önce düzeltilen hatanın
   aynısı — aynı hatayı ikinci kez yaptım.)
2. **Görünürlük.** Openbox autostart paneli günlüğe yazıyor ve üç kez
   deniyor; `boot-check` panel yoksa günlüğü, `dpkg-query` durumunu ve
   `import karanos_panel.panel` çıktısını seri konsola döküyor.
3. **Derleme anında içe aktarma denetimi.** `build-packages.yml` artık
   paketi açıp bütün modülleri içe aktarıyor ve metin tablosunun
   tutarlılığını kontrol ediyor. Bir sözdizimi hatası ya da eksik `gi`
   modülü artık 40 dakikalık ISO koşusunu değil, 10 saniyeyi harcıyor.
   Bu denetim yerelde çalıştırıldı: modüller temiz yükleniyor, yani
   çöküş bir içe aktarma hatası **değil** — zamanlama hipotezini
   güçlendiriyor.

---

## Tek tema kararı: yalnızca KOYU

Açık tema kaldırıldı — ne varsayılan olarak ne seçenek olarak. Sebep:
kimliğe uymuyor.

Nasıl uygulandı:
- `debian/rules` **aynı koyu dosyayı hem `gtk.css` hem `gtk-dark.css`
  olarak** kuruyor. Böylece `gtk-application-prefer-dark-theme`
  kapatılsa ya da bir uygulama açık temayı zorlasa bile görünüm
  değişmiyor. Tek bir ayara güvenmek yerine iki yoldan da kapatmak,
  "bir yerden açık tema sızdı" hatasını imkânsız kılıyor.
- `src/gtk-3.0/gtk.css` → `gtk-light.css` olarak yeniden adlandırıldı ve
  **pakete girmiyor**. Dosya silinmedi; ileride istenirse paletin açık
  karşılığı hazır dursun diye kaynak olarak saklanıyor.
- `appearance.theme` / `theme_light` / `theme_dark` anahtarları
  arayüz metinleri tablosunda üstü çizili işaretlendi. Satırları silmek
  yerine kayıt olarak bırakmak, ileride birinin "bu metinler nerede
  kaldı" sorusunu cevaplıyor.
- Ekran görüntüsü script'lerindeki `VARYANT=acik` seçeneği kaldırıldı.
- `tools/ornek-pencere.py` içindeki "Tema: Açık/Koyu" açılır listesi
  duvar kağıdı seçicisiyle değiştirildi — artık var olmayan bir ayarı
  gösteriyordu ve ekran görüntüsünde "sistem açık temada" izlenimi
  veriyordu.

**Bundan sonraki aşamalarda açık tema için ek iş yapılmaz.**

---

## Aşama 4 — karanos-panel (görev çubuğu + başlat menüsü)

Kapsam bölüm 17'nin 4. maddesi: **görev çubuğu ve başlat menüsü**.
Bölüm 8'deki masaüstü simgeleri, snap (Win+ok), Alt+Tab önizlemeleri ve
kısayol tuşları bu commit'te YOK — ayrı bir adımda yapılacak, durum.md
güncellenecek.

**Karar: pencere listesi için libwnck.** Openbox EWMH konuşuyor;
pencere listesini, sanal masaüstlerini ve "masaüstünü göster"i elle X
protokolüyle yazmak yerine libwnck kullanıyoruz. Zaten Debian'da ve
GTK3 ile aynı olay döngüsünde çalışıyor.

**Karar: uygulama listesi Gio.AppInfo'dan.** Kendi .desktop
ayrıştırıcımızı yazmıyoruz — Gio, NoDisplay/OnlyShowIn/TryExec ve dil
kurallarını zaten doğru uyguluyor.

**Karar: güç eylemleri logind üzerinden, sudo'suz.** logind, yerel
oturum sahibine kapatma/yeniden başlatma iznini polkit üzerinden zaten
veriyor. Böylece parola sorulmuyor ve panelin root yetkisi gerekmiyor.

**Karar: `_NET_WM_STRUT_PARTIAL` xprop ile yazılıyor.** Doğal yolu
`Gdk.property_change` olurdu ama PyGObject onu dışarı vermiyor
(introspection'da `skip`), çağırınca `AttributeError` geliyor. Kalan
seçenekler `python3-xlib` bağımlılığı eklemek ya da x11-utils'ten gelen
`xprop`u çağırmak; xprop zaten ISO'da olduğu için o seçildi. Bu özellik
olmazsa büyütülen pencereler panelin üstünü kaplıyor.

**Karar: dil seçimi tek yerde.** `metinler.py` hem tablo metinlerini
hem `turkce()` bayrağını veriyor; XDG kategori adları da onu kullanıyor.
İlk sürümde kategoriler her zaman Türkçe, düğmeler yerele göreydi —
ekran görüntüsünde "Start" ile "Geliştirme" yan yana çıkınca fark edildi.

**Karar: sistem tepsisi bu aşamada yok.** Bölüm 8 ağ/ses/pil simgelerini
tepside istiyor ama XEmbed/StatusNotifier tepsisi kendi başına bir iş.
Panelin sağ ucundaki göstergeler (klavye dili, pil, saat) doğrudan
sistemden okunuyor; gerçek tepsi 10. aşamadaki karanos-tools ile
gelecek.

**Geçici tema önizlemesi kaldırıldı.** 2. ve 3. aşamada ISO'ya giren
`/usr/lib/karanos/theme-preview` panel geldiği için silindi;
`tools/ornek-pencere.py` olarak geliştirme araçlarının arasına taşındı
(ekran görüntüsü script'leri onu açıyor).

**Doğrulama:** `tools/panel-screenshot.sh` paneli Xvfb + Openbox'ta
çalıştırıp PNG veriyor, `MENU=1` ile başlat menüsü açık hâlde. Bu turda
üç hatayı ISO derlemeden yakaladı: CSS bloğu Türkçe yorum içerdiği için
`bytes` literal olamıyordu, `Gdk.property_change` yoktu, dil seçimi iki
yerde ayrıydı. `boot-check` de artık `PANEL-OK` arıyor — panel
çalışmazsa duman testi düşüyor.

---

## Çalışma biçimi — CI tetiklenmiyor (AÇIK SORUN)

**Belirti:** `45431df` ve `c28a15e` push edildi, GitHub hiçbir iş akışı
koşusu üretmedi. Depo public, üç iş akışı da `active`, `paths` filtreleri
tutuyor. Toplam koşu sayısı `d143bb4`'te kaldı.

**Sebep (büyük olasılıkla):** Bu Codespace oturumunun `GITHUB_TOKEN`'ı
kısıtlı bir kurulum token'ı (`ghu_…`). `gh workflow run` denemesi
`403 Resource not accessible by integration` döndü; `actions/permissions`
uç noktası da 403. GitHub, kurulum token'ıyla yapılan push'lardan iş
akışı tetiklemiyor (özyinelemeli koşuları önlemek için). Daha önceki
push'lar tetikliyordu, yani token kapsamı oturumlar arasında değişmiş.

**Ne yapılmalı:** Actions sekmesinden **Run workflow** ile elle
başlatmak gerekiyor. Bu Codespace'ten tetiklenemiyor — kullanıcının
yapması lazım.

**Sonuç:** 2. ve 3. aşamaların CI doğrulaması **yapılamadı**. Elde
şunlar var:
- `karanos-theme` yerelde derlendi ve Xvfb'de çizildi (koyu ve açık
  varyant), görsel olarak doğrulandı
- `karanos-boot` yerelde derlendi, paket içeriği ve WAV süresi
  (6,14 sn) doğrulandı; splash'in kendisi yalnızca gerçek açılışta
  görülebiliyor
- `user-setup` düzeltmesi ve `os-release` hook'u **hiç çalıştırılmadı**

### Push tetikleyicileri daraltıldı

Codespace beklenmedik anda kapanabildiği için sık commit ediyoruz, ama
her commit 40 dakikalık derlemeyi hak etmiyor. `build-iso.yml` artık
yalnızca `iso/**`, `packages/**`, `assets/**` ve kendi dosyası
değişince koşuyor.

**Bunun bedeli:** `tools/qemu-smoke-test.sh` ya da
`tools/build-packages.sh` değiştiğinde derleme kendiliğinden koşmuyor.
O değişiklikleri denemek için Actions sekmesinden elle başlatmak
gerekiyor. Lint her push'ta koşmaya devam ediyor (20 saniye).
Belge/not commit'lerinin mesajına `[skip ci]` ekleniyor.

---

## Aşama 3 — karanos-boot (açılış ekranı)

**Karar: italik yazı PNG olarak gömüldü.** Bölüm 5'in notu iki seçenek
sunuyordu: hazır PNG ya da kendi framebuffer programımız. Plymouth
bitmap font kullanıyor ve italik gösteremiyor; kendi programımızı yazmak
Plymouth'u ikinci kez yazmak olurdu. `src/made-by-karan.svg` paket
derlenirken `rsvg-convert` ile PNG'ye çevriliyor — açılışta yazı tipi
bağımlılığı yok, sonuç her makinede birebir aynı.

**Karar: müzik WAV olarak gömülüyor, mp3 olarak değil.** Bölüm 5 "görsel
ve ses birlikte yumuşakça söner" diyor ama mp3 çalarların çoğunda
fade-out yok. `ffmpeg` paket derlenirken mp3'ü çözüp sonuna 0,4 saniyelik
fade ekliyor; açılışta `aplay` yetiyor, mp3 çözücü gerekmiyor. Bedeli
~1 MB ISO alanı (99 KB mp3 → 1,08 MB WAV); 1,5 GB hedefinde sorun değil.

**Karar: splash'i tutan mekanizma systemd sıralaması.**
`karanos-boot-sound.service` `Type=oneshot`; müzik bitene kadar
"başlıyor" sayılıyor. `plymouth-quit.service` ve
`plymouth-quit-wait.service` için konan drop-in'ler onu bekliyor. Böylece
sistem daha erken hazır olsa bile splash müzik bitene kadar duruyor —
bölüm 5 madde 4'ün istediği bu. Ses servisi başarısız olsa da sonlandığı
için açılış kilitlenmiyor; script kendi içinde 10 saniyede kesiyor
(madde 5'teki güvenlik ağı), servisin `TimeoutStartSec=20` değeri de
onun üstünde ikinci bir ağ.

**Karar: fade-out'u ses servisi tetikliyor.** Plymouth script'i müziğin
ne zaman bittiğini bilemez. Servis müzik bitince
`plymouth update --status=karanos-sonlaniyor` çağırıyor, tema script'i
bu durumu görünce sönmeyi başlatıyor. Görsel ile sesin birlikte sönmesi
böyle sağlanıyor.

**Karar: initramfs ayrı hook'ta üretiliyor.**
`plymouth-set-default-theme -R` tek adımda yapardı ama her paket
kurulumunda initramfs üretmek live-build chroot'unda derlemeye dakikalar
ekliyor. `postinst` yalnızca temayı seçiyor,
`0300-plymouth.hook.chroot` initramfs'i bir kez üretiyor **ve temanın
gerçekten içine girdiğini `lsinitramfs` ile doğruluyor**. Girmezse
derleme duruyor: aksi hâlde açılışta siyah ekran görünür ve sebebi ISO
açılmadan anlaşılmaz.

**Karar: görsel tek kopya.** Aslı tema dizininde, bölüm 5'in istediği
`/usr/share/karanos/boot/boot-image.png` ona giden bir bağ. Tersi
olsaydı tema dizini initramfs'e kopyalanırken bağ kırılırdı. 432 KB
tasarruf.

**Yan etki: `quiet splash` seri günlüğü kısıyor.** Duman testi
çekirdeğin başladığını "Linux version" satırından anlıyordu; `quiet` ile
o satır görünmüyor. Test artık daha geniş bir desene bakıyor
(`systemd[1]`, `Reached target`, `KARANOS-CHECK`). Bu tespit yalnızca
"önyükleyicide mi takıldık" sorusunu ayırmak için kullanılıyor.

**Splash nasıl görülüyor:** `plymouth-x11` Debian trixie'de yok, yani
açılış ekranı yerelde çizdirilemiyor. Duman testi çekirdek başladıktan
10 saniye sonra ayrı bir kare alıyor: `screen-<mod>-acilis.png`.
QEMU'ya ses kartı da eklendi (`intel-hda`, backend `none`) — ses hiçbir
yere gitmiyor ama `aplay` gerçek zamanda çalışıyor, böylece splash'in
müzik boyunca açık kalması da test ediliyor.

---

## Aşama 2 sonrası — renk kimliği değişimi ve iki gerçek hata

### Renk kimliği turuncu/sarıdan koyu turkuaz-maviye geçti

Yeni palet `CLAUDE.md` ve `docs/karanos-claude-code-prompt.md` bölüm 4'te.
Tek kaynak `packages/karanos-theme/`: CSS'lerdeki `@define-color` blokları
ve `tools/gen-*.py` başındaki sabitler.

**Karar: varsayılan tema koyu, açık tema ikinci seçenek.**
GTK'da bu, tema dizininde iki dosya tutmak demek — `gtk-dark.css` (koyu)
ve `gtk.css` (açık). Hangisinin yükleneceğini
`gtk-application-prefer-dark-theme` belirliyor ve
`/etc/gtk-3.0/settings.ini` içinde açık geliyor. Ayrı iki tema
(`Karan` / `Karan-Light`) yapmadım: tek tema + bir mantıksal anahtar,
8. aşamadaki "Tema: Açık / Koyu" seçiminin değiştireceği tek bir değer
bırakıyor.

**Karar: açık temada turkuaz ve mavi koyulaştırıldı** — `#2DD4BF` yerine
`#0D9488`, `#4F92F7` yerine `#2563EB`. Sebep kontrast: `#2DD4BF` beyaz
zeminde beyaz yazıyı taşıyamıyor (oran ~1.7). Marka degradesinin yönü ve
karakteri korundu, yalnızca değeri düştü.

**Karar: seçili/etkin öğelerde yazı rengi koyu.** Turkuaz açık bir renk;
üstüne beyaz yazı okunmuyor. Koyu temada seçili satırın yazısı
`#0D141B`. Aynı sebeple Openbox'ta etkin pencerenin başlık yazısı da koyu.

**Karar: "yasak" imleci kırmızı kaldı** (`#EF4444`). Turkuaz bir yasak
işareti işlevini anlatmıyor; tek renk istisnası bu.

**Karar: imleç dış çizgisi neredeyse siyah** (`#0D141B`). İmleç hem koyu
masaüstünde hem beyaz bir belgenin üstünde aynı netlikte görünmeli.

**Karar: duvar kağıdı adı `karan-koyu` → `karan-gece`.** Varsayılan tema
koyu olunca "koyu" ayırt edici bir ad olmaktan çıktı. Üçü de koyu:
`karan` (marka degradesi), `karan-gece` (en sakin), `karan-duz` (düz
zemin + logo).

### Hata 1: grafik oturum hiç açılmıyordu — `user-setup` eksikti

**Belirti:** CI 1. ve 2. aşamada yeşil yandı ama QEMU ekran görüntüsü
simsiyahtı. `boot-check` "WM-WARN openbox bulunamadi" yazıyor, buna
rağmen `RESULT=OK` veriyordu.

**Kök sebep:** `live-config`, canlı kullanıcıyı
`/usr/lib/user-setup/user-setup-apply` ile oluşturuyor ve bu dosya
`user-setup` paketinden geliyor. `live-config` onu yalnızca
**Recommends** ile istiyor. Biz `--apt-recommends false` ile derliyoruz,
dolayısıyla paket hiç kurulmadı, `karan` kullanıcısı hiç oluşmadı,
lightdm var olmayan bir kullanıcıya otomatik giriş yapmaya çalışıp boş
bir X kök penceresinde kaldı.

Bu, `CLAUDE.md`'de zaten yazan tuzağın (`libpam-systemd` örneği) ikinci
kez ısırması. `user-setup` artık `01-base.list.chroot` içinde, sebebiyle
birlikte.

**Nasıl bulundu:** ISO'yu Codespace'e indirip squashfs'i açtım,
`lightdm.conf`, `xsessions`, `openbox-session` — hepsi yerindeydi.
Sonra `live-config` paketini indirip `0030-user-setup` bileşenini
okudum; `user-setup-apply` çağrısını görünce paketin Recommends'te
olduğunu doğruladım. Tahminle üç CI koşusu harcamaktan ucuzdu.

**Denenip vazgeçilen:** canlı sisteme seri konsoldan girip
`/var/log/lightdm` okumak. Canlı kullanıcı hiç oluşmadığı için parola
da yoktu (`live-config` parolayı `live` yapıyor ama kullanıcı yaratılmamış).
`systemd.debug-shell` ile tty9'dan root kabuğu denemesi de yarıda kaldı.
Paket metaverisini okumak daha kısa yoldu.

### Hata 2: `/etc/os-release` devralınmıyordu

**Belirti:** ISO içindeki `/usr/lib/os-release` doğru ("Karan OS 1.0")
ama çalışan sistemde `/etc/os-release` "Debian GNU/Linux 13" diyordu.

**Kök sebep:** Debian'da `/etc/os-release`, `/usr/lib/os-release`'e giden
bir sembolik bağ. `karanos-theme` hedefi `dpkg-divert` ile devralıyor —
bu kısım çalıştı, derleme günlüğünde görünüyor. Ama **live-build**
derlemenin erken bir aşamasında `/etc/os-release`'i silip yerine
**gerçek bir dosya** yazıyor: Debian'ın o anki içeriği + `IMAGE_ID` ve
`BUILD_ID`. Bu iş bizim paketimiz kurulmadan önce olduğu için bağ
kopuyor ve eski içerik donuyor.

**Çözüm:** `iso/config/hooks/normal/9996-os-release.hook.chroot`.
Chroot hook'ları paketlerden sonra çalıştığı için burada
`/usr/lib/os-release`'i tekrar `/etc/os-release`'e yazıyoruz.
live-build'in eklediği `IMAGE_ID` / `BUILD_ID` satırları korunuyor —
onlar derlemenin kimliği, bizim üstümüze aldığımız bilgi değil.
Hook, dosya bizim sürümümüz değilse derlemeyi durduruyor.

### Duman testi artık yanlış yeşil veremiyor

İki kere yeşil yanıp aslında masaüstü açılmadığı için testin geçme
şartları sıkılaştırıldı:

- `boot-check` içinde ölümcül hata listesi var. Kullanıcı yok, pencere
  yöneticisi yok, tema eksik, imleç yok, duvar kağıdı yok ya da
  os-release yanlışsa `RESULT=FAIL`. Eskiden bunlar "uyarı"ydı.
- Pencere yöneticisi için 60 saniyelik bekleme eklendi — oturum X'ten
  birkaç saniye sonra açılıyor, anlık bakmak yanlış negatif veriyordu.
- `tools/screen-not-blank.py`: QEMU ekran görüntüsünün gerçekten bir şey
  gösterdiğini ölçüyor (renk çeşitliliği + parlaklık sapması). Boş ekran
  testi düşürüyor. `RESULT=OK` satırını görmek yetmiyor artık.
- Pencere yöneticisi yoksa `boot-check` lightdm günlüklerini, oturum
  dosyalarını ve süreç listesini seri konsola döküyor — bir sonraki
  arıza tek koşuda teşhis edilsin diye.

### Yerel doğrulama

`tools/theme-screenshot.sh` Xvfb + Openbox'ta temayı çizip PNG veriyor,
~10 saniye. `VARYANT=acik` ile açık tema. Bu turda üç hatayı ISO
derlemeden yakaladı: kaydırıcı dolgusu Adwaita mavisinde kalmıştı,
Openbox `label.bg` yazılmadığı için başlık çubuğunun ortasını siyaha
boyuyordu, önizleme penceresi sabit `sleep` yüzünden kareye
girmiyordu (artık pencere haritalanana kadar bekleniyor).

---

## Aşama 2 — karanos-theme

**Karar: sıfırdan GTK teması yazılmadı.** GTK'nın kendi Adwaita'sı
`@import` ile alınıp yalnızca renkler ve vurgu alan bileşenler eziliyor.
Sıfırdan tema binlerce satır ve her GTK güncellemesinde bozulan bir
bakım yükü; bu yöntemde yeni GTK sürümü gelince tema kendiliğinden
uyumlu kalıyor.

**Karar: depoda üretilmiş ikili dosya yok.** Simgeler, imleçler ve duvar
kağıtları `assets/logo/k-logo.svg` ve `tools/gen-*.py` üreteçlerinden
derleme sırasında çıkıyor. 16 imleç şekli × 4 boyut (ikisi 12 kareli
animasyon) = 400'den fazla PNG; bunları depoda tutmak her renk
değişikliğini megabaytlarca ikili fark yapardı.

**Karar: Openbox teması hook'la, dosya değiştirilerek değil.**
`rc.xml` yalnızca tema adını değil **bütün fare ve klavye kısayollarını**
taşıyor. Dosyayı kendi sürümümüzle değiştirseydik `<mouse>` bölümü
giderdi ve pencereler fareyle tutulamaz hâle gelirdi.
`0200-openbox-theme.hook.chroot` awk ile yalnızca `<theme>` bloğundaki
ilk `<name>` alanını değiştiriyor (sonraki `<name>`ler yazı tipi adları).

**Karar: `.deb`'ler ISO'ya `config/packages.chroot/` üzerinden giriyor.**
`build-packages.yml` paketleri üretiyor, `build-iso.yml` onu `uses:` ile
çağırıp yapıtı indiriyor. Böylece ISO'ya giren `.deb` ile test edilen
`.deb` aynı koşunun ürünü. Gerçek APT deposu 13. aşamada.

**Karar: tema önizleme penceresi geçici.** 2. aşamada tema var ama onu
gösterecek panel/masaüstü yok; boş ekranın görüntüsüne bakıp "tema
uygulanmış mı" denemez. `/usr/lib/karanos/theme-preview` yalnızca canlı
ortamda açılıyor (`/run/live/medium` varsa) ve 4. aşamada panel gelince
silinecek. Etiketleri `docs/karanos-arayuz-metinleri.md` içindeki
`appearance.*` anahtarlarından alındı — bu pencereye özel metin
uydurulmadı.

---

## Aşama 1 — çıplak ISO

**Tuzak: live-build `set timeout` yazmıyor.** GRUB'da timeout tanımsızsa
menü sonsuza kadar tuş bekler, ISO hiç açılmaz. Üç QEMU testi de 25
dakika zaman aşımına uğradı. `9500-grub-timeout.hook.binary` bunu
ekliyor; iş akışındaki "ISO içi önyükleyici doğrulaması" adımı ISO'nun
içinden `config.cfg`'yi çıkarıp satırın gerçekten orada olduğunu
doğruluyor.

**Tuzak: binary hook'lar `binary/` dizininin İÇİNDE çalışıyor**, derleme
kökünde değil. İlk sürüm yanlış dizinde arıyordu.

**Tuzak: `cmd | tee` tee'nin çıkış kodunu döndürüyor.** `iso/auto/build`
bu yüzden `#!/bin/bash` + `set -eo pipefail` kullanıyor; olmazsa
başarısız derleme CI'da yeşil görünüyor — bir kez görünmüştü de.

**Karar: `--apt-recommends false` yalnızca derleme için.**
`9990-apt-recommends.hook.chroot` kurulan sistemde Recommends'i geri
açıyor. Bunun bedeli: Recommends'ten gelen paketler (`libpam-systemd`,
`user-setup`) paket listelerinde açıkça yazılmak zorunda.
