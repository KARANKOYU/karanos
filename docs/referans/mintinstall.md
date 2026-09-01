# mintinstall — referans incelemesi

İlgili Kavis maddeleri: 12 (mağaza), 41 (Flatpak). İnceleme tarihi: 2026-09-01,
depo HEAD'i `06407c8` (2026-08-19). Kaynaklar: `/tmp/referans/mintinstall` ve
arka uç kitaplığı `/tmp/referans/mintcommon` (mintinstall tek başına anlaşılmaz;
asıl iş `python3-mintcommon` paketindeki `mintcommon.installer` modülünde).

## Kimlik

- Linux Mint'in "Yazılım Yöneticisi"; GTK3 + PyGObject, saf Python 3.
- Boyut şaşırtıcı derecede küçük: mintinstall deposunda ~4 450 satır Python
  (bunun ~3 340'ı tek dosya `mintinstall.py`) + ~2 400 satır Glade arayüz
  tanımı. Arka uç `mintcommon/installer` ~4 100 satır. Toplam ~8 500 satır
  Python ile tam teşekküllü bir mağaza.
- Veri dosyaları koddan ayrı: kategori listeleri, öne çıkanlar, deb↔flatpak
  eşleme tablosu hepsi düz metin/JSON olarak `usr/share` ve `usr/lib` altında.

## Mimari

İki katman:

1. **UI katmanı** (`usr/lib/linuxmint/mintinstall/mintinstall.py`): tek büyük
   Gtk.Application sınıfı; sayfalar bir Gtk.Stack içinde (landing / liste /
   detay / arama / "önbellek oluşturuluyor"). Yardımcılar: `imaging.py`
   (asenkron simge/ekran görüntüsü), `reviews.py` (puan önbelleği),
   `housekeeping.py` (eski önbellek temizliği), `screenshot_window.py`.
2. **Arka uç kitaplığı** (`mintcommon/installer/`): `installer.py` cephe sınıfı
   ve `InstallerTask` görev nesnesi; `cache.py` paket önbelleği; `_apt.py` ve
   `_flatpak.py` iki kaynak sürücüsü; `appstream_pool.py` AppStream okuyucu;
   `pkgInfo.py` ortak veri modeli.

Kilit fikir: **tek ortak `PkgInfo` modeli**. Her paketin `pkg_hash` anahtarı
kaynak önekiyle başlar ("a…" = apt, "f…" = flatpak; ör. `apt:ad` /
`fp:uzak-depo:ref`). UI'nin çoğu yeri kaynağı sadece bu önekten ayırt eder;
gerisi ortak arayüzden (`get_display_name`, `get_summary`, `get_icon`…) akar.

Kurulum/kaldırma arka uçları:

- **apt**: işlemi `aptkit` (aptdaemon'un Mint devamı) yürütür; ilerleme
  penceresi `aptkit.gtk3widgets.AptProgressDialog`. `PackageKitGlib` yalnızca
  hata kodu numaralandırması için içe aktarılıyor (asıl motor PackageKit
  değil). Simülasyon adımı (`do_simulate_question`) neyin ekleneceğini/
  sileceğini ve disk etkisini kullanıcıya onaylatır; `CRITICAL_PACKAGES`
  listesindeki paketleri (mint-common, python3, perl…) söken işlemler
  "forbidden" durumuyla engellenir.
- **Flatpak**: aracı süreç yok — GIR üzerinden doğrudan libflatpak;
  `Flatpak.Transaction` uygulama içinde kurulur, ilerleme sinyalleri UI'ye
  bağlanır. `.flatpakref` / `.flatpakrepo` dosyaları da uygulamaya
  bırakılabiliyor (dosya yöneticisinden çift tıklama akışı).

Her iki tür işlem tek `InstallerTask` soyutlamasına sarılır: seçim → bilgi
hazır geri çağrısı → onay → yürütme → bitti/hata temizliği. UI, kaynak türünü
bilmeden aynı düğme/ilerleme mantığını kullanır.

## apt + Flatpak birlikte sunumu

Kavis madde 41'in sorduğu sorunun mintinstall cevabı üç parça:

1. **Tek önbellek, iki kaynak.** `PkgCache` sözlüğünde apt ve flatpak kayıtları
   yan yana durur; arama, kategoriler ve listeler tek listeden beslenir.
   Listelerdeki karolar flatpak paketlerine küçük bir amblem + depo adı basar
   ("Bu paket bir Flatpak" ipucuyla).
2. **deb↔flatpak eşleme tablosu elle onaylanmış statik bir JSON.**
   `apt_flatpak_match_data.info` dosyasında `apt_flatpak_matches` (deb adı →
   flatpak kimliği) ve yanlış pozitifleri hatırlamak için `apt_ignore_list`
   var. Tabloyu depodaki `apt_flatpak_matcher.py` betiği yarı otomatik üretir:
   ad benzerliği, `org.gnome.X` kalıpları ve ana sayfa URL eşitliği gibi
   sezgisel kurallarla aday bulur, **insan tek tek onaylar** (betiğin kendi
   yorumu "5 GHz işlemcide ~5 dakika" sürdüğünü söylüyor). Yani çalışma
   zamanında pahalı eşleştirme yok; ürünle birlikte kürate edilmiş liste
   gemiye biner.
3. **Detay sayfasında kaynak seçici.** Bir paketin hem deb'i hem flatpak'ı
   varsa detay sayfasında "System Package / Flatpak (depo adı)" seçenekli bir
   açılır kutu çıkar; seçim değişince aynı sayfa diğer kaynağın `PkgInfo`
   nesnesiyle yeniden çizilir. Tek kaynak varsa kutu gizlenir, yerine sabit
   bir tür rozeti görünür. Flatpak aynı adla birden çok uzak depoda varsa her
   depo ayrı satır olur.

Arama sonuçlarında çiftleri bastırmak için bir **tür tercihi ayarı** var
(apt öncelikli / flatpak öncelikli / ikisi de): tercih apt ise, deb'i bulunan
flatpak eşi sonuç listesinden gizlenir (tersi de aynı). Ayrıca Flathub'ın
"verified" bayrağı taşınır: doğrulanmamış flatpak'lar vitrine (banner, Top
Rated) çıkmaz ve detayda uyarı kutusu görür.

## Katalog, metaveri ve önbellek

- **apt tarafı**: kaynak, python-apt önbelleğinin kendisi. Tam liste agresif
  biçimde süzülür: lib*, -dev/-dbg/-doc/-data/-common, l10n, i386 (steam
  hariç), çekirdek paketleri, geçiş ("transitional") paketleri atılır. Kalan
  paketlerin apt bölümü (section) kategorilere eşlenir.
- **Kategoriler AppStream'den değil, elle bakımlı listelerden**:
  `usr/share/linuxmint/mintinstall/categories/*.list` düz metin paket adı
  listeleri (internet-web, graphics-3d, games-fps…). Kategori ağacı kodda
  kurulur; önce bu listeler eşlenir, sonra listede olmayan paketler apt
  bölümlerine göre "eksik kalanlar" geçişiyle dağıtılır. Flatpak tarafında
  kategori = uzak depo (Flathub vb.); her depo, "Flatpak" kök kategorisinin
  altına alt kategori olarak eklenir.
- **Flatpak metaverisi AppStream'den**: her uzak deponun indirdiği
  `appstream.xml(.gz)` dosyası libxmlb (`Xmlb` GIR) ile mmap'lenip derlenir,
  bileşenler XPath sorgularıyla tembelce (lazy) bulunur ve pkg_hash →
  AppStream nesnesi sözlüğünde tutulur. Görünen ad, açıklama, geliştirici,
  sürüm, ekran görüntüsü URL'leri, eklentiler (addon) hep buradan.
- **apt metaverisi apt kayıtlarından** (özet/açıklama); görünen adlar için
  kodda küçük bir `ALIASES` tablosu var (ör. gimp → Gimp). apt paketleri için
  AppStream kullanımı sınırlı görünüyor (doğrulanmadı — `_apt.py`'deki
  arama yardımcı işlevi ayrıntılı incelenmedi).
- **Paket önbelleği**: tüm süzülmüş katalog tek `pkginfo.json` dosyasına
  yazılır; hem sistem (`/var/cache/mintinstall/`) hem kullanıcı
  (`~/.cache/mintinstall/`) kopyası olabilir, **en yenisi kazanır**; 7 günden
  eskiyse yok sayılır. Dosyada şema sürümü var; uymuyorsa sessizce yeniden
  üretilir. Flatpak uzak depoları değiştiyse (ad/URL/devre dışı durumu
  gsettings'te saklanan son görüntüyle karşılaştırılır) önbellek zorla
  tazelenir. Tazeleme tek türle sınırlanabilir (yalnız "f" yenilenirken apt
  kayıtları korunur — yorumda gerekçe: mintupdate'in flatpak tazelemesi
  mintinstall'ı apt'siz bırakmasın).
- **Bant dışı tazeleme**: `mintinstall-update-pkgcache` adlı küçük bir CLI
  betiği önbelleği UI olmadan yeniden üretir; zamanlanması bu depoda değil
  (muhtemelen mintupdate/cron tarafında — doğrulanmadı).
- **Görseller**: simgeler önce simge temasından, yoksa URL'den `AsyncImage`
  ile asenkron indirilir (2 iş parçacıklı havuz + bellek içi surface
  önbelleği). Ekran görüntüleri: flatpak'ta AppStream'deki URL (Flathub göreli
  yolları CDN tabanına eklenir); deb'de önce community.linuxmint.com'daki
  hazır PNG, yoksa **screenshots.debian.net sayfası BeautifulSoup ile
  kazınır** (kırılgan bir yöntem). Hepsi `~/.cache/mintinstall/screenshots`
  altına iner; `housekeeping.py` 14 günden eskileri ayrı bir süreçte siler.
- **Puanlar/yorumlar**: community.linuxmint.com'dan tek büyük liste dosyası
  indirilir, yerelde `reviews.json` olarak tutulur; güncelleme kontrolü önce
  HEAD isteğiyle boyut karşılaştırarak yapılır (değişmediyse indirme yok).

### Başlangıç hızı hileleri

- Önbellek tazeyse `init_sync` ile **eşzamanlı** yüklenir ve pencere doğrudan
  içerikle açılır; değilse "önbellek oluşturuluyor" sayfası gösterilip üretim
  iş parçacığına atılır. İlk açılış yavaş, sonrakiler hızlı — maliyeti kabul
  edilmiş bir tasarım.
- Landing içeriği (banner, Top Rated, kategoriler) `GLib.idle_add`
  geri çağrılarıyla parça parça kurulur; ağır kategori eşleme işi bile
  "önce görseli göster, kalanı idle'da bitir" diye ikiye bölünmüş.
- Arama dizini yok: arama, önbellek listesi üzerinde **idle döngüsünde paket
  paket** ilerleyen basit alt dize karşılaştırması (ad → anahtar kelime →
  özet → açıklama sırasıyla katmanlı puan). UI hiç kilitlenmez, yeni tuş
  basımı idle kaynağını iptal eder. Ölçeklenebilirlik yerine basitlik seçilmiş.
- Kod her yerde `print_timing` dekoratörüyle ölçümlü; başlangıç süresi
  ayrıca toplam olarak yazdırılır.

## Tuzaklar (tekrar eden issue şikâyetleri)

En çok yorum alan issue'lardan süzülen örüntüler (gh api ile alındı):

- **Flatpak entegrasyonu baş şikâyet kaynağı**: kurulum hataları
  (ör. Flathub Thunderbird), flatpak'ların listede hiç görünmemesi, sistem
  deposunun kendiliğinden yeniden etkinleşmesi, hatta "Flatpak desteğini
  tamamen kaldırma" seçeneği isteyen talep. Ders: iki kaynaklı mağazada
  flatpak tarafı bozulunca kullanıcı tüm mağazayı suçluyor.
- **"Generating cache" ekranında takılma / açılmama** birden çok issue'da
  geçiyor. İlk açılışta ağır önbellek üretimi + bozuk önbellekte kurtarma
  eksikliği, uygulamanın hiç açılmaması gibi görünüyor.
- **Aramada / yoğun kullanımda çökme** (LMDE'de arama çökmesi, çok sayıda
  kurulumdan sonra işlevsizleşme).
- **Kaldırma işleminin neyi sileceğini söylememesi**: bağımlılık yüzünden
  masaüstünün yarısını söken kaldırmalar; bir vakada Handbrake flatpak'ı
  kurarken uygulamanın kendini kaldırması. Simülasyon/onay ekranı sonradan
  gelmiş.
- **Yanlış eşleme/metaveri**: yanlış Opera paketi, flatpak sürüm bilgisinin
  görünmemesi, banner görsellerinin kaybolması. Statik eşleme tablosunun ve
  AppStream boşluklarının bedeli.
- Bir sistem mağazasının izin dosyalarını bozması (dconf izinleri) gibi
  kök/kullanıcı ayrımı kazaları.

## Kavis için çıkarımlar

Madde 12 (mağaza):

- **Katman ayrımını aynen al**: kaynak-bağımsız tek PkgInfo modeli + kaynak
  öneki taşıyan anahtar + kaynak sürücüleri (apt / flatpak) + ince UI. Bu,
  8 500 satırla mağaza yazılabilmesinin asıl sebebi.
- **Süzülmüş katalogu tek JSON önbelleğe yaz** (şema sürümü + azami yaş +
  sistem/kullanıcı kopyasından yenisini seçme). İkinci açılıştan itibaren
  anında açılan mağazanın sırrı bu. İlk açılıştaki "önbellek oluşturuluyor"
  ekranı için mintinstall issue'larından ders: takılırsa kurtarma yolu ve
  ilerleme göstergesi şart.
- **Kategorileri elle bakımlı listelerle + apt bölümü geriye düşüşüyle kur.**
  AppStream kategorileri Debian arşivinde eksik/dağınık; mintinstall'ın düz
  metin `.list` yaklaşımı ucuz ve öngörülebilir. Kavis kendi kürate
  listelerini `usr/share` altında veri dosyası olarak taşımalı, koda gömmemeli.
- **Kaldırma simülasyonunu ve kritik paket korumasını baştan koy**: neyin
  sileceğini göstermeyen kaldırma, mintinstall'ın en acı issue'larından.
  Kavis masaüstü metapaketleri "kritik" listesine girmeli.
- Arama için idle-döngülü doğrusal tarama 60–70 bin kayıtta bile yeterli ve
  UI'yi kilitlemiyor; başlangıçta dizin kurma maliyetinden kaçınmak için iyi
  bir ilk sürüm stratejisi.
- Ekran görüntüsünde HTML kazımaya (screenshots.debian.net + BeautifulSoup)
  bel bağlama; kırılgan. Debian AppStream metaverisindeki resmi ekran
  görüntüsü URL'leri tercih edilmeli (deb tarafı için de AppStream okumak,
  mintinstall'ın yapmadığı ama Kavis'in yapabileceği bir iyileştirme).

Madde 41 (aynı uygulama iki kaynaktan):

- mintinstall'ın cevabı üçlü: tek listede amblemle ayırt et, detayda kaynak
  seçici sun, aramada kullanıcı tercihiyle çifti gizle. Bu akış Kavis'e
  doğrudan uyarlanabilir.
- **Eşleme tablosu statik ve insan onaylı** — çalışma zamanı sezgiselinden
  daha güvenilir, ama bakım ister ve yanlış eşleme issue'ları doğurmuş.
  Kavis için daha sağlam yol: eşlemeyi öncelikle **AppStream bileşen
  kimliği** üzerinden otomatik yapmak (deb'lerin de AppStream kimliği var),
  kimlik eşleşmeyenler için mintinstall tarzı küçük bir elle liste tutmak.
  mintinstall'ın `apt_ignore_list` fikri (yanlış pozitifleri kalıcı
  hatırlama) her iki yolda da değerli.
- Doğrulanmamış flatpak'ları vitrine çıkarmama ve detayda uyarı gösterme
  kuralı aynen alınmalı.

Madde 23 (aria2c tabanlı indirme yöneticisi) ile bağdaşma:

- mintinstall **hiçbir paketi kendisi indirmez**; indirme apt/aptkit ve
  libflatpak'ın içinde kalır. Yani "mağaza + harici indirme yöneticisi"
  deseni mintinstall'da yok; Kavis bunu kendisi tasarlamak zorunda.
- Gerçekçi sınır: Flatpak tarafında indirme `Flatpak.Transaction`'ın içinde
  gömülü, aria2c araya sokulamaz — flatpak indirmeleri indirme yöneticisinde
  ancak **izlenebilir** (ilerleme sinyalleri oradan yansıtılır), devralınamaz.
  apt tarafında ise indirme ve kurulum ayrıştırılabilir: .deb'leri aria2c ile
  indirip apt'ye yerel dosyadan kurdurmak mümkün (Kavis'in tasarım kararı;
  mintinstall'dan örneği yok).
- mintinstall'dan alınacak indirme dersleri daha çok **yardımcı varlıklar**
  için: ekran görüntüsü/simge indirmeleri küçük bir iş parçacığı havuzunda,
  iptal edilebilir, diske önbellekli ve yaşlanınca temizlenir; büyük liste
  dosyaları indirilmeden önce HEAD ile "değişmiş mi" kontrolü yapılır. Bu
  kalıplar aria2c kuyruğuna da aynen taşınabilir (önbellek dizini + azami
  yaş + koşullu indirme).
