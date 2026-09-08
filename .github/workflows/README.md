# Workflow naming convention (#1033)

GitHub sorts the **Actions** sidebar alphabetically by workflow name. With
fourteen workflows that only reads well if the name itself carries the
grouping, so every workflow here is named:

```
<Group> · <what it does, sentence case>
```

The convention is the one Sparkilo settled on; keeping the two projects
identical means one habit covers both sidebars.

## The six groups

Ordered by when you care about them, which is also how they cluster in the
sidebar:

| Group | Meaning | Who triggers it |
| --- | --- | --- |
| `CI` | gates a PR or a push to master | automatic |
| `Nightly` | scheduled health checks | cron |
| `Release` | ships a build to users | cron or maintainer |
| `Publish` | pushes non-app artefacts — site, listings, data | cron or maintainer |
| `Status` | read-only queries; changes nothing | maintainer |
| `Tools` | manual maintenance utilities | maintainer |

DesKilo has no `Nightly` workflow yet. The group stays in the list because
the two projects share one convention, and the first scheduled health check
should not have to invent a name.

## What is here today

| Name | File | What it is for |
| --- | --- | --- |
| CI · Analyze, test & coverage | `ci.yml` | the gate every PR waits on |
| CI · Android boot check | `android-boot.yml` | installs the shrunk release APK on an emulator and proves it stays alive |
| CI · F-Droid no-GMS audit | `fdroid-foss.yml` | proves the libre flavour carries no Google dependency |
| Release · Train (all platforms) | `release-train.yml` | one dispatch, every store, one commit |
| Release · Play track upload | `play-internal.yml` | builds the signed AAB and uploads it to the chosen Play track |
| Release · iOS TestFlight build | `ios-testflight.yml` | builds, uploads, and optionally distributes to the external group |
| Release · macOS DMG | `macos-app.yml` | the desktop disk image |
| Release · Windows MSI | `windows-msi.yml` | the desktop installer |
| Publish · Web app (GitHub Pages) | `web.yml` | the browser build, and on request the Pages deploy |
| Publish · F-Droid release APKs | `fdroid-release.yml` | the libre APKs F-Droid reproduces against |
| Publish · Play Store listing | `play-listing.yml` | store texts and graphics |
| Status · Play track availability | `play-availability.yml` | what Play actually serves, per track |
| Tools · Add iOS TestFlight tester | `ios-testers.yml` | invite one person |
| Tools · Dev APK (sideload) | `dev-apk.yml` | a one-off APK from any ref |

## Rules

- Sentence case after the group — `Android boot check`, not
  `Android Boot Check`.
- Verb-first when the workflow *performs* an action
  (`Add iOS TestFlight tester`); noun-first when it names what it produces
  or reports on (`Play track availability`, `macOS DMG`).
- `F-Droid` is always spelled that way — never `fdroid` in a display name.
- A parenthetical only for a real disambiguator: `(all platforms)`,
  `(sideload)`, `(GitHub Pages)`. Not for an explanation.
- Two workflows must never share a name: in a run list they would be
  indistinguishable.

Both rules that can be checked mechanically are enforced by
`test/lint/workflow_naming_test.dart`.

## What this convention does *not* touch

Workflow names are **not** status-check contexts. Branch protection lists
job names — here `analyze · l10n gate · test · coverage`, `build`,
`deploy` — so renaming a *workflow* is free, while renaming a **job**
changes a required context and can block auto-merge until protection is
updated in lockstep. Do not rename a job to tidy a name.

`workflow_call` references resolve by path
(`./.github/workflows/play-internal.yml`), so the release train is
unaffected by a rename too.
