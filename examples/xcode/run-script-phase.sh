#!/usr/bin/env bash
#
# An Xcode "Run Script" build phase — scan your own code on every build.
#
# Setup: Target → Build Phases → + → New Run Script Phase → paste the contents of
# this file (or: bash "${SRCROOT}/examples/xcode/run-script-phase.sh").
#
# LICENCE: add the key to your Xcode scheme as an environment variable, or keep it
# in ~/.logdrop/license (both are supported below).
#
# NOTE: findings are printed in `warning:` form so they land in Xcode's warning list
# and appear as clickable lines in the build log.
set -euo pipefail

BIN_DIR="$HOME/.logdrop/bin"
BIN="$BIN_DIR/logdrop-taint"

# The key: fall back to the file when the environment variable is absent.
if [ -z "${LOGDROP_LICENSE:-}" ] && [ -f "$HOME/.logdrop/license" ]; then
  LOGDROP_LICENSE="$(cat "$HOME/.logdrop/license")"
  export LOGDROP_LICENSE
fi

if [ ! -x "$BIN" ]; then
  echo "warning: LogDrop Taint is not installed — run examples/install-logdrop-taint.sh."
  exit 0     # Never fail a build just because it is not installed.
fi

# We do NOT fail the Xcode build over findings: on a developer machine the scan is a
# warning layer, not a gate. The gate belongs in CI (--fail-on-findings).
set +e
OUT="$("$BIN" "${SRCROOT}/Sources" --repo-root "${SRCROOT}" --sarif "${DERIVED_FILE_DIR}/logdrop.sarif" --verbose 2>&1)"
STATUS=$?
set -e

case $STATUS in
  0) echo "LogDrop Taint: no findings." ;;
  2) echo "warning: the LogDrop licence is invalid or expired." ;;
  3) echo "warning: there is an error in the .logdrop.json config file." ;;
esac

# Turn "  [RULE] path:line — message" lines into Xcode warnings.
echo "$OUT" | sed -n 's|^  \[\([^]]*\)\] \([^:]*\):\([0-9]*\) — \(.*\)$|\2:\3: warning: [\1] \4|p'
