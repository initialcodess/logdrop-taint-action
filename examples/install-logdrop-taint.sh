#!/usr/bin/env bash
#
# LogDrop Taint kurulumu — indirir, BÜTÜNLÜĞÜNÜ DOĞRULAR, kullanıma hazır eder.
#
# GitHub Actions dışındaki bütün entegrasyonlar (CircleCI, GitLab, Jenkins,
# Bitrise, fastlane, yerel makine) aynı üç adımı yapar. O yüzden tek bir betik:
# her CI bunu çağırır, kendi diliyle sarmalar.
#
# Kullanım:
#   ./install-logdrop-taint.sh                 # varsayılan sürüm, ./bin altına
#   LOGDROP_VERSION=v1.4.0 ./install-logdrop-taint.sh
#   LOGDROP_BIN_DIR=/usr/local/bin ./install-logdrop-taint.sh
#
# Çıktı: $LOGDROP_BIN_DIR/logdrop-taint
set -euo pipefail

VERSION="${LOGDROP_VERSION:-v1.4.0}"
BIN_DIR="${LOGDROP_BIN_DIR:-$PWD/bin}"
REPO="initialcodess/logdrop-taint-action"

# Sürüm biçimini doğrula: yanlış bir değer, anlaşılmaz bir 404'e dönüşür.
if ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "hata: LOGDROP_VERSION 'v1.2.3' biçiminde olmalı (gelen: '$VERSION')" >&2
  exit 1
fi

# macOS gerekir: analizci Apple sistem kütüphanelerine bağlı. Xcode ya da Swift
# kurulumu GEREKMEZ — yalnız işletim sistemi.
if [ "$(uname -s)" != "Darwin" ]; then
  echo "hata: LogDrop Taint macOS gerektirir (bulunan: $(uname -s))." >&2
  echo "      Swift kurulumu ya da Xcode gerekmez, ama işletim sistemi macOS olmalı." >&2
  exit 1
fi

mkdir -p "$BIN_DIR"

# Aynı sürüm zaten kuruluysa tekrar indirme (CI önbelleğiyle iyi çalışır).
if [ -x "$BIN_DIR/logdrop-taint" ] && "$BIN_DIR/logdrop-taint" --version 2>/dev/null | grep -qx "${VERSION#v}"; then
  echo "LogDrop Taint ${VERSION} zaten kurulu: $BIN_DIR/logdrop-taint"
  exit 0
fi

ARCHIVE="logdrop-taint-${VERSION}-macos-universal.tar.gz"
BASE="https://github.com/${REPO}/releases/download/${VERSION}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "İndiriliyor: ${VERSION}"
curl -fsSL --retry 3 --retry-delay 2 -o "$WORK/$ARCHIVE" "$BASE/$ARCHIVE"
curl -fsSL --retry 3 --retry-delay 2 -o "$WORK/$ARCHIVE.sha256" "$BASE/$ARCHIVE.sha256"

# Bütünlük kontrolü ATLANMAZ: yarım inen ya da değiştirilmiş bir ikiliyle kod
# taramak, taramamaktan kötüdür — yanlış bir güven verir.
echo "Bütünlük doğrulanıyor (SHA-256)"
( cd "$WORK" && shasum -a 256 -c "$ARCHIVE.sha256" )

tar -xzf "$WORK/$ARCHIVE" -C "$WORK"
mv "$WORK/logdrop-taint" "$BIN_DIR/logdrop-taint"
chmod +x "$BIN_DIR/logdrop-taint"

echo "Kuruldu: $BIN_DIR/logdrop-taint ($("$BIN_DIR/logdrop-taint" --version))"
