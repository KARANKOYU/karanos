# GitHub kurulumu — adım adım

Bu dosya prompt'un 21. bölümünün cevabı. Aşağıdakileri **bir kez** yapacaksın;
sonrası otomatik.

GitHub kullanıcı adın: **`KARANKOYU`**
GitHub Pages adresleri küçük harfle çalışır: `https://karankoyu.github.io/...`

---

## 1. Açılacak depolar

| # | Depo adı | Görünürlük | Ne işe yarıyor | Durum |
|---|---|---|---|---|
| 1 | `karanos` | public | **Ana kaynak kodu.** Tüm `karanos-*` paketleri, ISO yapılandırması, kurulum aracı, GitHub Actions. ISO buradan Releases'e çıkar. | ✅ zaten var |
| 2 | `karanos-repo` | **public (zorunlu)** | **APT deposu.** Kurulu sistemler panel/ayarlar güncellemelerini buradan `apt upgrade` ile alır. İçeriğini Actions üretip buraya iter, elle dokunmayacaksın. | ⏳ açacaksın |
| 3 | `karanos-catalog` | **public (zorunlu)** | **Mağaza kataloğu.** Uygulama listesi (`catalog.json`) + ikonlar. ISO'ya gömülmez, mağaza ilk açılışta buradan indirir. Yeni uygulama eklemek = burada bir JSON satırı değiştirmek. | ⏳ açacaksın |

> **Neden public zorunlu:** GitHub Pages private depolarda sadece ücretli
> planlarda çalışır, ve çalışsa bile `apt` kimlik doğrulaması yapamaz. Depoların
> içinde gizli bir şey yok — `.deb` dosyaları ve uygulama listesi zaten dağıtılan
> şeyler.

### Depoları açma

GitHub'da sağ üst **+** → **New repository**:

**`karanos-repo` için:**
- Repository name: `karanos-repo`
- Public
- ✅ Add a README file
- Create repository

**`karanos-catalog` için:**
- Repository name: `karanos-catalog`
- Public
- ✅ Add a README file
- Create repository

---

## 2. GitHub Pages ayarı (iki depoda da aynı)

`karanos-repo` ve `karanos-catalog` depolarının **her ikisinde**:

1. Depoya gir → üstten **Settings**
2. Sol menüden **Pages**
3. **Build and deployment** → **Source**: `Deploy from a branch`
4. **Branch**: `main`, klasör: `/ (root)` → **Save**
5. Sayfa yenilenince üstte adresi yazar; birkaç dakika sonra aktifleşir

Sonuçta ortaya çıkacak adresler:

```
https://karankoyu.github.io/karanos-repo/
https://karankoyu.github.io/karanos-catalog/
```

### ⚠️ Her iki depoya da `.nojekyll` dosyası ekle

Bu şart. Yoksa GitHub Pages dosyaları Jekyll'den geçirir ve APT deposundaki
bazı dosyalar bozulur/gizlenir.

Her iki depoda: **Add file** → **Create new file** → dosya adı `.nojekyll`
(içi boş kalsın) → **Commit changes**.

---

## 3. GPG anahtarı (APT deposunu imzalamak için)

`apt` imzasız depoyu reddeder. Bir imzalama anahtarı üretip özel kısmını
GitHub Actions'a vereceğiz.

Anahtarı bu Codespace'te üretebilirsin. Terminale şunu yaz (Claude Code
içindeysen satırın başına `!` koy):

```bash
export GNUPGHOME=$(mktemp -d)
gpg --batch --passphrase '' --quick-generate-key \
    "Karan OS Repository <farukyildiz3207@gmail.com>" rsa4096 sign never
KEYID=$(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5; exit}')
echo "Anahtar kimliği: $KEYID"

# Genel anahtar — depoya girecek, gizli değil
gpg --export "$KEYID" > /tmp/karanos-archive-keyring.gpg

# Özel anahtar — GitHub secret'ına girecek, KİMSEYE VERME
gpg --armor --export-secret-keys "$KEYID" > /tmp/karanos-signing-key.asc

echo "--- ÖZEL ANAHTAR (kopyala) ---"
cat /tmp/karanos-signing-key.asc
```

Sonra:

1. **Özel anahtar → GitHub secret.**
   `karanos` deposu → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret**
   - Name: `GPG_PRIVATE_KEY`
   - Secret: yukarıdaki `-----BEGIN PGP PRIVATE KEY BLOCK-----` ile başlayıp
     `-----END PGP PRIVATE KEY BLOCK-----` ile biten metnin **tamamı**
   - Add secret

2. **Anahtar kimliği → GitHub secret.**
   Aynı yerde ikinci bir secret:
   - Name: `GPG_KEY_ID`
   - Secret: yukarıda yazdırılan `Anahtar kimliği` değeri

3. **Genel anahtarı bir kenara kaydet.** `/tmp/karanos-archive-keyring.gpg`
   dosyasını indir (VS Code'da sağ tık → Download) veya Codespace'i kapatmadan
   `assets/` dışında bir yere kopyala. Actions bunu `karanos-repo`'ya kendi
   yazacak, ama yedeği sende dursun.

> Parola koymadık (`--passphrase ''`) — otomatik imzalama yapan bir CI anahtarı
> için doğrusu bu. Anahtarın değeri zaten secret olarak korunuyor.
> **Bu anahtarı kaybedersen** yeni bir tane üretip kurulu sistemlerdeki
> keyring'i güncellemen gerekir; yedeğini bir yere al.

---

## 4. Erişim jetonu (Actions'ın diğer iki depoya yazabilmesi için)

ISO'yu derleyen workflow `karanos` deposunda çalışıyor ama `.deb`'leri
`karanos-repo`'ya, kataloğu `karanos-catalog`'a itmesi gerekiyor. Actions'ın
varsayılan jetonu sadece kendi deposuna yazabilir, o yüzden bir PAT lazım.

1. GitHub sağ üst avatar → **Settings** (hesap ayarları, depo ayarları değil)
2. En altta **Developer settings**
3. **Personal access tokens** → **Fine-grained tokens** → **Generate new token**
4. Doldur:
   - Token name: `karanos-ci`
   - Expiration: `No expiration` (veya 1 yıl)
   - Resource owner: `KARANKOYU`
   - Repository access: **Only select repositories** →
     `karanos-repo` **ve** `karanos-catalog` (ikisini de seç)
   - Permissions → Repository permissions → **Contents**: `Read and write`
5. **Generate token** → çıkan `github_pat_...` metnini kopyala (bir daha
   gösterilmez)
6. `karanos` deposu → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret**
   - Name: `REPO_TOKEN`
   - Secret: kopyaladığın jeton

### Özet — `karanos` deposuna eklenecek 3 secret

| Secret adı | İçeriği |
|---|---|
| `GPG_PRIVATE_KEY` | armored özel GPG anahtarı (`-----BEGIN PGP PRIVATE KEY BLOCK-----`…) |
| `GPG_KEY_ID` | GPG anahtar kimliği (uzun hex) |
| `REPO_TOKEN` | fine-grained PAT, `karanos-repo` + `karanos-catalog` üzerinde Contents: RW |

---

## 5. Actions izni

`karanos` deposu → **Settings** → **Actions** → **General**:

- **Actions permissions**: `Allow all actions and reusable workflows`
- **Workflow permissions**: `Read and write permissions` (Releases'e ISO
  yükleyebilmesi için) → **Save**

---

## 6. Release'e ne yüklenecek, adlandırma kuralı

Sürüm etiketi attığında (`git tag v1.0 && git push origin v1.0`) Actions
otomatik derler ve `karanos` deposunun **Releases** bölümüne şunları koyar:

```
karanos-1.0-amd64.iso            ← ISO'nun kendisi
karanos-1.0-amd64.iso.sha256     ← sha256 özeti (tek satır)
karanos-1.0-amd64.iso.zsync      ← isteğe bağlı, kısmi indirme için
SHA256SUMS                       ← tüm dosyaların özeti bir arada
```

**Adlandırma kuralı:** `karanos-<sürüm>-<mimari>.iso`
Sürüm etiketten gelir: `v1.0` → `1.0`, `v1.3.2` → `1.3.2`.
Mimari şimdilik hep `amd64`.

Kullanıcının indirme adresi:
```
https://github.com/KARANKOYU/karanos/releases/latest/download/karanos-1.0-amd64.iso
```

---

## 7. Katalog dosyası — ad, depo, adres

`karanos-catalog` deposunun içi şöyle olacak (13. aşamada Actions dolduracak,
ama yapısını şimdiden bilmen iyi):

```
karanos-catalog/
├── .nojekyll
├── version.json          ← küçük dosya: {"version": 7, "sha256": "..."}
├── catalog.json          ← asıl katalog (uygulamalar, kategoriler, türler)
└── icons/
    ├── vscode.png
    ├── steam.png
    └── ...               ← 64×64 PNG
```

| Dosya | İndirileceği adres |
|---|---|
| Sürüm kontrolü | `https://karankoyu.github.io/karanos-catalog/version.json` |
| Katalog | `https://karankoyu.github.io/karanos-catalog/catalog.json` |
| İkonlar | `https://karankoyu.github.io/karanos-catalog/icons/<ad>.png` |

Sistemdeki yeri: `/var/cache/karanos/store/`

Mağaza her açılışta önce `version.json`'a bakar (birkaç yüz bayt). Sürüm
numarası yerel kopyadan büyükse `catalog.json`'ı indirir ve `sha256`'sını
doğrular. İnternet yoksa yerel kopyayı kullanır, hiç yoksa
`store.catalog_failed` mesajını gösterir ama `apt-cache` araması yine çalışır.

**Yeni uygulama eklemek:** `karanos-catalog` deposundaki `catalog.json`'a bir
kayıt ekle, `version.json`'daki sayıyı bir artır, commit'le. Sistem
güncellemesi gerekmez, kullanıcılar bir sonraki mağaza açılışında görür.

---

## 8. APT deposunun sistemdeki karşılığı

Kurulu Karan OS'ta şu iki dosya olacak (`karanos-desktop` paketi koyacak):

```
/usr/share/keyrings/karanos-archive-keyring.gpg
/etc/apt/sources.list.d/karanos.sources
```

`karanos.sources` içeriği:

```
Types: deb
URIs: https://karankoyu.github.io/karanos-repo
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/karanos-archive-keyring.gpg
```

---

## Kontrol listesi

Bunları yaptıysan hazırsın:

- [ ] `karanos-repo` deposu açıldı (public)
- [ ] `karanos-catalog` deposu açıldı (public)
- [ ] Her ikisinde GitHub Pages `main` / root olarak açıldı
- [ ] Her ikisine `.nojekyll` dosyası eklendi
- [ ] GPG anahtarı üretildi
- [ ] `karanos` deposuna `GPG_PRIVATE_KEY` secret'ı eklendi
- [ ] `karanos` deposuna `GPG_KEY_ID` secret'ı eklendi
- [ ] `karanos` deposuna `REPO_TOKEN` secret'ı eklendi
- [ ] Actions workflow permissions = Read and write
- [ ] `assets/boot/boot-image.png` konuldu
- [ ] `assets/boot/boot-sound.mp3` konuldu

> **Aciliyet sırası:** ISO'nun ilk derlemesi için hiçbiri şart değil — 1.
> aşamayı bunlar olmadan da derleyip test edebilirsin. `boot-image.png` +
> `boot-sound.mp3` 3. aşamada, GPG + `REPO_TOKEN` + iki yeni depo 13. aşamada
> lazım olacak.
