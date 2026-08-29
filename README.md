# LogDrop Taint — GitHub Action

**Taint (data-flow) analysis for iOS/Swift source code.** It tracks whether data
that came from a user — or data that was meant to stay secret — travels through
your code and reaches somewhere dangerous without being sanitised.

**Your codebase never leaves the runner.** The scan runs locally. What goes into
the report is the list of findings: the rule, the file, the line — and **the
offending line plus a few lines around it**, so the problem is legible (exactly
what GitHub Code Scanning does). The whole file, the other files scanned and the
rest of your code are never sent.

If you do not want even that, set `snippets: "false"`: the report then carries only
the rule and `file:line`, and not a single line of your code leaves.

The Android counterpart is
[logdrop-taint-android-action](https://github.com/initialcodess/logdrop-taint-android-action).
Both produce the same report shape and read the same `.logdrop.json` and
suppressions file, so a team shipping both apps sees one kind of finding and
records a judgement once.

## Usage

```yaml
name: Security scan
on: [pull_request]

jobs:
  taint:
    runs-on: macos-15
    permissions:
      contents: read
      security-events: write   # only if you upload to Code Scanning
    steps:
      - uses: actions/checkout@v4
      - uses: initialcodess/logdrop-taint-action@v1
        with:
          license: ${{ secrets.LOGDROP_LICENSE }}
          path: Sources
          fail-on-findings: "true"
```

`macos-15` is required (Swift 6+). The analyzer is downloaded prebuilt — nothing
is compiled in your project.

## Using it without GitHub (your machine, your server)

The analyzer is **a single executable** and needs only macOS — no Xcode, no Swift
toolchain, no Homebrew. So you are not tied to GitHub Actions:

```bash
# Download it once (change the version as needed)
V=v1.23.0
curl -fsSL -O "https://github.com/initialcodess/logdrop-taint-action/releases/download/$V/logdrop-taint-$V-macos-universal.tar.gz"
curl -fsSL -O "https://github.com/initialcodess/logdrop-taint-action/releases/download/$V/logdrop-taint-$V-macos-universal.tar.gz.sha256"
shasum -a 256 -c "logdrop-taint-$V-macos-universal.tar.gz.sha256"   # integrity
tar -xzf "logdrop-taint-$V-macos-universal.tar.gz"

# Run it
export LOGDROP_LICENSE="LOGDROP...."
./logdrop-taint Sources --sarif report.sarif --verbose --fail-on-findings
```

Where that helps:

- **On a developer machine** — scan your own code before you push.
- **On your own build server** (Jenkins, TeamCity, Bitrise, your Mac mini): put
  the two lines above into your build step. Exit code `1` means findings.
- **In a fastlane lane or an Xcode Run Script phase** — same binary, same exit codes.
- **On a self-hosted GitHub runner** — this action works as-is and GitHub's
  per-minute billing does not apply.

The `--sarif` output is standard SARIF 2.1.0; open it in Xcode or VS Code's SARIF
viewer, or feed it into your own dashboard.

**Ready-made recipes:** [`examples/`](examples/) has working setups for CircleCI,
GitLab CI, Jenkins, Bitrise, fastlane, an Xcode build phase and a local machine —
all built on the same install script.

## Where you see the findings

All three are **free and work on every GitHub plan**:

1. **An inline box on the pull request** — the finding appears above the relevant
   line in the "Files changed" view.
2. **The job summary** — a location / rule / finding table on the run page.
3. **The CI gate** — with `fail-on-findings: "true"`, findings block the merge.

If **Code Scanning** is enabled on your repository, the SARIF is uploaded there as
well. That feature is free on public repositories and depends on GitHub's paid Code
Security licence on private ones; without a licence the step warns and moves on —
it **does not break the build**.

## Test code is skipped

Test fixtures are where fake credentials live: WordPress-iOS writes
`blog.password = "test"` in five different test helpers, and nothing in the code
distinguishes that from the real thing. Files under a `Tests`/`UITests` directory,
or named `*Tests.swift` / `*Spec.swift`, are left out by default.

It is not done quietly — the step prints what it skipped:

```
Skipped 591 test file(s). Use --include-tests to scan them.
```

A file named directly on the command line is always scanned, whatever it is called.

## What it finds

| Scenario | CWE |
|---|---|
| User, network or deep-link data reaches `WKWebView` unsanitised | CWE-79 |
| A key hardcoded in the source reaches a crypto API | CWE-321 |
| Personal data (email, phone, password, card number, PIN, SSN, passport, date of birth) is written to a log | CWE-532 |
| Personal data is stored in the clear (a local database, `UserDefaults`, Core Data) | CWE-312 |
| User or network data is interpolated into a SQL query instead of being bound | CWE-89 |
| User or network data is built into an `NSPredicate` format string instead of being passed as an argument | CWE-943 |
| Personal data or a credential is copied to the system pasteboard, which every other app can read | CWE-200 |

What a value is also comes from the name it is read from: `cvvTextField.text` is a
CVV, while `searchTextField.text` is only user input and produces nothing — logging
your own search term is not a leak.

It follows flows across functions too, and does not report data that passed through
a sanitiser such as `escapeHTML(...)`. Sanitising is **label-specific**: escaping
HTML stops the injection but does not stop the data being personal — an escaped
email written to a log is still a finding.

## Sending reports to the LogDrop panel (optional)

If you want to track findings over time, see the binary (Layer 1) and source scans
for the same app on one screen, and carry "this is a false positive" decisions
across scans, you can send the report to the panel:

```yaml
- uses: initialcodess/logdrop-taint-action@v1
  with:
    license: ${{ secrets.LOGDROP_LICENSE }}
    path: Sources
    bundle-id: com.company.app           # required when sending to the panel
    panel-url: https://panel.logdrop.io
```

**Off by default.** Without `panel-url` nothing is sent and the scan stays entirely
local.

Sending needs three things together — `panel-url`, `license` and `bundle-id`. Miss
any one and nothing is sent. **`bundle-id` must be the id registered for that
project in the panel**: an id the panel does not recognise is refused and the step
fails, so a typo is loud rather than silent.

Not on GitHub Actions? Every recipe under [`examples/`](examples/) ends by calling
[`examples/report-to-panel.sh`](examples/report-to-panel.sh), which does the same
POST from CircleCI, GitLab, Jenkins, Bitrise, fastlane or a laptop. It does nothing
until you set all three of `PANEL_URL`, `LOGDROP_LICENSE` and `BUNDLE_ID`. If the
panel *rejects* a report — usually a bundle id not registered for your project —
the step fails, because a green step that sent nothing is worse than a red one. If
the panel is merely unreachable, it warns and your build is untouched.

The analyzer itself still contacts nothing: sending is a separate step on a report
that already exists, which is what keeps "the scanner never phones home" true
wherever you run it.

When it is sent, the only thing that goes is the **SARIF**: rule id, file path, line
number and (if enabled) the code of the offending line — so the panel can show the
faulty code with the relevant line highlighted. Turn the snippets off with
`snippets: "false"`, or stop the sending altogether by leaving `panel-url` unset.

If the panel is unreachable or refuses the key, **your build is not broken** — a
warning is emitted and the scan result (inline annotations, job summary, exit code)
is unaffected.

## Adapting it to your codebase

Put a `.logdrop.json` at your repository root to adapt the rules to your project.
This is how you teach the analyzer about **your** code — your sanitising function,
your field names, your logging wrapper. Clearing a single finding you have judged
and disagreed with is a different thing; see [Silencing a finding](#silencing-a-finding-you-have-judged).

```json
{
  "sanitizers":     { "makeSafe": ["user-input"], "maskEmail": ["pii"] },
  "sources":        { "nationalId": "pii", "customerEmail": "pii" },
  "sensitiveNames": { "sifre": "pii", "kartNo": "pii" },
  "sinks":          { "secret": { "rule": "SWIFT-TAINT-PII-LOG", "accepts": ["pii"] } },
  "passthrough":    ["normalise"],
  "exclude":        ["Pods/", "Generated/", "Tests/"]
}
```

| Field | What it does |
|---|---|
| `sanitizers` | Your own sanitising function; state which kind of taint it removes. No finding is produced past it. |
| `sources` | Your own personal-data fields (`nationalId` and the like). |
| `sensitiveNames` | Your own names for sensitive inputs. A value read from a name listed here counts as personal data — useful when your fields are not in English. |
| `sinks` | Your own wrapper (your logging class, say) — state which rule it maps to. |
| `passthrough` | Your own helpers that transform data but preserve taint. |
| `exclude` | Paths to skip (`Pods/` etc.). A path is skipped if it contains the fragment. |

Labels: `user-input`, `hardcoded-secret`, `pii`, `credential`.

A bad config is **not ignored silently**: an unrecognised field, rule or label is
rejected before the scan starts, and the message lists the valid ones.

## Silencing a finding you have judged

Sometimes a finding is real code and still not a problem for you. You should be able
to say so once and not be asked again.

That judgement lives in `.logdrop-suppressions.json` at your repository root, and it
is **written and signed by the LogDrop panel**. The analyzer verifies the signature
offline — it contacts nothing, here or anywhere else — and honours nothing it cannot
verify.

```json
{
  "version": 1,
  "suppressions": [
    {
      "fingerprint": "a3f1c0d92b74e518",
      "reason": "Test double; this password is not a real one",
      "by": "ayse@example.com",
      "at": "2026-08-26"
    }
  ],
  "signature": "…"
}
```

**Why signed rather than a file you write yourself.** Not to make it hard for you —
if you want the scan gone you can delete this step in one line. It is so that
silencing a finding costs a moment of thought. An unsigned file gets a line appended
the first time a build goes red, by whoever is in a hurry; nobody reviews it, and a
real leak gets silenced with the same keystroke as a false alarm. Going through the
panel means somebody said why, and it is written down.

The file stays readable and stays in your repository, so anyone reviewing a pull
request can see what is being silenced and object to it.

**What the signature covers:** which findings are silenced, and the expiry. It does
**not** cover `reason`, `by` or `at` — those are for whoever reads the diff, and
fixing a typo in a sentence must not invalidate the file.

**A silenced finding is not deleted.** It stays in the report, marked as suppressed
with your reason attached, so GitHub Code Scanning and the panel show it as closed
rather than as never having existed. The count says so plainly:

```
LogDrop Taint: 4 finding(s) (1 suppressed) → logdrop-taint.sarif
```

It does not fail the build.

**If the file cannot be verified, it is ignored and every finding is reported** — and
the reason is printed. A hand-edited file, a file signed with the wrong key, an
expired one: all of them say so out loud. Believing a finding is silenced when it is
not is the one outcome worth protecting you from.

**A judgement is about a line, not a line number.** Moving code around, adding an
import, reformatting: the suppression holds. Editing the offending line itself
releases it, and that is deliberate — the code you judged is no longer the code that
is there.

> **Not `exclude`.** `exclude` in `.logdrop.json` drops whole paths from the scan,
> unsigned, with nobody named. Used to clear one finding it also silences every
> future finding in that file, and nobody notices. It is for code that is not yours —
> vendored dependencies and the like. Every scan prints how many files it dropped and
> why, so a list that grows during a red build shows up in the log.

## Inputs

| Input | Default | Description |
|---|---|---|
| `license` | — | **Required.** Your licence key; keep it in a secret. |
| `path` | `.` | The file or directory to scan. |
| `fail-on-findings` | `false` | Fail the step when there are findings. |
| `annotations` | `true` | Inline boxes on the pull request. |
| `snippets` | `true` | The offending line plus ±2 lines of context in the report. With `false`, no fragment of your code leaves. |
| `upload-sarif` | `true` | Attempt to upload to Code Scanning. |
| `sarif-file` | `logdrop-taint.sarif` | SARIF output path. |
| `repo-root` | `github.workspace` | The root SARIF paths are relative to. |
| `panel-url` | *(empty)* | The panel address, if reports should go to the LogDrop panel. **Empty means nothing is sent.** |
| `bundle-id` | *(empty)* | The application id. Required when `panel-url` is set. |
| `analyzer-version` | the version tested with this release | You should not need to change it. |

**Outputs:** `findings` (the count), `sarif-file`.

## Exit codes

The three mean different things and are never conflated:

| Code | Meaning |
|---|---|
| `0` | Clean — no findings |
| `1` | Findings (only with `fail-on-findings: "true"`) |
| `2` | A licence problem (missing / invalid / expired) |
| `3` | An error in the `.logdrop.json` config file |

## Requirements

**macOS 15 or newer.** The analyzer links against Apple system libraries, so it runs
where iOS code is already built — no Xcode, no Swift toolchain, no Homebrew, and
nothing compiled in your project.

That is the one real difference from the Android analyzer, which needs only a JVM and
runs in a plain Linux container. Cloud providers bill macOS roughly ten times Linux,
and a scan takes seconds — but the difference drops to **zero** on your own Mac,
which most iOS teams already have and which this action supports as a self-hosted
runner.

## Licence

LogDrop Taint is **commercial software** and runs on a time-limited key. This
repository distributes the action and the compiled analyzer — it is not open
source, and the analyzer's source code is not in this repository.

The key is verified **offline**: the program contacts no server, does not count your
usage and reports to nobody. It warns 14 days before expiry.

To obtain a key: **satis@initialcode.io**

---
*Initial Code Software Solutions*
