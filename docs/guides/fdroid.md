# F-Droid

DesKilo can be built for F-Droid without Google services (ADR 0012).

## Status

This is the one place the F-Droid status is stated. The README, the
project overview, the privacy page and the user and setup guides link
here instead of repeating it. Last checked: 2026-10-10.

- **A Google-free build exists.** It swaps the push package for
  `packages/deskilo_push_foss`, which has no transport: notifications are
  local and the inbox is the source of truth. The CI job `fdroid-foss`
  builds it and fails if any Google Play Services or Firebase class
  reaches the APK; `fdroid-release.yml` attaches the signed per-ABI APKs
  that F-Droid reproduces against to the GitHub release the recipe names.
- **It is submitted, not published.** The recipe is
  [fdroiddata MR !47409](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/47409),
  open and waiting for review. DesKilo cannot be installed from the
  F-Droid client yet.
- **When that changes**, this list is the only statement to update.

> **The submission is FROZEN.** While
> [MR !47409](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/47409) is
> under review, `fdroid/de.deskilo.app.yml` and everything supporting the
> submission change **only** for something F-Droid asks for — a reviewer
> comment, or a specific edit one of their jobs demands. Not a version bump,
> not tidying, not a drive-by. The recipe is worked on again once DesKilo is
> actually published there.
>
> This is enforced, not remembered: `test/lint/fdroid_frozen_test.dart` pins the
> file, so any edit turns the suite red. To make a change F-Droid *has* asked
> for, move the pin in the same commit and name the request in the message —
> the pin moving in review is what makes the exception visible.
>
> Why: a reviewer reads a moving target as an unfinished one, every push
> restarts a quarter-hour pipeline, and this MR spent four days red over two
> bytes of a linker note nothing reads. It verifies now.

## What differs

Two things: the push transport, and the default server. `pubspec.yaml` depends on the local package
`deskilo_push`; the repo has two of them:

| path | contents | used by |
|---|---|---|
| `packages/deskilo_push` | Firebase Cloud Messaging | Play, App Store, macOS, Windows, web |
| `packages/deskilo_push_foss` | no transport | F-Droid |

Same name, same API. F-Droid's recipe swaps the path with one `sed`.
On that build, notifications are local and the inbox is the source of
truth; Settings → Advanced says the build carries no push transport.

**No default server (#2343).** The same swap flips the default of
`BackendConfig.noDefaultServer` (`lib/core/backend/backend_config.dart`)
to true. A build made with `--dart-define=DESKILO_NO_DEFAULT_SERVER=true`
does the same thing. The F-Droid build then compiles no default
endpoint. On first start, before anything is contacted, it asks which
server to use: the reference deployment by name, an existing server
(tested before it is saved), or a new one built by the instance wizard.
Flipping a default in the source, instead of adding the define to the
recipe, keeps the recipe's build lines byte-for-byte what they were.
`fdroid rewritemeta` folds lines a little past 99 characters, and the
arm64 build line is already 99.

## Building it yourself

```sh
bash tool/fdroid_foss_swap.sh   # GNU sed: Linux or CI
flutter pub get --enforce-lockfile
flutter build apk --release
git checkout pubspec.yaml pubspec.lock lib/core/backend/backend_config.dart \
  && flutter pub get   # back to the store flavour
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
— the downside is that the text has to be true for BOTH stores. It says
so where the builds differ: the F-Droid build starts without a server,
and only the store builds carry push.

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

**No `AntiFeatures` (#2343).** Until 1.0.2 the recipe declared
`NonFreeNet`: the binary compiled the author's hosted deployment in as
its default, so a fresh install reached it before anyone chose it.
linsui asked on !47409 whether the server was non-free. It is not: the
schema, RLS policies and edge functions under `supabase/` are
AGPL-3.0-or-later and can be self-hosted. From 1.0.3 the F-Droid build
also ships no default server (above), so nothing is contacted before
the user picks one. The optional payment hand-offs
(PayPal/Stripe/Mollie, configured per workspace) send the user to the
provider's own page, and they are not declared either.

- **`UpdateCheckMode: Tags ^v\d+\.\d+\.\d+$`.** The store pipelines
  push audit tags (`v1.0.2+1663632`, `v1.0.2+…-ios`) on later commits
  whose pubspec still reads the released version. A bare `Tags` could pick
  one of them for a version whose `binary:` assets sit on the real
  `v1.0.x` release, and the verification would fail (mezinster's review,
  2026-10-06). Only release tags match the pattern.

`pubspec.lock` is deliberately **kept**: `flutter pub get` re-resolves only
the swapped path dependency and leaves every other version pinned. Deleting
it would build against whatever is newest that day. (It cannot be *enforced*
though — see `--enforce-lockfile` above.)

### Verified (reproducible) builds — the two things that must line up

F-Droid does not sign DesKilo. It rebuilds the commit the recipe pins and,
if its output matches the APK we published, it ships **our** binary with
**our** signature. Two conditions carry that, and breaking either one
turns every future release red on their builder rather than here:

**1. The same absolute path on both sides.** Dart's AOT output embeds the
directory it was compiled in. F-Droid checks a project out to
`build/de.deskilo.app`, which can never match a GitHub Actions build under
`/home/runner/work/deskilo/deskilo`. So the recipe moves the tree to that
exact path before `prebuild` and `build`, and moves it back afterwards —
the same trick every reproducible Flutter app in fdroiddata uses. If the
repository is ever renamed, or the publishing job stops running on
`ubuntu-latest` with the default checkout path, the recipe's `export repo=`
line has to change with it.

**2. The same signing key, forever.** `AllowedAPKSigningKeys` in the recipe
pins the certificate F-Droid will accept. The keystore lives outside this
repository, in OneDrive under `Documents/DesKilo`, and reaches CI as the
`FDROID_KEYSTORE_BASE64` and `FDROID_KEYSTORE_PASSWORD` secrets. There is
no rotation: a different key means every F-Droid user must uninstall and
reinstall, losing local data. The password is deliberately not stored
beside the keystore.

`fdroid-release.yml` publishes the binaries: it builds each ABI from a
clean `build/`, builds arm64 a second time and refuses to publish if the
two disagree outside `META-INF`, checks the signer against the fingerprint
the recipe allows, and attaches `deskilo-<version>-<abi>.apk` to the
release the `binary:` fields point at. Run it before pushing a recipe that
names a new version, because F-Droid downloads that binary during the
build: no asset, no release.

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
