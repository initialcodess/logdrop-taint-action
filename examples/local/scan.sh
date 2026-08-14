#!/usr/bin/env bash
#
# Geliştirici makinesinde tarama — push etmeden önce kendi kodunu kontrol et.
#
#   export LOGDROP_LICENSE="LOGDROP...."
#   ./examples/local/scan.sh Sources
#
# CI'a hiç ihtiyaç yok. Aynı ikili, aynı kurallar, aynı çıkış kodları.
set -euo pipefail

TARGET="${1:-.}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Analizciyi kur (zaten kuruluysa atlar).
LOGDROP_BIN_DIR="${LOGDROP_BIN_DIR:-$HOME/.logdrop/bin}"
export LOGDROP_BIN_DIR
"$HERE/../install-logdrop-taint.sh"

echo
# `set -e` açıkken sıfırdan farklı çıkış betiği anında sonlandırır — ve bulgu
# bulmak tam olarak sıfırdan farklı çıkıştır. Kodu okuyup anlamlandırabilmek için
# bu çağrı boyunca kapatıyoruz.
set +e
"$LOGDROP_BIN_DIR/logdrop-taint" "$TARGET" \
  --sarif "logdrop-taint.sarif" \
  --verbose \
  --fail-on-findings
status=$?
set -e

# Çıkış kodları ayrı anlam taşır — hangisi olduğunu insan diliyle söyle.
case $status in
  0) echo; echo "Temiz: bulgu yok." ;;
  1) echo; echo "Bulgu var. Ayrıntılı rapor: logdrop-taint.sarif"
     echo "SARIF'i VS Code'un 'SARIF Viewer' eklentisiyle açabilirsiniz." ;;
  2) echo; echo "Lisans sorunu. LOGDROP_LICENSE tanımlı mı, süresi dolmuş mu?" ;;
  3) echo; echo ".logdrop.json ayar dosyanızda hata var (yukarıdaki mesaja bakın)." ;;
esac
exit $status
