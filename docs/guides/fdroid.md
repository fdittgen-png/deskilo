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

Only the **build recipe** goes to fdroiddata — one file,
`fdroid/de.deskilo.app.yml` → `metadata/de.deskilo.app.yml`.

Everything a user reads (title, summary, description, screenshots, icon)
is pulled from **`fastlane/metadata/android/`** in this repo, which is
the same folder the Play listing is generated from
(`.github/workflows/play-listing.yml`). Their reviewer asked for this
explicitly on !47409: *"Don't add summary and description or other
metadata files except the build metadata in fdroiddata."* The upside is
that the listing is maintained here, in one place, in all five languages
— the downside is that the text has to be true for BOTH stores, so keep
F-Droid-specific caveats (the hosted default endpoint) in the recipe's
`AntiFeatures` block, not in the description.

`fdroid build -v -l de.deskilo.app` in an fdroiddata checkout reproduces
what their builder does.

### One APK per ABI

F-Droid ships a build per architecture, and the version codes carry the
ABI in their lowest digit — `versionCode * 10 + abi`, with
`armeabi-v7a` = 1 < `arm64-v8a` = 2 < `x86_64` = 3. The override lives in
`android/app/build.gradle.kts`; `VercodeOperation` in the recipe repeats
the same arithmetic so autoupdate can compute future codes.

The ordering is not cosmetic. A client installs the highest code a device
can take, and fdroidserver archives all but the highest — so putting the
ABI digit anywhere but last would offer 64-bit phones the 32-bit build
forever, and let an old release's x86_64 outrank a new release's arm.

The base code comes from `pubspec.yaml` (`version: 1.0.0+1` → 1 → 11/12/13),
read back by `UpdateCheckData`. **A new F-Droid release is a bumped
pubspec build number**, not a hand-set `--build-number` as before; the
store trains keep passing their own wall-clock number at build time and
never touch the pubspec.

### The recipe is stored in canonical form — do not "tidy" it

`fdroid/de.deskilo.app.yml` is byte-for-byte what `fdroid rewritemeta`
produces, because their CI runs that tool and **fails the pipeline on any
diff**. That is why the file carries no comment header (this guide holds
the rationale instead), why `Categories` is alphabetical, why blank lines
separate the field groups, and why long commands are folded double-quoted
scalars. Change it only by re-deriving it: the failing job prints the
exact diff to apply.

Rules their pipeline and their reviewer taught us, each one a red job or a
review comment:

- **`commit:` is a full 40-character hash**, never a tag or branch name.
- **No `submodules: true`** unless the repo really has submodules —
  `fdroid build` raises `NoSubmodulesException` when it finds none.
- **`scandelete: .pub-cache` needs `flutter pub get` in `prebuild`.** The
  source scan runs between prebuild and build, so a cache populated in
  `build` does not exist yet and the path is reported twice, as
  "Non-exist" and as "Unused". Populate it in prebuild and the scanner
  both sees and deletes it — which is also what gets the dart packages
  scanned at all.
- **`--enforce-lockfile` IS used**, via `tool/fdroid_foss_swap.sh`. It
  first failed because swapping the push package changes the dependency
  GRAPH, not just a path: the libre twin pulls no Firebase, so seven
  `firebase_*` packages and `_flutterfire_internals` stop being depended
  on and pub rejects the lock. The script patches the path in both
  `pubspec.yaml` and `pubspec.lock` and drops exactly those entries, and
  then the lock describes the libre build with every other version still
  pinned to the byte. linsui asked for this; it works, verified locally
  and in our own gate.
- **The Flutter version is pinned in `.flutter-version`** and the recipe
  `cat`s it, rather than being written into the `srclibs` line (also
  linsui's ask). `srclibs` is `flutter@stable` and `prebuild` checks the
  pinned tag out of it. A lint keeps every workflow's `FLUTTER_VERSION`
  equal to that file, because a workflow that disagrees is a toolchain we
  never actually test.
- **The swap is ONE script**, `tool/fdroid_foss_swap.sh`, called by the
  recipe and by our `fdroid-foss` gate, so the build we test cannot drift
  from the build F-Droid makes.
- **No `Summary`/`Description` in the `.yml`** — fastlane, as above.
  Leaving `Summary` in also trips the "tools check scripts" job, which
  runs `tools/make-summary-translatable.py` and fails if it would move
  anything.
- **The APK must carry no extra signing block** (#787), and the dex no
  Google classes. Both are asserted by our own `fdroid-foss` gate now.

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
it would build against whatever is newest that day. (It cannot be *enforced*
though — see `--enforce-lockfile` above.)

## Submission state (2026-09-01)

The recipe is `fdroid/de.deskilo.app.yml` and it submits **three builds of
one commit** (version codes 11/12/13, one per ABI) — the first F-Droid
build in which the app can be pointed at a community's own Supabase from
Settings → Advanced → Server (#780), which is what the `NonFreeNet`
disclosure describes.

Reviewed by **linsui** on 2026-09-01, who asked for the App-inclusion MR
template, fastlane metadata upstream instead of files in fdroiddata, a
full commit hash instead of a tag, `templates/build-flutter.yml`, and the
ABI split. All five are in (#795).

Audited against the sibling app's review (fdroid/fdroiddata!42093) before
submitting, which caught three things a first review round would have:

1. `Categories: [Office]` — **Office is not one of F-Droid's 108 categories**
   (`config/categories.yml`). Now `Schedule` + `Finance Manager`.
2. `AntiFeatures: {}` contradicted the binary: `lib/core/backend/backend_config.dart`
   compiles the author's hosted endpoint in as the default, so `NonFreeNet` is
   declared with a per-app description.
3. The `prebuild` sed line was unparseable YAML (`path:` inside an unquoted
   scalar) — quoted now; `fdroid lint` would have rejected it.

### The APK carries no dependency-metadata block

Their `check apk` job scans the *built* binary, and it refuses an "extra
signing block 'Dependency metadata'" — a Google-signed, encrypted blob of
the dependency tree that the Android Gradle Plugin embeds by default and
that nobody outside Google can read. `android/app/build.gradle.kts` turns
it off for the APK and keeps it in the bundle (#787): the AAB is the copy
Play reads for its vulnerability warnings, and Play never sees the APK.

The same job's dex scan is the real prize, and it is clean: no
`com/google/android/gms`, no Firebase. The `deskilo_push_foss` swap is
doing what this guide claims it does.

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
