# Integration recipes

LogDrop Taint is **not tied to GitHub.** The analyzer is a single executable and
needs only macOS — no Xcode, no Swift toolchain, no Homebrew.

## The model: the same three steps everywhere

```
1. DOWNLOAD  →  once, per version (cacheable)
2. VERIFY    →  SHA-256; a corrupt or altered binary never scans
3. RUN       →  the exit code makes the decision
```

The first two live in [`install-logdrop-taint.sh`](install-logdrop-taint.sh), and
every recipe below calls it. On GitHub Actions you do not even need that — the
action does both for you.

## Sending the report to the panel

Optional, and off until you switch it on. Every recipe here ends by calling
[`report-to-panel.sh`](report-to-panel.sh), and the step is safe to leave in place:
with nothing configured it prints one line and does nothing.

Three variables, and you need all three:

| Variable | What it is |
|---|---|
| `PANEL_URL` | Your panel's address |
| `LOGDROP_LICENSE` | Your key — already required for the scan itself |
| `BUNDLE_ID` | Your application's bundle id, **as registered in the panel** |

Set them wherever your CI keeps configuration and reports start arriving; no edit to
the recipe. Miss one and nothing is sent, quietly — so if the dashboard stays empty,
check that all three are actually reaching the job.

**The bundle id must be registered for that project in the panel.** One the panel
does not recognise is refused outright, nothing is stored, and the step fails. That
is deliberate: a typo you can see beats a green pipeline that sent nothing.

**The analyzer itself never contacts anything.** It verifies its licence offline,
counts no usage and does not report that it ran. Sending is a separate step, on a
report that already exists, run by you — which is why it is a script you can read
rather than a flag inside the binary.

**A rejected report fails the build; a panel that is down does not.** If the panel
refuses the report — the usual cause is a `BUNDLE_ID` not registered for your
project — the step exits non-zero and you see it. A step that stayed green while no
report ever arrived is the failure nobody notices until someone asks why the
dashboard is empty.

If the panel is unreachable, under maintenance, or simply not configured, the step
exits 0 and your build is untouched. The scan's exit code already said what it
found, and a maintenance window on our side must not turn your green build red an
hour later. An expired or revoked licence is in this second group too: the
developer who pushed the commit cannot fix it, so it warns rather than blocks.

Which customer a report belongs to comes from your **licence key**, not from
anything the recipe sends.

## Exit codes — the contract every integration rests on

| Code | Meaning | What CI should do |
|---|---|---|
| `0` | Clean | Carry on |
| `1` | Findings (with `--fail-on-findings`) | Fail the build, block the pull request |
| `2` | Licence missing / invalid / expired | Fail, but DO NOT say "your code has a vulnerability" |
| `3` | An error in `.logdrop.json` | Fail, fix the config file |

Telling `1` and `2` apart matters: a developer whose licence lapsed will go looking
in entirely the wrong place if you tell them their code is insecure.

## The recipes

| System | File | Note |
|---|---|---|
| **GitHub Actions** | [main README](../README.md) | The action does everything, download and verification included |
| **CircleCI** | [`circleci/config.yml`](circleci/config.yml) | Needs a macOS executor (on paid plans) |
| **GitLab CI** | [`gitlab/.gitlab-ci.yml`](gitlab/.gitlab-ci.yml) | Needs a macOS runner; your own Mac is free |
| **Jenkins** | [`jenkins/Jenkinsfile`](jenkins/Jenkinsfile) | An agent labelled `macos` |
| **Bitrise** | [`bitrise/bitrise.yml`](bitrise/bitrise.yml) | Already a macOS stack; nothing extra needed |
| **fastlane** | [`fastlane/Fastfile`](fastlane/Fastfile) | Run it before the build |
| **Xcode** | [`xcode/run-script-phase.sh`](xcode/run-script-phase.sh) | Findings appear as Xcode warnings — [setup below](#in-xcode) |
| **Your own machine** | [`local/scan.sh`](local/scan.sh) | Scan your code before you push |

## Where the licence key goes

Always in the **`LOGDROP_LICENSE` environment variable**, and always sourced from
that system's secret store:

| System | Where |
|---|---|
| GitHub Actions | Repository secrets |
| CircleCI | Project Settings → Environment Variables |
| GitLab | Settings → CI/CD → Variables (tick **Masked**) |
| Jenkins | Credentials → Secret text |
| Bitrise | Secrets |
| Local | `export LOGDROP_LICENSE=...` or `~/.logdrop/license` |

Do not write the key into a configuration file: command-line arguments can show up
in run logs and in the process list, which is why every recipe here uses the
environment variable.

## The macOS requirement

The analyzer runs on macOS because it links against Apple system libraries. In
practice that is not a constraint: iOS source is already built on macOS, so the
machine is one you already have.

**A note on cost:** cloud providers bill macOS noticeably higher than Linux (~10x
on GitHub). A scan takes seconds, so the extra is small — and it drops to **zero**
if you use your own Mac as a runner, which most iOS teams already have.

## In Xcode

The scan runs on every build and findings appear as warnings against the lines that
caused them, so you see a leak while you are still writing it.

1. Copy [`xcode/run-script-phase.sh`](xcode/run-script-phase.sh) to
   `~/.logdrop/xcode-scan.sh` and make it executable.
2. In Xcode, select the project, pick your target, open **Build Phases**.
3. **+** → **New Run Script Phase**.
4. Paste: `bash "$HOME/.logdrop/xcode-scan.sh"`
5. Drag the phase **above Compile Sources**, so it runs before the build.
6. Leave **Based on dependency analysis** unticked. Ticked, Xcode decides the inputs
   have not changed and skips the scan without telling you.

Put your key in `~/.logdrop/license` once and the phase finds it; there is no key to
paste into Xcode.

### Knowing it ran

- Warnings appear next to the code, and in the issue navigator (⌘5).
- The build log (⌘9 → *Run custom shell script 'LogDrop Taint'*) ends with
  `LogDrop Taint: N finding(s).` **That line is the proof.** No line at all means the
  phase did not run.
- Nothing fails silently: a missing binary, a missing key and an expired licence each
  print their own warning.

### It never fails your build

On your own machine this is a warning layer. The gate belongs in CI, where
`--fail-on-findings` blocks the merge. A scan that broke the build every time you
typed a half-finished line would be turned off within a day.

### Scanning less

A whole project is scanned by default, which on a large one is noticeable on every
build. Point it at a folder instead:

```
SCAN_PATH="$SRCROOT/Sources" bash "$HOME/.logdrop/xcode-scan.sh"
```

### Sending to the panel from Xcode — usually don't

The phase can send its report, if you give it `PANEL_URL` and `BUNDLE_ID`. It is off
by default, and that is the recommendation:

```
PANEL_URL="https://panel.example.com" BUNDLE_ID="com.company.app" \
  bash "$HOME/.logdrop/xcode-scan.sh"
```

Turned on, **every build** publishes your working copy — half-finished code, code you
are about to delete, an experiment. Your colleagues open the panel and ask why it is
red. The panel should hold what the team agreed on, and that comes from committed
code through CI, not from somebody's editor.

Worth turning on in one case: you work alone, you have no CI, and the panel is the
only place you want history.
