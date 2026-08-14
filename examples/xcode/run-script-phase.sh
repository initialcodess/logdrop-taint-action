#!/usr/bin/env bash
#
# Xcode "Run Script" build fazı — her derlemede kendi kodunu tara.
#
# Kurulum: Target → Build Phases → + → New Run Script Phase → bu dosyanın
# içeriğini yapıştırın (ya da: bash "${SRCROOT}/examples/xcode/run-script-phase.sh").
#
# LİSANS: Anahtarı Xcode şemasına ortam değişkeni olarak ekleyin ya da
# ~/.logdrop/license dosyasında tutun (aşağıda ikisi de destekleniyor).
#
# NOT: Bulguları Xcode'un uyarı listesinde göstermek için `warning:` biçiminde
# yazdırıyoruz — böylece derleme günlüğünde tıklanabilir satırlar olarak çıkar.
set -euo pipefail

BIN_DIR="$HOME/.logdrop/bin"
BIN="$BIN_DIR/logdrop-taint"

# Anahtar: ortam değişkeni yoksa dosyadan oku.
if [ -z "${LOGDROP_LICENSE:-}" ] && [ -f "$HOME/.logdrop/license" ]; then
  LOGDROP_LICENSE="$(cat "$HOME/.logdrop/license")"
  export LOGDROP_LICENSE
fi

if [ ! -x "$BIN" ]; then
  echo "warning: LogDrop Taint kurulu değil — examples/install-logdrop-taint.sh çalıştırın."
  exit 0     # Derlemeyi kurulum eksikliği yüzünden kırma.
fi

# Xcode derlemesini bulgu yüzünden KIRMIYORUZ: geliştirici makinesinde tarama bir
# uyarı katmanıdır, kapı değil. Kapı CI'da (--fail-on-findings) uygulanır.
set +e
OUT="$("$BIN" "${SRCROOT}/Sources" --repo-root "${SRCROOT}" --sarif "${DERIVED_FILE_DIR}/logdrop.sarif" --verbose 2>&1)"
STATUS=$?
set -e

case $STATUS in
  0) echo "LogDrop Taint: bulgu yok." ;;
  2) echo "warning: LogDrop lisansı geçersiz ya da süresi dolmuş." ;;
  3) echo "warning: .logdrop.json ayar dosyasında hata var." ;;
esac

# "  [KURAL] yol:satır — mesaj" satırlarını Xcode uyarısına çevir.
echo "$OUT" | sed -n 's|^  \[\([^]]*\)\] \([^:]*\):\([0-9]*\) — \(.*\)$|\2:\3: warning: [\1] \4|p'
