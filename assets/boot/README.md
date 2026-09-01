# assets/boot/ — açılış ekranı dosyaları

Buraya **iki dosya** koyacaksın. Adlar birebir bu olmalı:

```
assets/boot/boot-image.png     ← açılış görseli
assets/boot/boot-sound.mp3     ← açılış müziği
```

Bu iki dosya `kavis-boot` paketine gömülür ve kurulu sistemde
`/usr/share/kavis/boot/` altında, `root:root 0644` izniyle durur.
Kullanıcı bunları **değiştiremez** (prompt 5. bölüm) — ne setup'ta ne ayarlarda
bir seçenek olacak.

---

## 1. `boot-image.png` — açılış görseli

| Konu | Değer |
|---|---|
| Biçim | PNG (PNG-24 veya PNG-32) |
| Önerilen boyut | **512 – 1024 piksel** uzun kenar |
| En-boy oranı | Serbest — tema oranı korur. Aşırı yatay/dikey olmasın (1:2 – 2:1 arası). |
| Arka plan | **Şeffaf** (alfa kanallı) |
| Renk uzayı | sRGB, 8 bit/kanal |
| Dosya boyutu | 500 KB altı (ideal: 150 KB altı) |
| Kenar boşluğu | Görselin kenarlarında ~%8 boşluk bırak |

> **Şu anki dosya:** 735 × 820, RGBA (alfa var), 422 KB — uygun. ✅

**Neden şeffaf arka plan:** açılış ekranının arka planı düz koyu renk
(`#1A1A1A`) olacak ve görsel %15 opaklıktan %100'e çıkarken üzerine bir parlama
(glow) uygulanacak. Beyaz veya siyah dolu bir arka plan varsa parlama efekti
kare bir kutu gibi görünür ve kötü durur.

**Neden kare:** Plymouth teması görseli ekran ortasında, ekran yüksekliğinin
%30'u olacak şekilde ölçekliyor. Kare olmayan görsel farklı çözünürlüklerde
farklı görünür.

**Kenar boşluğu neden önemli:** parlama efekti görselin dışına doğru taşıyor.
Görsel PNG'nin tam kenarına dayanırsa parlama kırpılır.

> İpucu: elinde tek yüksek çözünürlüklü görsel varsa 512×512'ye küçültmene
> gerek yok, 1024×1024 koy — derleme sırasında gereken boyutlara biz düşürürüz.

---

## 2. `boot-sound.mp3` — açılış müziği

| Konu | Değer |
|---|---|
| Biçim | MP3 (MPEG-1 Layer III) |
| Önerilen süre | **4 – 8 saniye** |
| Üst sınır | 15 saniye (aşağıdaki uyarıyı oku) |
| Bit hızı | 128 kbps CBR (192 kbps'e kadar sorun değil) |
| Örnekleme | 44.1 kHz |
| Kanal | Stereo veya mono |
| Dosya boyutu | 250 KB altı |

### ⚠️ Süre neden önemli

Prompt 5. bölüm: **açılış ekranı müzik bitene kadar kapanmıyor.** Sistem 6
saniyede hazır olsa bile 20 saniyelik müzik koyarsan bilgisayar her açılışta 20
saniye açılış ekranında bekler. Müzik ne kadar uzunsa açılış o kadar uzun
hissettirir.

Ayrıca: sistem müzikten uzun sürerse müzik **bir kez** çalıp susar, döngüye
alınmaz — yani sessiz bir bekleme olur. 4–8 saniye bu iki durumun arasındaki
en dengeli aralık.

### Ses seviyesi

- Tepe seviyesini **-1 dBFS**'e normalize et (kırpma/clipping olmasın)
- **Başta sessizlik bırakma** — dosyanın ilk karesi sesin başlangıcı olsun.
  Baştaki 2 saniyelik sessizlik açılışı 2 saniye uzatır.
- Sonda kısa bir doğal iniş (fade-out) iyi olur; splash zaten kapanmadan önce
  kendi kısa fade-out'unu uygular, ikisi üst üste binerse yumuşak durur.

Kontrol/düzeltme komutu (ffmpeg kuruluysa):

```bash
# süre, bit hızı, kanal bilgisi
ffprobe -hide_banner assets/boot/boot-sound.mp3

# normalize + baştaki sessizliği kırp + 128 kbps'e getir
ffmpeg -i kaynak.mp3 -af "silenceremove=start_periods=1:start_threshold=-50dB,loudnorm" \
       -codec:a libmp3lame -b:a 128k -ar 44100 assets/boot/boot-sound.mp3
```

### Neden MP3, WAV değil

Açılışın çok erken bir anında, `kavis-boot-sound.service` adlı küçük bir
systemd servisi sesi `mpg123` ile çalacak (Plymouth'un kendi ses desteği yok).
`mpg123` ~1 MB'lık, bağımlılığı az bir araç; MP3'ü doğrudan ALSA'ya veriyor.
WAV kullanmak dosyayı 10 kat büyütür, ISO'ya bedava yer kaybettirir.

---

## Dosyaları koyduktan sonra

```bash
git add assets/boot/boot-image.png assets/boot/boot-sound.mp3
git commit -m "açılış görseli ve müziği eklendi"
git push
```

Doğrulama script'i (3. aşamada yazılacak) şunu kontrol edecek:
dosyalar var mı, PNG kare ve alfa kanallı mı, MP3 15 saniyeden kısa mı.
