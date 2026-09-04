# DEVİR NOTU — 4 Eylül 2026 akşamı

Yeni sohbet bu dosyayı okuyarak başlar. Kaldığı yer, ne bozuk, ne
yapılacak — hepsi burada. Gerekçeler `docs/durum.md`'nin başındaki
4 Eylül kaydında.

---

## 1. Nerede kaldık

- **Etiket `v0.5-test1` atıldı ve push'landı.** v0.4-test4 VM turunun
  A–F maddeleri + Grup F'in kalan altı maddesi (Ekran 10, Güç 51,
  Ağ 52, Donanım testi 50, Kilit ekranı 70, kavisfetch 71, selftest
  kapsamı 72) bitti. ~35 commit, hepsi push'lu.
- Türkçe çeviri **544/544 (%100)**.
- Bitmiş gruplardaki her madde için selftest senaryosu: **34/34**.

## 2. CI DURUMU: KIRMIZI — ilk iş bu

Koşu: <https://github.com/KARANKOYU/karanos/actions/runs/33881670790>

| İş | Sonuç |
|---|---|
| Paketler (.deb) | ✅ 4m27s — yeni denetimlerin hepsi geçti |
| ISO derlemesi | ✅ 9m17s — **956 MB** (sınır 1900, uyarı 1700) |
| QEMU (5 profil) | ❌ hepsi — selftest adımları kaldı |

ISO **üretildi ve sağlam**; kırmızı olan **selftest senaryolarının
kendisi**. Yani ISO'yu indirip VM'de denemek mümkün, ama önce aşağıdaki
listeyi kapat.

### 2a. Kök sebep (düzeltildi, commit edilmemiş olabilir — kontrol et)

`close window nemo` **nemo-desktop'ı da kapatmaya çalışıyordu**:
`clients_of("nemo")` WM_CLASS'ında nemo geçen HER pencereyi buluyor,
masaüstü katmanı da öyle. Masaüstü kapanma isteğine cevap vermiyor,
sonra kaçış yolu SIGTERM gönderiyor ve **masaüstünü oturumdan
düşürüyordu** — ondan sonraki her senaryo bozuk bir oturumda koştu.
Muhtemelen 3, 4, 6 numaralı hataların hepsi bunun devamı.

Düzeltme: `packages/kavis-selftest/src/xwin.vala` içinde
`is_furniture()` — `_NET_WM_WINDOW_TYPE` DESKTOP/DOCK olanlar atlanıyor.
**`git status` ile commit edilmiş mi bak**; edilmemişse derle, denetle,
commit et.

### 2b. Kalan hatalar, öncelik sırasıyla

1. **Zaman aşımları (kesin hata).** `06-shortcuts` içinde
   `ctrl+shift+Escape` → Görev Yöneticisi ve `super+i` → Ayarlar 6
   saniyede açılmadı. TCG'de soğuk bir GTK uygulaması 6 sn'ye sığmıyor.
   `tools/gen-keybind-scenario.py` içindeki `timeout: 6000`, pencere
   açan kısayollar için **40000** olmalı (popup'lar 6000 kalabilir).
   Değiştirince `tools/gen-keybind-scenario.py` çalıştır.
2. **Mikrofon FAIL olmamalı.** QEMU'da ses kartı yok; `arecord`
   sessizlik kaydediyor ve `microphone FAIL` diyor. Kayıt aygıtı
   yoksa **SKIP** olmalı: `hwtest.vala` → `microphone()` içinde
   `arecord -l` boşsa ya da tepe TAM sıfırsa SKIP.
3. **`52-network/2`** — `nmcli` ethernet göremiyor (QEMU'nun NIC'i
   NetworkManager'ın yönetiminde değil). Senaryo `nmcli device`
   çıktısının BOŞ OLMAMASINI istesin, `ethernet` aramasın.
4. **`52-network/4`** — `set-dns` kullanıcı olarak koşunca
   `mkdir /etc/systemd/resolved.conf.d` izin hatası veriyor (doğru
   davranış). Senaryo koruma geçsin diye çalıştırıyor; beklenti
   "rc=0" değil **"exit 3 DEĞİL"** olmalı — yani guard'ın reddetmediği.
   En temizi: `/usr/lib/kavis/set-dns` var mı + guard satırları var mı
   diye bakmak, çalıştırmamak.
5. **`29-capture/2`** — Escape yakalama çubuğunu kapatmıyor
   (`popup count 1`). Gerçek hata olabilir; `kavis-tools capture`
   Escape'i ele alıyor mu bak.
6. **Popup'lar açılmıyor** — `37-panels`, `55-desktops`,
   `60-popup-dismiss` adımlarında `popup count 0`. Önce 2a'yı düzeltip
   yeniden koş; büyük ihtimalle masaüstü düşmesinin devamı. Değilse
   `click taskbar clock/start` koordinatları dikey/yatay panelde
   doğru mu bak.
7. **`06-window-snap`** — pencere hiç kımıldamamış (`frame 478,159`
   sabit). Yine 2a'nın devamı olabilir; ayrıca yerelde
   `KAVIS_ROOT=… tools/check-snap.sh` **geçiyor**, yani snap kodu
   sağlam.

### 2c. Etiketten SONRA main'e giren düzeltmeler (koşuda yoktu)

- `40-editors` tırnak hatası (`'! xdotool …'` → `test -z "$(…)"`).
- i18n printf argüman sırası + `tools/check-format-strings.py`.
- Ayarlar'da var olmayan bölüm ikonu.
- Gece ışığı: xsct yoksa dakikada bir uyarı basmıyor.

Yani **etiketi düzeltmelerden sonra yeniden taşımak gerekiyor**
(`git tag -f -a v0.5-test1 … HEAD && git push --force origin v0.5-test1`).

## 3. VM turundan gelen ÖLÇÜMLER (yeni)

Bu turda eklenen denetimler çalıştı ve ilk gerçek sayıları verdi:

```
CURSOR-OK Breeze_Light 115 names, Kavis-Cursors 105
FETCH-OK  Kavis 1.0 x86_64 (logo 9 lines)     ← kavisfetch os-release'i okuyor
DESKTOP-READY panel ve masaüstü 13 saniyede
MEM-USED=552MB                                 ← hedef 380 MB
```

**Boşta bellek dökümü (USS / RSS, MB):**

| Süreç | USS | RSS |
|---|---|---|
| Xorg | 62 | 111 |
| nemo-desktop | 45 | 75 |
| kavis-panel | 35 | 66 |
| lxpolkit | 12 | 68 |
| kavis-osd | 4 | 20 |
| kavis-snap | 4 | 20 |
| picom | 1 | 6 |
| lightdm (2 süreç) | 1 | 15 |

Bunlar **RAM temizliği maddesi 2'nin cevabı**:

- **lxpolkit 12 MB USS** — 15 MB eşiğinin altında, **değiştirmeye gerek
  yok** (RSS 68 aldatıcı, paylaşılan GTK sayfaları).
- **nemo-desktop 45 MB USS** — 30 MB eşiğinin üstünde. Küçültmenin tek
  yolu masaüstü ikonlarını kendimiz çizmek; ayrı madde olarak açılmalı.
- **kavis-osd 4 MB USS** — tembel pencere işe yaradı (Xvfb'de 15'ti,
  VM'de 4). "Kapalıyken bellek tutmasın" isteği karşılandı.
- **kavis-panel 35 MB USS** — 20 MB bütçesinin ÜSTÜNDE. Ama
  `PANEL-USS=1MB` loglanmış: **ölçüm panel ikonlarını yüklemeden önce
  yapılıyor**, yani boot-check'teki PANEL-USS ölçümü çok erken.
  Düzeltilecek: ölçümü DESKTOP-READY'den sonra al.
- Toplam 552 MB, hedef 380. Xorg + nemo-desktop + panel üçü 142 MB;
  gerisi çekirdek, systemd ve squashfs önbelleği (canlı oturum).

## 4. Sıradaki iş (sırayla)

1. **2a/2b listesini kapat**, etiketi taşı, koşu yeşile dönsün.
2. **ISO'yu VM'de dene** — gözle bakılacaklar listesi `docs/durum.md`
   → "VM'de doğrulanacaklar (v0.5-test1 turu)".
3. **Madde 74** — kısayol grupları + yeniden atanabilir Fn
   kombinasyonları, Ayarlar'da hiyerarşik alt bölümler, gerçek ayar
   araması. Tam metin `docs/sonraki-tur.md` 4. bölüm.
4. **Selftest kayıt modu** — madde 72'nin kalan tek parçası.
5. **RAM maddeleri** — yukarıdaki tablodan: nemo-desktop, PANEL-USS
   ölçüm anı, boşta 380 MB hedefi.
6. **Grup G** — mağaza + arama. Madde 75 "App Files" kararı
   `docs/kararlar.md` 10'da hazır.

## 5. Push öncesi denetimler (hepsi yerelde geçmeli)

```bash
tools/check-config.sh          # sözdizimi, host koruması, Build-Depends CI'da kurulu mu
tools/check-packages.sh        # paket adları trixie arşivinde var mı
tools/check-i18n.sh            # çeviri + printf argümanları
tools/check-visual.sh          # yazı, DPI, başlık çubuğu eşleşmesi, köşe yarıçapı
tools/check-picom.sh           # yapılandırma gerçek picom 12.5'te açılıyor mu
tools/check-keybinds.sh /etc/xdg/openbox/rc.xml
tools/gen-test-coverage.py --check
tools/gen-keybind-scenario.py --check

# snap iki turda (compositor'süz ve compositor'lü):
mkdir -p /tmp/kr && dpkg-deb -x out/packages/kavis-panel_*.deb /tmp/kr \
  && dpkg-deb -x out/packages/kavis-theme_*.deb /tmp/kr
KAVIS_ROOT=/tmp/kr DISPLAY_NO=96 tools/check-snap.sh
KAVIS_ROOT=/tmp/kr DISPLAY_NO=95 SNAP_PICOM=auto tools/check-snap.sh

# senaryolar ayrıştırılıyor mu (ekran gerekmez):
dpkg-deb -x out/packages/kavis-selftest_*.deb /tmp/ks \
  && /tmp/ks/usr/bin/kavis-selftest --check --scenarios tests/ui
```

Xvfb ile gözle bakmak için: `tools/theme-screenshot.sh`,
`CSD=1 tools/theme-screenshot.sh` (başlık çubuğu karşılaştırması),
`tools/panel-screenshot.sh`.

## 6. Hatırlatmalar

- Commit mesajları İngilizce, `Co-Authored-By` YOK, etiket konacak
  commit'te `[skip ci]` YOK.
- Host'ta sistem/kullanıcı değiştiren komut yok (CLAUDE.md).
- Yeni bağımlılık → paketin `Depends`/`Build-Depends` alanına **ve**
  iş akışının kurulum adımına. Artık `check-config.sh` bunu denetliyor
  (bu turda üç koşu bu yüzden kırmızı yandı).
