# LogDrop Taint — GitHub Action

iOS/Swift **kaynak kodunda taint (veri akışı) analizi**. Kullanıcıdan gelen ya da
gizli olması gereken bir verinin, kodun içinde yolculuk edip tehlikeli bir yere
temizlenmeden ulaşıp ulaşmadığını izler.

**Kaynak kodunuz runner'dan çıkmaz.** Tarama yerelde koşar; dışarıya yalnız bulgu
listesi (kural + dosya + satır) üretilir. Kaynak metni ne rapora ne de başka bir
yere gider.

## Kullanım

```yaml
name: Güvenlik taraması
on: [pull_request]

jobs:
  taint:
    runs-on: macos-15
    permissions:
      contents: read
      security-events: write   # yalnız Code Scanning'e yükleyecekseniz
    steps:
      - uses: actions/checkout@v4
      - uses: initialcodess/logdrop-taint-action@v1
        with:
          license: ${{ secrets.LOGDROP_LICENSE }}
          path: Sources
          fail-on-findings: "true"
```

`macos-15` gerekir (Swift 6+). Analizci hazır derlenmiş indirilir — projenizde
Swift derlemesi yapılmaz.

## Bulguları nerede görürsünüz

Üçü de **ücretsizdir ve her GitHub planında** çalışır:

1. **PR'da satır içi kutu** — bulgu, "Files changed" görünümünde ilgili satırın
   üstünde belirir.
2. **İş özeti** — koşu sayfasında konum / kural / bulgu tablosu.
3. **CI kapısı** — `fail-on-findings: "true"` ise bulgu varsa PR birleştirilemez.

Deponuzda **Code Scanning** açıksa SARIF oraya da yüklenir. Bu özellik public
depolarda ücretsiz, private depolarda GitHub'ın ücretli Code Security lisansına
bağlıdır; lisans yoksa adım uyarı verip geçer, **build'i kırmaz**.

## Ne bulur

| Senaryo | CWE |
|---|---|
| Kullanıcı/ağ verisi `WKWebView`'a temizlenmeden akıyor | CWE-79 |
| Koda gömülü sabit anahtar bir kripto API'sine akıyor | CWE-321 |
| Kişisel veri (e-posta, telefon, parola, kimlik) log'a yazılıyor | CWE-532 |

Akışı fonksiyonlar arasında da izler ve `escapeHTML(...)` gibi temizleyicilerden
geçen veriyi bulgu saymaz. Temizleme **etiket bazlıdır**: HTML kaçışlaması
enjeksiyonu keser ama veriyi kişisel olmaktan çıkarmaz — kaçışlanmış bir e-posta
log'a yazılırsa hâlâ bulgudur.

## Girdiler

| Girdi | Varsayılan | Açıklama |
|---|---|---|
| `license` | — | **Zorunlu.** Lisans anahtarı; secret olarak saklayın. |
| `path` | `.` | Taranacak dosya ya da dizin. |
| `fail-on-findings` | `false` | Bulgu varsa adımı kırar. |
| `annotations` | `true` | PR'da satır içi kutular. |
| `upload-sarif` | `true` | Code Scanning'e yükleme dener. |
| `sarif-file` | `logdrop-taint.sarif` | SARIF çıktı yolu. |
| `repo-root` | `github.workspace` | SARIF yollarının göreceleneceği kök. |
| `analyzer-version` | bu sürümle test edilmiş sürüm | Değiştirmeniz gerekmez. |

**Çıktılar:** `findings` (bulgu sayısı), `sarif-file`.

## Çıkış kodları

Üçü ayrı anlam taşır; karıştırılmaz:

| Kod | Anlamı |
|---|---|
| `0` | Temiz — bulgu yok |
| `1` | Bulgu var (yalnız `fail-on-findings: "true"` ile) |
| `2` | Lisans sorunu (yok / bozuk / süresi dolmuş) |

## Lisans

LogDrop Taint **ticari bir üründür**; süreli bir anahtarla çalışır. Bu depo
Action'ı ve derlenmiş analizciyi dağıtır — açık kaynak değildir, analizcinin
kaynak kodu bu depoda bulunmaz.

Anahtar **çevrimdışı** doğrulanır: program hiçbir sunucuya bağlanmaz, kullanımınızı
saymaz, kimseye rapor göndermez. Süre dolmadan 14 gün önce uyarır.

Anahtar edinmek için: **satis@initialcode.io**

---
*Initial Code Software Solutions*
