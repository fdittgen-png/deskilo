# Releasing DesKilo

Mirrors the tankstellen/Sparkilo release toolchain (spec §12). Status of each
lane and what the owner must provide before it can go live.

## Sideload APK (works today)

```bash
gh workflow run dev-apk.yml -f ref=master
gh run download <run-id> --dir /tmp/dev-apk
```

Debug-signed — sideload only. Naming convention for manual drops:
`deskilo-arm64-<ref>-<short-sha>-<UTC-yyyymmdd-hhmmZ>.apk`.

## Release signing (DONE 2026-07-07)

- PKCS12 upload keystore generated with OpenSSL (alias `upload`, 30-year
  validity). **Master copy + password: `~/keystores/deskilo-upload-keystore.*`
  on the dev Mac — back both up off-machine.**
- Repo secrets set: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- `android/app/build.gradle.kts` signs release builds from
  `android/key.properties` when present (CI writes it from secrets); local
  builds without it fall back to debug signing.

## Google Play internal testing

Automated half (`play-internal.yml`, tankstellen daily-beta pattern):

- **Daily at 16:00 UTC** and on demand
  (`gh workflow run play-internal.yml -f track=internal`), master is built
  with a **wall-clock monotonic versionCode** (minutes since 2025-07-06 UTC
  on a 1M base), signed, attached as an artifact, uploaded to the chosen
  Play track by `tools/upload_to_play.py` (resumable upload with retries,
  per-locale changelogs `fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt`
  with fallback notes), and tagged `vX.Y.Z+<versionCode>`.
- Until `PLAY_STORE_SERVICE_ACCOUNT_JSON` exists on this repo the upload is
  skipped with a warning and only the artifact is produced.

Owner half (Google offers NO API for these):

1. Play Console → **Create app**: name *DesKilo*, App, Free; package
   `de.deskilo.app` is bound on first AAB upload.
2. Reuse the tankstellen publisher service account: copy the JSON into this
   repo (`gh secret set PLAY_STORE_SERVICE_ACCOUNT_JSON -R fdittgen-png/deskilo < sa.json`)
   and, in Play Console → Users & permissions, make sure the service account
   may manage releases for the new app.
3. Internal testing → **Testers**: create/attach an email list and share the
   opt-in link.
4. Re-run `play-internal.yml` (or upload the artifact AAB manually once —
   after that the API path works).

- Store listing text lives in `fastlane/metadata/android/<locale>/`
  (en-US, de-DE, fr-FR, es-ES, it-IT); internal testing does not require the
  full listing, production does.

## F-Droid

- The GMS-free guarantee is enforced by `scripts/audit_no_gms.sh` in CI
  (ADR 0003); no flavor split is needed until a Play-only feature appears.
- `metadata/de.deskilo.app.yml` is the fdroiddata recipe **draft**. After the
  first tagged release (`vX.Y.Z`), fill in the TODO version fields and open a
  merge request to gitlab.com/fdroid/fdroiddata. F-Droid builds from source
  on their buildserver; `AutoUpdateMode: Version` picks up future tags.
- Caveat carried over from Sparkilo: sideloaded/F-Droid APKs and Play APKs
  are signed differently — devices must uninstall one to install the other.

## iOS / TestFlight

Pipeline (`ios-testflight.yml`, tankstellen mirror, dispatch-only to spare
macOS minutes):

```bash
gh workflow run ios-testflight.yml -f sync_certs=true   # once: mint the profile
gh workflow run ios-testflight.yml                      # build + TestFlight
```

- Signing: **fastlane match** against the shared team repo
  `tankstellen-ios-certs` (the distribution cert is per-team; DesKilo only
  adds its own `de.deskilo.app` appstore profile — created by the
  `sync_certs` run, which also registers the bundle id at Apple).
- Secrets in place: `APP_STORE_CONNECT_API_KEY_ID` / `_BASE64` (key
  `CG5N5AKMH9`, .p8 also in `~/Downloads` — back it up, Apple won't
  re-issue it), `MATCH_DEPLOY_KEY` (write deploy key `deskilo-ci` on the
  certs repo — may be downgraded to read-only after the first sync).
- Secrets still owner-provided: `APP_STORE_CONNECT_API_ISSUER_ID`
  (App Store Connect → Users and Access → Integrations, shown above the key
  list) and `MATCH_PASSWORD` (the certs-repo passphrase, same as
  tankstellen's).
- Owner-only, no API exists: create the **app record** in App Store Connect
  (My Apps → ＋ → New App → iOS, name *DesKilo*, bundle id `de.deskilo.app`,
  any SKU) and add internal testers under TestFlight → Internal Testing.
- Uploads are internal-only (instant, no review, ≤100 testers); external
  groups + Beta App Review land later by porting tankstellen's
  `upload_testflight` extras.

## Release checklist (every release)

1. `git tag vX.Y.Z` on master with a green CI run.
2. Bump `version:` in `pubspec.yaml` (name+code) in the release PR.
3. Changelog entry under `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`.
4. `gh workflow run dev-apk.yml -f ref=vX.Y.Z` → smoke-test the artifact on a device.
