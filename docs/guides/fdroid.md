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

1. Tag a commit `v1.0.0-fdroid.1` (F-Droid follows `v*-fdroid.*` tags).
2. Copy `fdroid/de.deskilo.app.yml` to `metadata/de.deskilo.app.yml` in a
   fork of https://gitlab.com/fdroid/fdroiddata and open a merge request.
3. `fdroid build -v -l de.deskilo.app` in that checkout reproduces what
   their builder will do.

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

**What is left is one owner action.** `glab` holds an expired token (401) and
SSH to gitlab.com is `Permission denied (publickey)`, so the fork push and the
merge request cannot be made from a session. Authenticate (`glab auth login`),
then push the prepared branch to `fdittgen/fdroiddata` and open the MR against
`fdroid/fdroiddata:master` titled **DesKilo (de.deskilo.app)**. Regenerate the
branch at any time with:

```bash
git clone https://gitlab.com/fdroid/fdroiddata.git && cd fdroiddata
git checkout -B de.deskilo.app origin/master
cp <deskilo>/fdroid/de.deskilo.app.yml metadata/de.deskilo.app.yml
git commit -am "New app: DesKilo (de.deskilo.app)"
```
