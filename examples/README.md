# Entegrasyon örnekleri

LogDrop Taint **GitHub'a bağlı değildir.** Analizci tek bir çalıştırılabilir
dosyadır ve yalnız macOS ister — Xcode, Swift kurulumu, Homebrew gerekmez.

## Model: her yerde aynı üç adım

```
1. İNDİR      →  sürüme göre, bir kez (önbelleğe alınabilir)
2. DOĞRULA    →  SHA-256; bozuk/değiştirilmiş ikiliyle tarama yapılmaz
3. ÇALIŞTIR   →  çıkış kodu kararı verir
```

İlk iki adım [`install-logdrop-taint.sh`](install-logdrop-taint.sh) içinde;
aşağıdaki bütün örnekler onu çağırıyor. GitHub Actions kullanıyorsanız buna bile
gerek yok, Action ikisini de kendisi yapar.

## Çıkış kodları — her entegrasyonun dayandığı sözleşme

| Kod | Anlamı | CI ne yapmalı |
|---|---|---|
| `0` | Temiz | Devam |
| `1` | Bulgu var (`--fail-on-findings` ile) | Derlemeyi kır, PR'ı engelle |
| `2` | Lisans yok / bozuk / süresi dolmuş | Kır, ama "kodunuzda açık var" DEME |
| `3` | `.logdrop.json` ayar dosyasında hata | Kır, ayar dosyasını düzelt |

`1` ile `2`'yi ayırmak önemli: lisansı biten geliştiriciye "kodunda güvenlik açığı
var" demek yanlış yere bakmasına yol açar.

## Örnekler

| Sistem | Dosya | Not |
|---|---|---|
| **GitHub Actions** | [ana README](../README.md) | Action her şeyi yapar; indirme/doğrulama dahil |
| **CircleCI** | [`circleci/config.yml`](circleci/config.yml) | macOS executor gerekir (ücretli planlarda) |
| **GitLab CI** | [`gitlab/.gitlab-ci.yml`](gitlab/.gitlab-ci.yml) | macOS runner gerekir; kendi Mac'iniz ücretsiz |
| **Jenkins** | [`jenkins/Jenkinsfile`](jenkins/Jenkinsfile) | `macos` etiketli agent |
| **Bitrise** | [`bitrise/bitrise.yml`](bitrise/bitrise.yml) | Zaten macOS yığını; ek gereksinim yok |
| **fastlane** | [`fastlane/Fastfile`](fastlane/Fastfile) | Derlemeden önce koşturun |
| **Xcode** | [`xcode/run-script-phase.sh`](xcode/run-script-phase.sh) | Bulgular Xcode uyarısı olarak görünür |
| **Yerel makine** | [`local/scan.sh`](local/scan.sh) | Push etmeden önce kendi kodunuzu tarayın |

## Lisans anahtarı nereye konur

Her zaman **`LOGDROP_LICENSE` ortam değişkenine**, ve her zaman o sistemin
gizli-değer deposundan gelmeli:

| Sistem | Yer |
|---|---|
| GitHub Actions | Repository secrets |
| CircleCI | Project Settings → Environment Variables |
| GitLab | Settings → CI/CD → Variables (**Masked** işaretleyin) |
| Jenkins | Credentials → Secret text |
| Bitrise | Secrets |
| Yerel | `export LOGDROP_LICENSE=...` ya da `~/.logdrop/license` |

Anahtarı yapılandırma dosyasına yazmayın: komut satırı argümanları koşu
günlüklerinde ve süreç listesinde görünebilir, o yüzden örneklerin hepsi ortam
değişkeni kullanıyor.

## macOS gerekliliği

Analizci Apple sistem kütüphanelerine bağlı olduğu için macOS'ta çalışır. Pratikte
bu bir kısıt değil: iOS kaynağı zaten macOS'ta derleniyor, yani o makine hâlihazırda
elinizde.

**Maliyet notu:** bulut sağlayıcıları macOS makineyi Linux'tan belirgin biçimde
pahalı ücretlendirir (GitHub'da ~10 kat). Tarama saniyeler sürdüğü için ek maliyet
küçüktür, ama kendi Mac'inizi runner olarak kullanırsanız **sıfırlanır** — ve iOS
ekiplerinin çoğunda zaten bir build makinesi vardır.
