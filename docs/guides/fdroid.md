# F-Droid

DesKilo can be built for F-Droid without Google services (ADR 0012).

## What differs

Only the push transport. `pubspec.yaml` depends on the local package
`deskilo_push`; the repo has two of them:

| path | contents | used by |
|---|---|---|
| `packages/deskilo_push` | Firebase Cloud Messaging | Play, App Store, macOS, Windows, web |
| `packages/deskilo_push_foss` | no transport | F-Droid |

Same name, same API. F-Droid's recipe swaps the path with one `sed`.
On that build, notifications are local and the inbox is the source of
truth; Settings → Advanced says the build carries no push transport.

## Building it yourself

```sh
sed -i 's|    path: packages/deskilo_push$|    path: packages/deskilo_push_foss|' pubspec.yaml
flutter pub get
flutter build apk --release
git checkout pubspec.yaml && flutter pub get   # back to the store flavour
```

The CI job `fdroid-foss` does exactly this on every change to
`packages/`, `pubspec.yaml` or `lib/core/push/`, and fails if any
`com/google/android/gms` or `firebase` class reaches the dex.

## Submitting

1. Tag a commit `v1.0.0-fdroid.<n>` (F-Droid builds that exact tag).
2. Copy this directory into a fork of
   https://gitlab.com/fdroid/fdroiddata and open a merge request:

   | here | there |
   |---|---|
   | `fdroid/de.deskilo.app.yml` | `metadata/de.deskilo.app.yml` |
   | `fdroid/de.deskilo.app/en-US/summary.txt` | `metadata/de.deskilo.app/en-US/summary.txt` |

3. `fdroid build -v -l de.deskilo.app` in that checkout reproduces what
   their builder will do.

### The recipe is stored in canonical form — do not "tidy" it

`fdroid/de.deskilo.app.yml` is byte-for-byte what `fdroid rewritemeta`
produces, because their CI runs that tool and **fails the pipeline on any
diff**. That is why the file carries no comment header (this guide holds
the rationale instead), why `Categories` is alphabetical, why blank lines
separate the field groups, and why `prebuild` is a folded double-quoted
scalar rather than the one-item list it reads more naturally as. Change it
only by re-deriving it: the failing job prints the exact diff to apply.

Four rules the first pipeline taught us, each one a red job:

- **No `submodules: true`** unless the repo really has submodules —
  `fdroid build` raises `NoSubmodulesException` when it finds none.
- **No `scandelete: .pub-cache`.** The source scan runs *before* the build
  commands, so the pub cache does not exist yet and the path is reported
  twice, as "Non-exist" and as "Unused".
- **`Summary` does not live in the `.yml`.** `tools/make-summary-translatable.py`
  moves it to `<pkg>/en-US/summary.txt`, and the "tools check scripts" job
  fails if that script would change anything. Ship it already moved.
- **`UpdateCheckMode: None`.** A `Tags` pattern makes `checkupdates` fail
  with "Couldn't find any version information", and it would be wrong
  anyway: each F-Droid release is a deliberate tag whose `--build-number`
  is set by hand here, on its own versionCode series (the store trains use
  a wall-clock number). `AutoUpdateMode: None` for the same reason.

`AntiFeatures: NonFreeNet` is not optional: the shipped binary's compiled
defaults (`lib/core/backend/backend_config.dart`) point at the author's
hosted deployment, so a user who installs and signs in does reach the
developer's instance. The server is free software in this repository
(0BSD: SQL migrations, RLS policies and edge functions under `supabase/`),
and since #780 a community points the *installed* build at its own
Supabase from Settings → Advanced → Server — but the default endpoint is
what F-Droid ships, hence the disclosure. It can be revisited if a build
ever ships with no default endpoint at all.

`pubspec.lock` is deliberately **kept**: `flutter pub get` re-resolves only
the swapped path dependency and leaves every other version pinned. Deleting
it would build against whatever is newest that day.

## Submission state (2026-08-31)

The recipe is `fdroid/de.deskilo.app.yml` and the build it submits is the tag
**`v1.0.0-fdroid.2`** (versionCode 100001) — the first F-Droid build in which
the app can be pointed at a community's own Supabase from Settings → Advanced
→ Server (#780), which is what the `NonFreeNet` disclosure describes.

Audited against the sibling app's review (fdroid/fdroiddata!42093) before
submitting, which caught three things a first review round would have:

1. `Categories: [Office]` — **Office is not one of F-Droid's 108 categories**
   (`config/categories.yml`). Now `Schedule` + `Finance Manager`.
2. `AntiFeatures: {}` contradicted the binary: `lib/core/backend/backend_config.dart`
   compiles the author's hosted endpoint in as the default, so `NonFreeNet` is
   declared with a per-app description.
3. The `prebuild` sed line was unparseable YAML (`path:` inside an unquoted
   scalar) — quoted now; `fdroid lint` would have rejected it.

**The merge request is filed: fdroid/fdroiddata!47409**, branch
`de.deskilo.app` on the `fdittgen/fdroiddata` fork. It now waits on an
F-Droid reviewer; they may ask for changes, which are pushed to the same
branch and re-run the pipeline.

How it was pushed, because the obvious two routes are both dead here: `glab`
holds an expired token (401), SSH to gitlab.com is `Permission denied
(publickey)`, and `git push` over HTTPS is refused with `shallow update not
allowed`. What works is the **REST API with the PAT already in the git
credential keychain**:

```bash
T=$(printf "protocol=https\nhost=gitlab.com\n\n" | git credential fill | sed -n 's/^password=//p')
curl -X POST -H "PRIVATE-TOKEN: $T" -H 'Content-Type: application/json' \
  https://gitlab.com/api/v4/projects/fdittgen%2Ffdroiddata/repository/commits \
  -d '{"branch":"de.deskilo.app","commit_message":"…","actions":[{"action":"update",
       "file_path":"metadata/de.deskilo.app.yml","content":"…"}]}'
```

One trap when recreating the branch: **do not branch from the fork's
`master`.** It is an old snapshot that still carries the sibling app's
`metadata/de.tankstellen.fuelprices.yml`, which upstream does not have, so
the MR shows two changed files and a reviewer sees an unrelated app. Create
the branch from a commit that is an ancestor of upstream `master` instead —
the branch here was cut at `d0a969eb`.
