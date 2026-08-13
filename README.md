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

## LogDrop paneline gönderme (isteğe bağlı)

Bulguları geçmişiyle birlikte izlemek, aynı uygulamanın ikili (Katman 1) ve kaynak
taramalarını tek ekranda görmek ve "bu yanlış alarm" kararlarını taramalar arasında
taşımak isterseniz raporu panele gönderebilirsiniz:

```yaml
- uses: initialcodess/logdrop-taint-action@v1
  with:
    license: ${{ secrets.LOGDROP_LICENSE }}
    path: Sources
    bundle-id: com.sirket.uygulama       # panele gönderirken zorunlu
    panel-url: https://panel.logdrop.io
```

**Varsayılan kapalıdır.** `panel-url` yazmazsanız hiçbir şey gönderilmez ve tarama
tamamen yerel kalır.

Gönderildiğinde giden tek şey **SARIF**'tir: kural kimliği, dosya yolu ve satır
numarası. Kaynak kod metni ne SARIF'e girer ne de gönderilir. Yine de dosya
*yolları* makineden çıkar; karar bu yüzden sizindir.

Panel erişilemezse ya da anahtarı kabul etmezse **derlemeniz kırılmaz** — uyarı
düşer, tarama sonucu (satır içi uyarılar, iş özeti, çıkış kodu) etkilenmez.

## Kendi kod tabanınıza göre ayarlama

Depo köküne `.logdrop.json` koyarak kuralları kendi projenize uyarlayabilirsiniz.
**Yanlış alarmı gidermenin birincil yolu budur.**

```json
{
  "sanitizers": { "guvenliHale": ["user-input"], "maskeleEposta": ["pii"] },
  "sources":    { "tcKimlik": "pii", "musteriEposta": "pii" },
  "sinks":      { "gizli": { "rule": "SWIFT-TAINT-PII-LOG", "accepts": ["pii"] } },
  "passthrough": ["normalizeEt"],
  "exclude":     ["Pods/", "Generated/", "Tests/"]
}
```

| Alan | Ne işe yarar |
|---|---|
| `sanitizers` | Sizin temizleyici fonksiyonunuz; hangi kirlilik türünü giderdiğini yazın. Bulgu üretilmez. |
| `sources` | Sizin kişisel-veri alanlarınız (`tcKimlik` gibi). |
| `sinks` | Sizin sarmalayıcınız (kendi log sınıfınız gibi) — hangi kurala bağlanacağını yazın. |
| `passthrough` | Veriyi dönüştüren ama kirliliği koruyan kendi yardımcılarınız. |
| `exclude` | Taranmayacak yollar (`Pods/` gibi). Yol bu parçayı içeriyorsa atlanır. |

Etiketler: `user-input`, `hardcoded-secret`, `pii`.

Hatalı bir ayar **sessizce yok sayılmaz**: tanınmayan alan, kural ya da etiket
tarama başlamadan reddedilir ve mesaj kullanılabilir olanları listeler.

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
| `panel-url` | *(boş)* | LogDrop paneline rapor gönderilecekse panel adresi. **Boşsa hiçbir şey gönderilmez.** |
| `bundle-id` | *(boş)* | Uygulama kimliği. `panel-url` verildiyse zorunlu. |
| `analyzer-version` | bu sürümle test edilmiş sürüm | Değiştirmeniz gerekmez. |

**Çıktılar:** `findings` (bulgu sayısı), `sarif-file`.

## Çıkış kodları

Üçü ayrı anlam taşır; karıştırılmaz:

| Kod | Anlamı |
|---|---|
| `0` | Temiz — bulgu yok |
| `1` | Bulgu var (yalnız `fail-on-findings: "true"` ile) |
| `2` | Lisans sorunu (yok / bozuk / süresi dolmuş) |
| `3` | `.logdrop.json` ayar dosyasında hata |

## Lisans

LogDrop Taint **ticari bir üründür**; süreli bir anahtarla çalışır. Bu depo
Action'ı ve derlenmiş analizciyi dağıtır — açık kaynak değildir, analizcinin
kaynak kodu bu depoda bulunmaz.

Anahtar **çevrimdışı** doğrulanır: program hiçbir sunucuya bağlanmaz, kullanımınızı
saymaz, kimseye rapor göndermez. Süre dolmadan 14 gün önce uyarır.

Anahtar edinmek için: **satis@initialcode.io**

---
*Initial Code Software Solutions*
