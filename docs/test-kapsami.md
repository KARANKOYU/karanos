# Test kapsamı — madde başına selftest senaryosu

Bu dosya `tools/gen-test-coverage.py` ile ÜRETİLİR, elle
düzenlenmez. Kaynaklar: `docs/gorev-listesi.md` maddeleri ve
`tests/ui/*.yaml` senaryolarının `item:` alanı (karar 9b).

Durum sütunu: **var** = senaryosu yazılmış · **EKSİK** =
grubu bitmiş ama testi yok (hata) · **sırada** = grubu henüz
yapılmadı · **yok** = çalışan sistemde karşılığı olmayan madde.

**Kapsam: 34 / 72 madde; bitmiş gruplarda 34 / 34.**

| Madde | Başlık | Durum | Senaryo |
|---|---|---|---|
| 0 | Kullanıcı sistemi ERTELENDİ | var | `01-boot` |
| 1 | Logo referansları | var | `01-logo` |
| 2 | picom compositor | var | `02-compositor` |
| 3 | Paneli C veya Vala'ya taşı | var | `03-panel` |
| 4 | Görev çubuğu görünümü: | var | `04-taskbar-look` |
| 5 | Görev çubuğu sağ tık menüsü: | var | `05-taskbar-menu` |
| 6 | Pencere yönetimi: | var | `06-shortcuts`, `06-window-snap` |
| 7 | Görev yöneticisi + küçük araçlar: | var | `07-tools` |
| 8 | Güvenlik sertleştirme: | var | `08-hardening` |
| 9 | Ayarlar iskeleti: | var | `09-settings-theme` |
| 10 | Ekran ayarları: | var | `10-display` |
| 11 | Arama çubuğu (Everything mantığı): | sırada | — |
| 12 | Kavis Mağaza: | sırada | — |
| 13 | Oyun Modu (SteamOS tarzı): | sırada | — |
| 14 | GPU offload: | sırada | — |
| 15 | Kurulum sihirbazı (ilk açılış): | sırada | — |
| 16 | Kurucu + canlı mod | sırada | — |
| 17 | /usr salt-okunur btrfs subvolume | sırada | — |
| 18 | Giriş ekranı + kilit ekranı | sırada | — |
| 19 | Kendi APT depomuz: | sırada | — |
| 20 | Kurtarma ortamı | sırada | — |
| 21 | kavis-gameopt: | sırada | — |
| 22 | CI iyileştirmesi (build-iso.yml): | yok — CI iş akışı — çalışan sistemde karşılığı yok | — |
| 23 | İndirme yöneticisi (Store içinde), aria2c tabanlı: | sırada | — |
| 24 | İlk açılış uygulama seçimi | sırada | — |
| 25 | Ağ önceliklendirme | sırada | — |
| 26 | Güncelleme sistemi | sırada | — |
| 27 | USB'den güncelleme (offline) | sırada | — |
| 28 | Mağazada "Windows karşılığı": | sırada | — |
| 29 | Ekran görüntüsü ve kaydı | var | `29-capture` |
| 30 | Açılış ekranı | var | `30-boot-splash` |
| 31 | Snapshot geri alma (Time Machine mantığı): | sırada | — |
| 32 | Sorun giderici (iyi yapılacak): | sırada | — |
| 33 | Kurtarma ortamı (F8) — WinRE karşılığı | sırada | — |
| 34 | Çok dilli altyapı + Türkçe | var | `34-i18n` |
| 35 | Sürücü yardımcısı: | sırada | — |
| 36 | Hızlı önizleme (Quick Look): | var | `36-preview` |
| 37 | Takvim + bildirim paneli: | var | `37-panels` |
| 38 | Ayarlar → Kişiselleştirme: | var | `38-personalisation` |
| 39 | DOSYA YÖNETİCİSİ — Nemo'yu kur ve uyarla, sıfırdan yazma | var | `39-task-manager` |
| 40 | Terminal ve editörler | var | `40-editors` |
| 41 | Flatpak: | sırada | — |
| 42 | Disk ve USB: | var | `42-disks` |
| 43 | Yazıcı sihirbazı: | var | `43-printer` |
| 44 | Terminal kolaylıkları: | var | `44-terminal` |
| 45 | Hakkında ekranı: | var | `45-about` |
| 46 | TEST ALTYAPISI | sırada | — |
| 47 | REFERANS İNCELEME (Grup A2) | yok — referans inceleme, çıktısı docs/referans/ | — |
| 48 | Güvenlik taraması + dosya doğrulama | sırada | — |
| 49 | SİSTEM SAĞLIĞI: | var | `49-system-health` |
| 50 | DONANIM TESTİ VE BENCHMARK: | var | `50-hardware-test` |
| 51 | GÜÇ VE PİL: | var | `51-power` |
| 52 | AĞ ARAÇLARI: | var | `52-network` |
| 53 | SANALLAŞTIRMA: | sırada | — |
| 54 | CİHAZ DESTEĞİ: | sırada | — |
| 55 | SANAL MASAÜSTLERİ + ODAKLANMA: | var | `55-desktops` |
| 56 | OTOMATİK YEDEKLEME (snapshot'tan AYRI): | sırada | — |
| 57 | İLK ADIMLAR REHBERİ: | sırada | — |
| 58 | YOL HARİTASI: | yok — yol haritası belgesi | — |
| 59 | SORUN ÖNLEME TARAMASI | sırada | — |
| 61 | GTK ORTAK BAŞLANGIÇ NOKTASI | var | `61-gtk-startup` |
| 62 | BİLİNEN HYPERVISOR UYARILARI LİSTESİ | var | `62-hypervisor-noise` |
| 63 | USB GÜVENLİ KULLANIM | var | `63-usb-safety` |
| 64 | USB DOSYA SİSTEMİ ONARIMI | var | `64-usb-repair` |
| 65 | CACHYOS REFERANS İNCELEMESİ | sırada | — |
| 66 | SICAKLIK İZLEME | sırada | — |
| 67 | KRİTİK SICAKLIK UYARISI | sırada | — |
| 68 | SOĞUTMA KATMANI — FAN KONTROLÜ | sırada | — |
| 69 | YENİDEN KURULUM — "DOSYALARIMI KORU" KİPİ | sırada | — |
| 70 | KİLİT EKRANI | var | `70-lock-screen` |
| 71 | fastfetch / kavisfetch | var | `71-kavisfetch` |
| 75 | APP FILES — uygulama verileri klasörü | sırada | — |

## Listede karşılığı olmayan senaryolar

- madde 60: `60-popup-dismiss`
- madde 72: `72-selftest`
