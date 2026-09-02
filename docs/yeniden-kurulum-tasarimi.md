# Yeniden kurulum — "dosyalarımı koru" kipi (tasarım)

Karar tarihi: 2026-09-02 (açılış deneyimi işleriyle aynı istekte
verildi). Uygulama zamanı: **Grup I** (Calamares, madde 16); alt birim
yapısı disk düzeni kararının parçası olduğu için Calamares disk
düzenine başlamadan ÖNCE bu belge okunur. Windows'un "dosyalarımı koru"
yeniden kurulumu gibi, ama daha temiz.

## Amaç

Yeni ISO ile mevcut kurulumun üstüne kurulunca:

- Kullanıcı dosyaları, ayarları ve kurduğu uygulamalar KALIR.
- Sistem dosyaları TAMAMEN yenilenir.
- Eski sistemden hiçbir artık kalmaz.

## Algılama

Calamares diskte mevcut Kavis kurulumu algılar: btrfs üzerinde `@` +
`@users` alt birimleri var ve `@` içindeki os-release Kavis ise.
Algılayınca üçüncü seçenek sunulur:

> "Kavis'i yeniden kur — dosyalarımı ve uygulamalarımı koru"

(Metin, uygulanırken `docs/kavis-arayuz-metinleri.md` tablosuna
eklenecek; Calamares TR/EN çevirileriyle birlikte.)

## Akış (seçilirse)

1. `@` içindeki kurulu paket listesi kaydedilir
   (`apt-mark showmanual` → `@users` altında geçici dosya).
2. Flatpak listesi kaydedilir (`flatpak list --app`).
3. Eski `@` SİLİNMEZ — `@old-<tarih>` olarak yeniden adlandırılır
   (geri dönüş için; 7 gün sonra otomatik silinir).
4. Yeni `@` alt birimi oluşturulur, squashfs buraya açılır.
5. `@users`'a hiç dokunulmaz.
6. Yeni sisteme geçilince: kaydedilen paket listesi apt ile geri
   kurulur, Flatpak'ler geri kurulur. Bulunamayan paketler kullanıcıya
   LİSTELENİR — sessizce atlanmaz.
7. fstab, GRUB girdileri, EFI kaydı yenilenir — eski sistemin GRUB
   girdisi kalmaz.

## Alt birim yapısı (genişletilmiş)

| Alt birim | Rol |
|---|---|
| `@` | sistem — her kurulumda yenilenir |
| `@users` | kullanıcılar — hiç dokunulmaz |
| `@flatpak` | `/var/lib/flatpak` — yeniden kurulumda korunur, runtime'lar tekrar inmez |
| `@old-*` | önceki sistem — otomatik temizlenir (7 gün) |

## Sistem geneli ayarların taşınması

Kullanıcı ayarları (`~/.config/kavis`, tema, güç planı, dil) zaten
`@users`'ta — kendiliğinden korunur. `/etc` altındaki sistem geneli
ayarlar `@` ile gider; şunlar kaydedilip yeni sisteme geri konur:

- `/etc/hostname`
- `/etc/timezone`
- `/etc/default/keyboard`
- `/etc/NetworkManager/system-connections/` (Wi-Fi şifreleri!)

## Geri yükleme noktalarıyla ilişki

Bu işlem kendisi de bir geri yükleme noktası gibi davranır: `@old-*`
varken GRUB F3 menüsünde "önceki sisteme dön" seçeneği görünür.

## Yapmayacaklarımız

- Eski `@`'nın üstüne dosya kopyalamak — artık bırakır.
- Kullanıcıya "hangi dosyaları koruyayım" diye sormak. Kural basit:
  `@users` tamamen kalır, `@` tamamen gider.
