#!/usr/bin/env bash
#
# Send a finished SARIF report to the LogDrop panel.
#
# WHY THIS IS A SEPARATE SCRIPT, AND NOT PART OF THE ANALYZER
#
# The analyzer contacts no server. It verifies its licence offline, counts no
# usage and tells nobody it ran — that is the product's central promise, and a
# scanner that phones home cannot make it. Reporting is therefore a step you can
# see, run by you, on a report that already exists.
#
# The GitHub Action does this same POST internally when you give it `panel-url`.
# Everywhere else — CircleCI, GitLab, Jenkins, Bitrise, fastlane, a laptop — this
# script is that step.
#
# USAGE
#   PANEL_URL=https://panel.example.com \
#   LOGDROP_LICENSE="LOGDROP...." \
#   BUNDLE_ID=com.company.app \
#     ./report-to-panel.sh logdrop-taint.sarif
#
# WITHOUT PANEL_URL IT DOES NOTHING, and says so. Recipes can therefore include
# the step unconditionally: a customer who never sets PANEL_URL never sends
# anything, and one who sets it needs no further edits.
#
# IT NEVER FAILS YOUR BUILD. The scan already ran and its exit code already said
# what it found; a panel under maintenance must not turn that red afterwards.
set -uo pipefail

SARIF="${1:-logdrop-taint.sarif}"

if [ -z "${PANEL_URL:-}" ]; then
  echo "LogDrop: PANEL_URL is not set — the report stays on this machine."
  exit 0
fi

if [ ! -f "$SARIF" ]; then
  echo "LogDrop: no report at '$SARIF' — nothing to send." >&2
  exit 0
fi

if [ -z "${LOGDROP_LICENSE:-}" ]; then
  echo "LogDrop: PANEL_URL is set but LOGDROP_LICENSE is not; the panel identifies you by your key." >&2
  exit 0
fi

if [ -z "${BUNDLE_ID:-}" ]; then
  echo "LogDrop: PANEL_URL is set but BUNDLE_ID is not; the panel needs it to know which app this is." >&2
  exit 0
fi

# Which app, which build. Everything here is optional context — the panel works
# without it, and reads WHICH CUSTOMER this belongs to from the licence key, not
# from anything sent here.
APP_NAME="${APP_NAME:-$(basename "$PWD")}"
VERSION="${VERSION:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}"
COMMIT="${COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"

URL="${PANEL_URL%/}/api/reports/sarif"
BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT

# No `|| echo 000` on the end of this: when curl cannot connect, -w already
# prints "000", and the two together produce "000000" — which matches no branch
# below, so an unreachable panel would fall through to the catch-all and report a
# nonsense status code.
CODE=$(curl -sS -o "$BODY" -w '%{http_code}' -X POST "$URL" \
  -H "Authorization: Bearer $LOGDROP_LICENSE" \
  -F "sarif=@$SARIF" \
  -F "bundle_id=$BUNDLE_ID" \
  -F "app_name=$APP_NAME" \
  -F "version=$VERSION" \
  -F "commit=$COMMIT")
CODE=${CODE:-000}

case "$CODE" in
  200|201)
    echo "LogDrop: report sent to the panel."
    ;;
  401)
    echo "LogDrop: the panel refused the licence key (401). Check the key." >&2
    ;;
  403)
    # Two different causes wear this code: expired, and revoked. "Renew it" is
    # wrong advice for a revocation, so the panel's own words are shown instead.
    echo "LogDrop: the panel refused the licence (403): $(head -c 300 "$BODY")" >&2
    echo "        It may be expired or revoked — satis@initialcode.io" >&2
    ;;
  400|422)
    echo "LogDrop: the panel rejected the request ($CODE): $(head -c 300 "$BODY")" >&2
    echo "        Check BUNDLE_ID and the SARIF file." >&2
    ;;
  413)
    echo "LogDrop: the report exceeded the panel's size limit (413)." >&2
    echo "        Narrow the scan with 'exclude' in .logdrop.json." >&2
    ;;
  503)
    echo "LogDrop: the panel is unavailable (503). The scan was unaffected." >&2
    ;;
  000)
    echo "LogDrop: the panel could not be reached ($PANEL_URL). The scan was unaffected." >&2
    ;;
  *)
    echo "LogDrop: the panel returned $CODE: $(head -c 300 "$BODY")" >&2
    ;;
esac

# Always 0. What the scan found was decided by the scan.
exit 0
