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
| **Xcode** | [`xcode/run-script-phase.sh`](xcode/run-script-phase.sh) | Findings appear as Xcode warnings |
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
