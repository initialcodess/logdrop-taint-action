#!/usr/bin/env bash
#
# Scanning on a developer machine — check your own code before you push.
#
#   export LOGDROP_LICENSE="LOGDROP...."
#   ./examples/local/scan.sh Sources
#
# No CI needed at all. Same binary, same rules, same exit codes.
set -euo pipefail

TARGET="${1:-.}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install the analyzer (skipped if already installed).
LOGDROP_BIN_DIR="${LOGDROP_BIN_DIR:-$HOME/.logdrop/bin}"
export LOGDROP_BIN_DIR
"$HERE/../install-logdrop-taint.sh"

echo
# With `set -e` a non-zero exit ends the script immediately — and finding something
# is exactly a non-zero exit. We turn it off around this call so the code can be
# read and acted on.
set +e
"$LOGDROP_BIN_DIR/logdrop-taint" "$TARGET" \
  --sarif "logdrop-taint.sarif" \
  --verbose \
  --fail-on-findings
status=$?
set -e

# Send it on, if a panel is configured. Nothing happens without PANEL_URL, so this
# line is harmless on a laptop that only ever scans locally.
"$HERE/../report-to-panel.sh" logdrop-taint.sarif

# The exit codes mean different things — say which one it is in plain language.
case $status in
  0) echo; echo "Clean: no findings." ;;
  1) echo; echo "Findings. Full report: logdrop-taint.sarif"
     echo "You can open the SARIF with VS Code's 'SARIF Viewer' extension." ;;
  2) echo; echo "Licence problem. Is LOGDROP_LICENSE set, and has it expired?" ;;
  3) echo; echo "There is an error in your .logdrop.json (see the message above)." ;;
esac
exit $status
