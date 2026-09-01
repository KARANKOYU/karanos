# picom — referans incelemesi

İlgili Kavis maddeleri: 2 (compositor), 4/38 (yuvarlak köşe, blur, animasyon),
13 (oyun modu ile ilişkisi). İnceleme tarihi: 2026-09-01, depo HEAD'i
`6d67682` (2026-06-02, v13-rc1 sonrası geliştirme dalı).

Kaynak: `/tmp/referans/picom` (sığ klon, `--depth 1`). Kural gereği bu
belgeye kod kopyalanmadı; yalnızca yaklaşım ve yapılandırma anahtarları
anlatılıyor.

## Kimlik

- X11 için bağımsız compositor; compton'un devamı, o da xcompmgr soyundan.
  C ile yazılmış, MPL-2.0/MIT karışık lisans.
- Arka uçlar: `xrender` (XRender uzantısı, GPU şart değil), `glx` (OpenGL),
  `egl`. v12'den itibaren hepsi aynı yeni backend API'sini kullanıyor;
  eski "legacy" arka uçlar v13'te tamamen kaldırılıyor (`--legacy-backends`
  artık işlevsiz).
- Kavis'te zaten kullanılıyor: `iso/config/includes.chroot/etc/xdg/picom-kavis.conf`
  — xrender + yalnız gölge, vsync kapalı.

## Sürümler: kaynak vs Debian trixie

| Kaynak | Sürüm |
|---|---|
| Klonlanan depo HEAD'i | v13 geliştirme dalı (meson `version: '13'`, v13-rc1 sonrası) |
| Debian trixie arşivi | **12.5-1** (deb.debian.org trixie main indeksinden doğrulandı) |
| Codespace konteyneri | 10.2 (Ubuntu paketi; ISO'yla ilgisiz, ölçü alma) |

Trixie'nin 12.5'i v12 ailesinden: **animasyonlar, `rules` (evrensel pencere
kuralları), `picom-inspect`, corner-radius, blur — hepsi VAR.** v13'e özgü
olanlar (kural içinde pencere başına `shadow-color`, `blur-opacity`, `color`
animasyon tetikleyicisi, `size`/`position` ayrık tetikleyicileri) trixie'de
YOK.

v12 ile gelen önemli davranış değişikliği: **`backend` artık zorunlu** —
yazılmazsa picom hiç başlamıyor. `picom-kavis.conf` zaten yazıyor, sorun yok.

## Özellik matrisi

| Özellik | xrender'da | glx'te | trixie 12.5'te | VM'de (yazılım GL) güvenli mi |
|---|---|---|---|---|
| Gölge (`shadow`) | Var | Var | Var | Evet (12.4'te xrender gölge performansı düzeltildi) |
| Yuvarlak köşe (`corner-radius`) | **Var** — kaynak: `src/backend/xrender/xrender.c` içinde yuvarlak köşe maskesi önbelleği; v11'de "xrender'da köşeler siyah çıkıyor" hatası (#1003) düzeltildi | Var | Var (`corner-radius`, `rounded-corners-exclude`, `corner-radius-rules`) | Evet, xrender'da GPU gerekmez |
| Blur — `dual_kawase` | **YOK** — kaynak açıkça "not compatible with the 'xrender' backend" uyarısı verip blur'u kapatıyor | Var (verimli olan bu) | Var | Riskli: llvmpipe'ta çalışır ama CPU yakar |
| Blur — `gaussian`/`box`/`kernel` | Var, XRender konvolüsyon filtresiyle; man sayfası kendisi "bad in performance" diyor, kalitesi de dual_kawase'den düşük | Var | Var | Hayır — QEMU'da konvolüsyon tamamen CPU'da, 2 çekirdekte felç eder |
| Animasyonlar (`animations`) | Var (backend'den bağımsız betik sistemi; boyut animasyonu xrender'da ölçekleme gerektirdiğinden daha pahalı) | Var | **Var** (v12'de geldi) | Evet, açılış/kapanış fade-ölçek animasyonları xrender'da makul |
| `rules` evrensel kurallar | Var | Var | Var (v12) | Evet |
| `unredir-if-possible` | Var | Var | Var | Evet |
| Kural içinde `shadow-color`, `blur-opacity` | — | — | YOK (v13) | — |

VM notu: v12 glx arka ucu OpenGL 4.3 özellikleri kullanıyor; llvmpipe 4.5
desteklediği için QEMU'da *çalışır* ama yazılım rasterizasyonla her kare
CPU'ya biner. Ayrıca "glx ile siyah ekran" en çok yorum alan açık
issue'lardan (aşağıda). Kavis QEMU duman testlerinin geçmesi gerektiğinden
**glx asla koşulsuz varsayılan yapılmamalı.**

### Animasyon tanımı (v12 sözdizimi, trixie'de geçerli)

Hazır "preset"ler işi kısaltıyor; süre saniye cinsinden, 150–200 ms hedefi
için 0.15–0.2:

```
animations = (
  { triggers = [ "open", "show" ];  preset = "appear";    scale = 0.95; duration = 0.15; },
  { triggers = [ "close", "hide" ]; preset = "disappear"; scale = 0.95; duration = 0.15; }
);
```

Presetler: `slide-in/out`, `fly-in/out`, `appear/disappear` (ölçek+fade),
`geometry-change` (deneysel). `geometry` tetikleyicisi deneysel ve fareyle
pencere taşırken de tetiklenir — Kavis'te geçiş animasyonu isteniyorsa
yalnız aç/kapa/gizle tetikleyicileriyle sınırlı tutmak güvenli olan.

## Çalışırken yeniden yükleme (Ayarlar entegrasyonu)

- **`SIGUSR1` = tam yeniden başlatma + yapılandırmayı yeniden okuma.**
  Kaynakta doğrulandı: sinyal ana döngüyü kırıyor, `main()` içindeki `do`
  döngüsü oturumu yeniden kuruyor ve `session_init` → `parse_config`
  yapılandırma dosyasını baştan okuyor. Yani Ayarlar için akış basit:
  dosyayı yaz → picom sürecine SIGUSR1 gönder. Ekranda kısa bir "yeniden
  yönlendirme" titremesi olur (tam reinit), ama ayar değiştirme sıklığında
  kabul edilebilir.
- **D-Bus (`--dbus`) bu iş için YETERSİZ:** `opts_set` yalnızca birkaç
  seçeneği tanıyor (fade parametreleri, `unredir_if_possible`,
  `stoppaint_force`) — corner-radius, blur, animasyon D-Bus'tan
  değiştirilemiyor. Man sayfası da API'yi "not yet stable, undocumented"
  diye işaretliyor. Kalıcılık zaten dosya gerektirdiğinden dosya+SIGUSR1
  hem daha basit hem geleceğe dayanıklı.
- inotify ile kendi kendine izleme YOK; tetiklemeyi Ayarlar yapmalı.
- `picom-inspect` (trixie'de var): kural/dışlama koşullarını canlı test
  etmek için — geliştirme sırasında işe yarar.

## Tuzaklar (tekrar eden issue şikâyetleri)

En çok yorum alan açık issue'lardan (gh api, yoruma göre sıralı; bir kısmı
compton döneminden kalma ama şikâyet kalıpları hâlâ geçerli):

- **Titreme/karartma:** "ekran koruyucu sonrası duvar kağıdı titriyor" (64
  yorum), "glx arka ucunda varsayılan ayarlarla siyah ekran" (53), "çalışma
  alanı değişince duvar kağıdı titriyor" (33). glx'in siyah ekranı sürücüye
  çok bağımlı — xrender'ı varsayılan tutma gerekçesi.
- **xrender gölge performansı/artefaktları** (43): 12.4'te büyük ölçüde
  düzeltildi (konvolüsyondan kaçınma) ama zayıf makinede gölgeyi popup'larla
  sınırlı tutmak — Kavis'in şu anki yaklaşımı — hâlâ doğru.
- **v10 sonrası genel performans düşüşü** (19) ve "Intel kartta lag" (31):
  eski/zayıf donanımda compositor maliyeti gerçek; Kavis'in 1 GB RAM hedefi
  için ayarları asgaride tutma gerekçesi.
- **Unredirect kaynaklı titreme:** man sayfası `--unredir-if-possible`
  için "yönlendirme değişiminde titremeye yol açtığı biliniyor" diyor;
  "unredirect edilen pencere xf86-video-intel tearfree'yi bozuyor" (12).
- **"Gölge üstüne gölge" / tam ekranda çoklu gölge** (13): WM çerçevesi +
  istemci penceresi ayrı gölge alınca oluyor; çare gölgeyi dışlamalarla dar
  tutmak ve panel gibi yüzeyler için `clip-shadow-above`.
- **Tearing:** vsync kapalıyken xrender'da yırtılma şikâyetleri klasik;
  vsync açmak gecikme/CPU maliyeti getirir. VM'de görüntü zaten senkron
  olmadığından Kavis'te `vsync = false` kalması makul, gerçek donanımda
  şikâyet gelirse açılacak ilk ayar bu.
- **Blur'un pencere dışından örneklemesi** (15): blur kenar artefaktları
  bilinen bir sorun alanı.

## Kavis için çıkarımlar

1. **Madde 2 (sağlamlaştırma):** `picom-kavis.conf` xrender + yalnız gölge
   temelinde kalmalı; `backend` satırı zorunlu olduğundan silinmemeli.
   `unredir-if-possible` şimdiden açılabilir: VM'de ve oyunlarda (madde 13)
   tam ekran pencere compositor'ü bedavaya atlar; `_NET_WM_BYPASS_COMPOSITOR`
   isteyen oyunlar da otomatik yakalanır. Oyun modunun ayrıca picom'u
   öldürmesi gerekmez. Titreme şikâyeti gelirse `unredir-if-possible-delay`
   ile yumuşatılır.
2. **Yuvarlak köşe (madde 4) hemen açılabilir:** xrender'da çalışıyor,
   GPU istemiyor, trixie 12.5'te var. `corner-radius` (ör. 8) +
   `rounded-corners-exclude` ile panel/dock/tam ekran dışlanır (eski tarz
   dışlama listesi kullanılırsa tam ekran zaten varsayılan dışlanıyor;
   `rules`'a geçilirse dışlamayı açıkça yazmak gerekir — v12 davranış
   değişikliği).
3. **Animasyon (madde 4/38) xrender'da kalarak eklenebilir:** yalnız
   `open/close/show/hide` tetikleyicileri, `appear`/`disappear` preset'i,
   `duration` 0.15–0.2. `geometry` tetikleyicisinden uzak dur (deneysel,
   sürüklemede de tetikleniyor).
4. **Blur'u koşula bağla:** dual_kawase yalnız glx'te; glx yalnız gerçek
   GPU'da güvenli. Yaklaşım: Ayarlar'da blur seçeneği "kapalı" varsayılan;
   açılırsa yapılandırma `backend = "glx"` + `blur-method = "dual_kawase"`
   olarak yazılır. Oturum açılışında yazılım GL tespit edilirse (ör.
   `glxinfo` çıktısında llvmpipe) blur seçeneği devre dışı bırakılıp
   xrender'a düşülür. xrender konvolüsyon blur'una hiç girme — hem yavaş
   hem çirkin. CI duman testi her koşulda xrender yolunu görür.
5. **Madde 38 (Ayarlar'dan değiştirme):** tek doğru mekanizma —
   Ayarlar `picom-kavis.conf`'u (ya da kullanıcı katmanı bir dosyayı)
   yeniden yazar, sonra picom sürecine `SIGUSR1` gönderir. D-Bus API'sine
   yatırım yapma; kararsız ve corner-radius/blur/animasyonu zaten
   kapsamıyor.
6. **RAM/CPU bütçesi:** xrender + gölge + yuvarlak köşe + kısa aç/kapa
   animasyonu 1 GB hedefini tehdit etmez; asıl maliyet blur ve
   `--no-use-damage`/`max-brightness` gibi tüm ekranı yeniden çizdiren
   ayarlarda. Damage takibi (varsayılan) açık kalmalı.
