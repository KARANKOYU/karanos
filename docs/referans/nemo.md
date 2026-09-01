# nemo — referans incelemesi

İlgili Kavis maddesi: 39 (dosya yöneticisi), 36 (hızlı önizleme).
İnceleme tarihi: 2026-09-01, depo HEAD'i `29fbc4b` (2026-08-28, sürüm 6.7.5 "alfa").
Kaynak: `/tmp/referans/nemo` (kod kopyalanmadı; yalnızca yaklaşım anlatılıyor).

## Kimlik

- Linux Mint'in dosya yöneticisi; Nautilus 3.4'ün çatalı. C + GTK3, meson ile
  derleniyor; ~164 bin satır C.
- Debian trixie'de paket **var**: `nemo`, `nemo-data`, `libnemo-extension1`,
  `gir1.2-nemo-3.0`, `nemo-python`, `nemo-fileroller` (trixie'deki sürüm
  numarası doğrulanmadı — paket indeksimiz sürüm tutmuyor; HEAD'den eski
  olduğu kesin, aşağıda "6.8" işaretli özellikler trixie'de olmayabilir).
- Masaüstü simgelerini ayrı bir süreç yönetir: `nemo-desktop`.

## Mimari ve bağımlılıklar

Kaynak yerleşimi:

- `src/` — uygulama, görünümler (simge / liste / kompakt / masaüstü), pencere,
  araç çubuğu, bağlan-sunucuya diyaloğu.
- `libnemo-private/` — dosya modeli, kopyalama motoru, geri alma, arama
  motorları, küçük resimler, gsettings şeması (`org.nemo.gschema.xml`).
- `libnemo-extension/` — **kararlı eklenti API'si** (ayrı .so, GIR üretiyor).
- `search-helpers/` — içerik aramasında belgeyi düz metne çeviren küçük
  yardımcılar (pdf, odf, xls, ppt, epub...).
- `action-layout-editor/` — sağ tık menüsündeki action'ları alt menülere
  dizmek için Python/GTK aracı.

`debian/control`'e göre `nemo` ikili paketinin bağımlılıkları (Cinnamon'un
tamamını ÇEKMEZ, sadece şu parçaları):

- **Depends:** `cinnamon-desktop-data`, `cinnamon-l10n`, `gvfs`,
  `libnemo-extension1`, `nemo-data`, `gsettings-desktop-schemas`,
  `shared-mime-info`, `desktop-file-utils`, `xapp-symbolic-icons` ve içerik
  araması yardımcıları için `poppler-utils`, `exif`, `id3`, `catdoc`,
  `untex`, `html2text`, `python3-xlrd`.
- **Recommends:** `gvfs-backends`, `gvfs-fuse`, `librsvg2-common`,
  `nemo-fileroller`, `gnome-disk-utility`.
- Derleme tarafında `libcinnamon-desktop-dev`, `libxapp-dev`, `json-glib`,
  `gtk-layer-shell` (Wayland) var; çalışma zamanında libcinnamon-desktop ve
  libxapp kütüphaneleri gelir.

**Kavis için kritik:** ISO `--apt-recommends false` ile derlendiğinden
(CLAUDE.md tuzağı) `gvfs-backends`, `gvfs-fuse`, `nemo-fileroller` ve
`librsvg2-common` paket listesine **açıkça** yazılmalı; yoksa ağ
paylaşımları ve sıkıştırma menüsü sessizce kaybolur.

## Genişletme noktaları (actions, eklenti, gsettings)

### 1. Actions (.nemo_action) — sağ tık menüsüne dosya ile madde ekleme

Belge deponun içinde: `files/usr/share/nemo/action-info.md` ve tam açıklamalı
örnek `files/usr/share/nemo/actions/sample.nemo_action`.

- Konum: `/usr/share/nemo/actions/` (sistem) ve
  `~/.local/share/nemo/actions/` (kullanıcı). Standart keyfile sözdizimi,
  `[Nemo Action]` grubu.
- Zorunlu anahtarlar: `Name`, `Exec`, `Selection` ve
  (`Extensions` VEYA `Mimetypes`).
- `Selection`: `s` (tek), `m` (çoklu), `any`, `notnone`, `none` (boş alana
  sağ tık = arka plan menüsü) veya sabit bir sayı.
- Exec/Name/Comment içinde yer tutucular: `%U` (URI listesi), `%F` (yol
  listesi), `%P` (bulunulan klasör), `%f`/`%N` (ilk seçimin adı), `%p`, `%D`
  (aygıt yolu), `%e` (uzantısız ad), `%X` (pencere XID), `%%`.
- Koşul mekanizmaları epey güçlü:
  - `Dependencies=` — PATH'te aranan programlar; `!program` ile ters mantık.
  - `Conditions=` — `desktop`, `removable`,
    `gsettings <şema> <anahtar> ...` (değer karşılaştırmalı), `dbus <ad>`,
    `exec <program>` (çıkış koduna göre), `sidebar-allow` / `sidebar-only`
    (6.8, trixie'de doğrulanmadı).
  - `UriScheme=` (örn. sadece sftp'de göster), `Locations=` / `Files=`
    (glob listeleri, `!` ile yasak deseni).
- `Terminal=true`, `Quote=`, `Separator=`, `Icon-Name=` ek ayarları.
- Hata ayıklama: `NEMO_DEBUG=Actions nemo --debug`.
- Menü düzeni: `~/.config/nemo/actions/actions-tree.json` ile action'lar alt
  menülere / ayraçlara dizilebilir, etiket ve simge ezilebilir
  (`action-layout-editor/actions-tree.md`).
- **Sınırlar:** action statik bir komut çalıştırır; duruma göre değişen
  etiket (yer tutucular hariç), onay kutusu, dinamik alt menü yok — bunlar
  için eklenti API'si gerekir. Kullanıcı action'ları `disabled-actions`
  gsettings anahtarıyla kapatabilir.

### 2. Scripts — daha da basit kanca

`~/.local/share/nemo/scripts/` altındaki çalıştırılabilirler "Betikler" alt
menüsünde görünür; seçim `NEMO_SCRIPT_SELECTED_FILE_PATHS`,
`NEMO_SCRIPT_CURRENT_URI` gibi ortam değişkenleriyle geçer (ikili panelin
karşı gözü için `NEMO_SCRIPT_NEXT_PANE_*` bile var).

### 3. Eklenti API'si (C ve Python)

`libnemo-extension` beş temel arayüz sunar (eklentiler
`/usr/lib/<triplet>/nemo/extensions-3.0/` içine .so olarak konur):

- `NemoMenuProvider` — `get_file_items` / `get_background_items` ile dinamik
  bağlam menüsü maddeleri (alt menü ve duruma göre üretim mümkün).
- `NemoColumnProvider` — liste görünümüne **yeni sütun** tanımlar.
- `NemoInfoProvider` — `update_file_info` ile dosya başına (async) öznitelik
  doldurur; sütunların verisi buradan gelir.
- `NemoPropertyPageProvider` — özellikler penceresine sekme ekler.
- `NemoLocationWidgetProvider` — klasöre özel bilgi bandı/widget
  (örn. "bu klasör salt okunur" şeridi bu mekanizmayla yapılabilir).
- Ek olarak `NemoNameAndDescProvider` (eklenti yöneticisi listesi için ad).

Python tarafı: trixie'deki `nemo-python` paketi aynı arayüzleri Python'a
açar (ayrı depo, bu incelemede kaynak düzeyinde doğrulanmadı); eklentiler
`~/.local/share/nemo-python/extensions/` altına .py olarak konur. Kavis'in
sütun/özellik sayfası eklemesi gerekirse en hızlı yol bu.

### 4. gsettings (org.nemo.*) — sadece ayarla açılan davranışlar

Şema: `libnemo-private/org.nemo.gschema.xml`. Kavis'i ilgilendirenler:

- **Klasör başına görünüm hatırlama:** varsayılan davranış zaten bu —
  görünüm/zoom klasörün gvfs metadata'sına yazılır. `ignore-view-metadata`
  ile kapatılır; `inherit-folder-viewer`, `inherit-show-thumbnails` alt
  klasörlere miras ayarları.
- **Tek tık:** `click-policy` (`single`/`double`); ayrıca
  `quick-renames-with-pause-in-between` (iki ayrı tıkla yeniden adlandırma),
  `click-double-parent-folder` (boş alana çift tıkla üst klasör).
- **Gizli dosyalar:** `show-hidden-files` (Ctrl+H ile de değişir).
- **Sıkıştırma formatları:** gsettings'te YOK — sıkıştırma tamamen
  `nemo-fileroller` eklentisi üzerinden file-roller diyaloğuna delege.
- Diğer işe yarayanlar: `start-with-dual-pane`, `restore-tabs-on-startup`,
  `tabs-open-position`, `default-folder-viewer`, `size-prefixes`
  (base-10/base-2), `enable-delete` + `swap-trash-delete` +
  `confirm-move-to-trash`, `show-directory-item-counts`,
  `show-full-path-titles`, `bulk-rename-tool`, `never-queue-file-ops`.
- **Menü ve araç çubuğu sadeleştirme tamamen ayarla yapılır:** her bağlam
  menüsü maddesi için `selection-menu-*` / `background-menu-*` boolean'ları,
  her araç çubuğu düğmesi için `show-*-toolbar` anahtarları,
  `disabled-actions` / `disabled-scripts` / `disabled-extensions` listeleri.
- Arama: `search-content-*`, `search-files-use-regex`, `search-skip-folders`
  gibi anahtarlarla dosya adı + içerik araması (yardımcı paketler sayesinde
  pdf/ofis belgelerinin içinde de arar).

Kavis'te varsayılanlar dconf profili yerine
`/usr/share/glib-2.0/schemas/` altına bir override dosyası + hook ile
verilmeli (tema/ayar paketimizdeki mevcut yaklaşımla aynı).

## Madde 39 istekleri: hazır olanlar / eksik olanlar

| İstek | Nemo'da durumu | Nasıl kapatılır |
|---|---|---|
| Ctrl+tekerlek zoom | KISMEN — Ctrl+tekerlek çalışıyor ama **kademesiz değil**: 7 sabit seviye (`NemoZoomLevel`), tekerlek seviye atlatıyor (`nemo-view.c`) | Pratikte yeterli; gerçek kademesiz istenirse yama gerekir (önerilmez) |
| Toplu yeniden adlandırma | DELEGE — kendi aracı yok; çoklu seçimde F2 `bulk-rename-tool` anahtarındaki harici komutu çağırır. Mint `bulky` kullanır, **trixie'de `bulky` YOK** (doğrulandı) | trixie'deki `gprename`'i paketleyip anahtara yazmak veya kendi basit aracımızı yazmak |
| Ctrl+Z geri alma | VAR ama **tek adım** — `NemoFileUndoManager` tek işlem tutar, yığın yok. Kapsam: kopyala/taşı/çoğalt/yeniden adlandır/çöp/klasör-dosya-bağlantı oluştur/izin-sahip değişikliği. Çöp boşalınca ilgili geri alma düşer | Tek adım kabul edilebilir; derin yığın istemek büyük yama olur, önerilmez |
| Çakışma ekranı | VAR — değiştir / atla / elle yeni ad / otomatik ad + "tümüne uygula" (`nemo-file-conflict-dialog`) | Hazır |
| Klasör boyutu hesaplama | KISMEN — Boyut sütunu klasörlerde **öğe sayısı** gösterir (`show-directory-item-counts`); bayt cinsinden derin boyut yalnız Özellikler penceresinde (deep count API'si mevcut) | Sütunda bayt istenirse `NemoColumnProvider`+`NemoInfoProvider` (nemo-python ile) yazılır |
| İkili panel | VAR — F3, `start-with-dual-pane` | Hazır |
| Sekmeler | VAR — açılışta geri yükleme dahil (`restore-tabs-on-startup`) | Hazır |
| Şablonlar | VAR — XDG `~/Templates`, alt klasörlü menü; şablondan oluşturma geri alınabilir | Şablon dosyalarını iskelet (`/etc/skel`) ile dağıt |
| Ağ paylaşımları | VAR — gvfs üzerinden (smb/sftp/ftp/dav); "Sunucuya Bağlan" diyaloğu | `gvfs-backends`+`gvfs-fuse` paket listesine açıkça yazılmalı |
| Madde 36: hızlı önizleme | KANCA VAR, UYGULAMA YOK — Boşluk tuşu `org.nemo.Preview` D-Bus servisine ShowFile çağrısı yapar (`src/nemo-previewer.c`); bunu sağlayan `nemo-preview` **trixie'de YOK** | Kavis kendi önizleyicisini bu D-Bus adını sahiplenen küçük bir GTK uygulaması olarak yazarsa Nemo'ya yama gerekmez |

## Tuzaklar (tekrar eden issue şikâyetleri)

En çok yorum alan açık issue'lardan (gh api, 2026-09-01):

- **Ağ/gvfs kırılgan bölge:** kopuk ağ paylaşımına göz atınca sistemin
  askıda kalması (48 yorum), SMB'den uygulamaya sürükle-bırak yapılamaması
  (23), SMB'ye kopyada sembolik link olunca hata (19), kenar çubuğundaki
  bayat ağ bağlantılarının silinememesi (16).
- **MTP/telefon:** USB hata ayıklama açık telefon bağlanınca çökme/donma
  (24), MTP hataları (19).
- **Küçük resimler:** amblemli küçük resimlerde 16 GB'a varan bellek
  sızıntısı (14), "thumbnail cache sorunu" yönetici uyarısı (13).
- **Yetki işleri:** "izinleri içindekilere uygula" çalışmıyor (36),
  "kök olarak aç" bozuldu (14) — polkit tarafı sürümden sürüme kırılıyor.
- Diğer: çoklu monitörde masaüstü simgeleri kayboluyor (29), taşıma sonrası
  boş klasör durumu güncellenmiyor (24), Del tuşu bazen silmiyor (18).

Kavis testine çevirisi: duman testine SMB bağlantısı ve USB/MTP takma
senaryosu eklemek, canlı sistemde thumbnail RAM'ini gözlemek mantıklı.

## Kavis için çıkarımlar

1. **Kurulum:** `nemo nemo-data nemo-fileroller gvfs-backends gvfs-fuse
   librsvg2-common` açıkça listeye yazılır (Recommends kapalı!). `nemo`
   paketi cinnamon-desktop-data + libcinnamon-desktop + libxapp getirir ama
   Cinnamon masaüstünün tamamını çekmez; ISO boyutu için kabul edilebilir.
   İçerik araması yardımcıları (poppler-utils, catdoc...) zorunlu Depends,
   kırpılamaz.
2. **Sağ tık kişiselleştirme sıfır yama ile:** kendi maddelerimiz
   `.nemo_action` dosyaları olarak `/usr/share/nemo/actions/`'a; istemediğimiz
   maddeler `selection-menu-*` / `background-menu-*` gsettings override'ı ile
   kapatılır; alt menü düzeni `actions-tree.json` iskeletiyle dağıtılabilir.
3. **Madde 36'nın en ucuz yolu:** `org.nemo.Preview` D-Bus arayüzünü
   (ShowFile/Close) sağlayan kendi hafif önizleyicimiz. Nemo Boşluk tuşunda
   onu zaten çağırıyor; Nemo'ya dokunmak gerekmiyor. Alternatif: nemo-preview
   kaynaktan paketlenir (clutter bağımlılığı ağır, önerilmez).
4. **Toplu yeniden adlandırma boşluğu:** `bulk-rename-tool` anahtarı +
   trixie'deki `gprename` (veya ileride kendi küçük aracımız). `bulky`
   trixie'de yok, Mint deposundan alınmaz.
5. Varsayılan davranış ayarları (tek/çift tık, çöp onayı, ikili panel,
   sekme geri yükleme, base-2 boyutlar vb.) tamamen gschema override dosyası
   ile verilir; kod değişikliği yok.
6. Ek sütun / özellik sayfası ihtiyacı doğarsa önce `nemo-python` ile
   denenir; C eklentisi son çare.
7. Tema tarafında Nemo saf GTK3 — mevcut `packages/kavis-theme` koyu
   teması ek iş istemez; masaüstü simgeleri `nemo-desktop` sürecinindir,
   oturum başlatıcıda buna karar verilmeli.
