# Grup B — sorun önleme taraması (madde 59)

Tarih: 2026-09-01. Grup B'nin konularına dokunan GitHub projeleri
tarandı (en çok yorumlanan issue'lar, `gh api`). picom zaten A2'de
derinlemesine incelenmişti — `picom.md`'nin "Tuzaklar" bölümü Grup B'nin
picom kararlarını belirledi (xrender'da kal, blur'u GPU şartına bağla,
glx'i varsayılan yapma). Plymouth (freedesktop GitLab) ve live-build
(Debian Salsa) GitHub'da olmadığı için taranamadı.

## earlyoom (madde 8)

En çok yorumlanan issue'lardan tekrar eden temalar:

- **"Yanlış süreci öldürüyor"** (oom_score_adj yüzünden, açık): earlyoom
  varsayılan hâliyle X sunucusunu/oturum sürecini de öldürebiliyor →
  kullanıcı siyah ekranda kalıyor. ÖNLEM: `/etc/default/earlyoom`'da
  `--avoid` ile oturum-kritik süreçler (systemd, Xorg, lightdm, openbox,
  picom, kavis-panel, dbus) korundu; obur ama zararsız kurbanlar
  (tarayıcı süreçleri) `--prefer` ile öne alındı.
- **Bildirim sorunları** (notify-send root'tan çalışmıyor, KDE
  geçmişine düşmüyor): `-n` bildirimi kırılgan. ÖNLEM: bildirim bayrağı
  KULLANILMADI; kullanıcıya bildirim madde 37'nin sistem geneli
  bildirim altyapısı gelince oradan bağlanacak.
- **CPU kullanımı** (eski sürümlerde agresif yoklama): trixie'deki
  sürümde uyarlanabilir; ek önlem gerekmedi, `-r 3600` ile günlük de
  sakin tutuldu.
- **hidepid=2 ile çalışmıyor**: Kavis /proc'u hidepid ile bağlamıyor;
  ileride sertleştirmeye hidepid eklenirse earlyoom'un kırılacağı
  bilinsin (buraya not).

## memtest86+ (madde 30, F3 menüsü)

- **"GRUB'dan memtest.efi yüklenemiyor"** ve Secure Boot gerçeği:
  memtest86+ EFI ikilisi İMZASIZ — Secure Boot açıkken shim yüklemeyi
  reddeder. ÖNLEM: UEFI girdisinin başlığı dürüst:
  "RAM testi (memtest86+, Secure Boot kapalıyken)". BIOS'ta linux16 ile
  sorunsuz.
- **USB klavye tespit sorunları** (çok sayıda donanımda): bizim
  çözebileceğimiz bir şey değil; F3 menüsünden çıkışın her zaman
  Ctrl+Alt+Del/reset ile mümkün olduğu docs'ta anılacak (madde 50'de
  ayarlardan yeniden başlatıp otomatik memtest'e gitme eklenince
  kullanıcıya da söylenecek).
- **x2APIC/çok çekirdek askıda kalmaları** (sunucu donanımı): hedef
  kitle dizüstü/masaüstü; kapsam dışı, not edildi.

## Karara bağlananlar

1. earlyoom `--avoid` REGEX'i zorunlu yapılandırma — "masaüstüne güvenli
   dönüş" ilkesinin (bazzite dersi) earlyoom'daki karşılığı.
2. memtest86+ yalnız amd64 (MİMARİ kuralı) ve UEFI girdisi Secure Boot
   sınırını başlıkta söylüyor; çalışmayan girdi gizlenmiyor ama yalan da
   söylemiyor.
3. picom: `picom.md`'deki plan aynen uygulandı (xrender + köşe +
   animasyon; blur yok).
