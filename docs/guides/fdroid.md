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
