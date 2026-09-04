# 4 Eylül 2026 — oturum sonu notu (v0.5-test1)

Kullanıcı aceleyle kapatmak zorunda kaldı; bu dosya "yarın devam"
dendiğinde okunacak kısa özet. Ayrıntı ve gerekçeler
`docs/durum.md`'nin başındaki 4 Eylül kaydında.

## Durum: bitti ve push'landı

- **Etiket `v0.5-test1`** atıldı ve push edildi. main = etiket.
- v0.4-test4 VM turunun **A–F maddelerinin hepsi** ve **Grup F'in kalan
  altı maddesi** (Ekran 10, Güç 51, Ağ 52, Donanım testi 50, Kilit
  ekranı 70, kavisfetch 71, selftest kapsamı 72) bitti.
- Toplam ~30 commit, her madde ayrı commit, mesajlar İngilizce.
- Türkçe çeviri **544/544 (%100)**.
- Bitmiş gruplardaki her madde için selftest senaryosu var: **34/34**;
  CI bu oranı düşürmeye izin vermiyor.

## Oturum kapanırken CI'da ne oluyordu

`v0.5-test1` etiketinin ISO derlemesi **hâlâ koşuyordu** (paket işi
yeşil geçmişti; ISO adımı yeni paketler yüzünden normalden uzun sürdü —
fonts-noto-core, breeze-cursor-theme, systemd-resolved, fastfetch,
smartmontools eklendi, önbellek de sıfırlandı).

**İlk iş:** koşunun sonucuna bak.

```
gh run list --limit 5
gh run view <id>                 # hangi iş kırmızı
gh run view <id> --log-failed    # neden
```

- Yeşilse: `kavis-iso` yapıtını indir, VirtualBox'ta dene.
- Kırmızıysa: QEMU işlerinin `diag-<mode>-<profile>` yapıtındaki seri
  günlüğe ve ekran görüntülerine bak; `KAVIS-CHECK:` satırları ve
  `SELFTEST` satırları neyin kaldığını tek tek yazıyor.

Bu turda etiket **üç kez taşındı** (hepsi paket derlemesi başlamadan
kırmızı olan koşulardı): eksik `libpam0g-dev`, `xvfb-run`'ın olmayan
`xauth`'u, ve `check-picom.sh`'ın gereksiz yere `curl` istemesi.
Üçü de düzeltildi ve **üçü de artık push öncesi yerelde yakalanıyor**
(`tools/check-config.sh` her paketin `Build-Depends`'inin iş akışında
kurulduğunu denetliyor).

## VM'de gözle bakılacaklar

Tam liste `docs/durum.md` → "VM'de doğrulanacaklar (v0.5-test1 turu)".
Kısaca: yazı netliği, köşeler, animasyon yumuşaklığı, snap önizlemesi,
başlık çubuklarının birbirine benzemesi, imleç, çoklu monitör, kapak/
boşta/düşük pil davranışı, gerçek Wi-Fi ve VPN, kilit ekranı gerçek
parolayla, `MEM-PROC` satırlarındaki bellek rakamları.

## Sıradaki iş

1. VM turunun sonuçları.
2. **Madde 74** — kısayol grupları + yeniden atanabilir Fn
   kombinasyonları, Ayarlar'da hiyerarşik alt bölümler, gerçek ayar
   araması ("light" yazınca tema ayarları da çıksın).
   Tam metin: `docs/sonraki-tur.md` 4. bölüm.
3. **Selftest kayıt modu** — madde 72'nin kalan tek parçası.
4. **RAM temizliği 2/5/6** — VM'deki `MEM-PROC` satırlarından.
5. Sonra **Grup G** (mağaza + arama). Madde 75 "App Files" kararı
   `docs/kararlar.md` 10'da hazır bekliyor.

## Bu turda eklenen denetimler (push öncesi çalıştır)

```
tools/check-config.sh          # + Build-Depends CI'da kurulu mu, host koruması
tools/check-packages.sh
tools/check-i18n.sh            # + çevirilerin printf argümanları
tools/check-visual.sh          # yazı, DPI, başlık çubuğu eşleşmesi, köşe yarıçapı
tools/check-picom.sh           # yapılandırma gerçek picom 12.5'te açılıyor mu
tools/check-snap.sh            # ve SNAP_PICOM=auto ile ikinci tur
kavis-selftest --check --scenarios tests/ui
```
