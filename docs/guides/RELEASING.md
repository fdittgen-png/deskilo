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

## Release signing (owner action needed)

1. Generate an upload keystore:
   `keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Add GitHub secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
   `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
3. Wire `android/app/build.gradle.kts` release signing to `key.properties`
   (never commit the keystore; `.gitignore` already excludes `*.jks`).
4. Switch `dev-apk.yml` to `--release` builds.

## Google Play (owner action needed)

- Play Console account, app entry for `de.deskilo.app`, Play App Signing
  enrolment with the upload key above.
- Store listing text lives in `fastlane/metadata/android/<locale>/`
  (en-US, de-DE, fr-FR, es-ES, it-IT) — used by fastlane `supply` once a
  service-account JSON exists in secrets.

## F-Droid

- The GMS-free guarantee is enforced by `scripts/audit_no_gms.sh` in CI
  (ADR 0003); no flavor split is needed until a Play-only feature appears.
- `metadata/de.deskilo.app.yml` is the fdroiddata recipe **draft**. After the
  first tagged release (`vX.Y.Z`), fill in the TODO version fields and open a
  merge request to gitlab.com/fdroid/fdroiddata. F-Droid builds from source
  on their buildserver; `AutoUpdateMode: Version` picks up future tags.
- Caveat carried over from Sparkilo: sideloaded/F-Droid APKs and Play APKs
  are signed differently — devices must uninstall one to install the other.

## iOS / TestFlight (owner action needed)

- Apple Developer Program membership, bundle id `de.deskilo.app`,
  App Store Connect API key in secrets, signing certificates (fastlane match
  recommended, as in tankstellen's ios guides).
- The workflow lands together with the first signing setup — a stub without
  certificates would only produce red runs.

## Release checklist (every release)

1. `git tag vX.Y.Z` on master with a green CI run.
2. Bump `version:` in `pubspec.yaml` (name+code) in the release PR.
3. Changelog entry under `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`.
4. `gh workflow run dev-apk.yml -f ref=vX.Y.Z` → smoke-test the artifact on a device.
