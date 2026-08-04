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

### Store listing sync (texts + images)

- Brand images live once under `fastlane/metadata/android/en-US/images/`:
  `icon.png` (512×512, derived from `assets/icon/icon_full.png`) and
  `featureGraphic.png` (1024×500). Other Play
  locales fall back to en-US at upload time.
- Regenerate the feature graphic after a brand change:
  `flutter test tool/store_assets/feature_graphic_test.dart` (draws it with
  the canvas API; not part of the CI test run).
- Sync everything to the Play listing:
  `gh workflow run play-listing.yml` (add `-f dry_run=true` to validate
  without committing). The workflow runs `tools/upload_listing.py`, which
  updates title/short/full description for every locale and re-uploads the
  icon, feature graphic, and any `images/phoneScreenshots/*.png`.
- Still missing for a production listing: at least 2 phone screenshots
  (drop PNGs into `fastlane/metadata/android/en-US/images/phoneScreenshots/`),
  plus Console-only forms (content rating, data safety, contact details).


## iOS / TestFlight

Pipeline (`ios-testflight.yml`, tankstellen mirror, dispatch-only to spare
macOS minutes):

```bash
# ONE-TIME, in this order:
gh secret set MATCH_PASSWORD -R fdittgen-png/deskilo                 # 1Password
gh secret set APP_STORE_CONNECT_API_ISSUER_ID -R fdittgen-png/deskilo \
  --body ae6fe867-5d68-454a-a38b-5f9a98a5be24                        # team-wide
gh workflow run ios-testflight.yml -f create_app=true    # ASC app record
gh workflow run ios-testflight.yml -f sync_certs=true    # mint the profile

# THEN, per build:
gh workflow run ios-testflight.yml                       # build + TestFlight
gh workflow run ios-testers.yml -f email=someone@example.com  # invite a tester
```

- Signing: **fastlane match** against DesKilo's own private repo
  `deskilo-ios-certs`, with its own `MATCH_PASSWORD`. The first
  `sync_certs` run mints an Apple Distribution certificate and the
  `de.deskilo.app` profile into it. (Sharing tankstellen's certs repo was
  the original plan; its passphrase proved unrecoverable, and re-encrypting
  a repo Sparkilo depends on to fix a DesKilo problem is not a trade worth
  making. Apple allows three distribution certificates per team, and
  minting one leaves the existing one alone.)
- **Losing `MATCH_PASSWORD` means redoing this**: the repo's contents are
  useless without it. Store it where the tankstellen one should have been.
- Secrets in place: `APP_STORE_CONNECT_API_KEY_ID` / `_BASE64` (key
  `CG5N5AKMH9`, .p8 also in `~/Downloads` — back it up, Apple won't
  re-issue it), `MATCH_DEPLOY_KEY` (write deploy key `deskilo-ci` on the
  certs repo — may be downgraded to read-only after the first sync).
- **`MATCH_PASSWORD` is the one thing only the owner has**: the
  certs-repo passphrase, same value as tankstellen's, in 1Password. Without
  it match cannot decrypt the repo and the run dies with *"Invalid password
  passed via 'MATCH_PASSWORD'"* — which is exactly how the 2026-07-09 run
  failed. `APP_STORE_CONNECT_API_ISSUER_ID` is the team-wide issuer UUID
  (App Store Connect → Users and Access → Integrations, above the key list);
  the command above carries it.
- The **app record** at Apple no longer needs the Console: `-f
  create_app=true` runs `fastlane produce` (lane `create_app_record`), which
  claims `de.deskilo.app` and creates the record TestFlight hangs off.
  Apple has no equivalent of Play binding a package on first upload, so this
  must happen before the first `pilot` upload. Idempotent.
- **Testers**: `ios-testers.yml` (lane `manage_testers`, ported from
  tankstellen) enrolls an address through the ASC API — external groups by
  email, internal groups by inviting the tester as a Users-and-Access user
  scoped to this app. Dispatch-only: it sends a real invitation email.
- Uploads are internal-only for now (instant, no review, ≤100 testers). An
  **external** tester means the build passes Beta App Review first; port
  tankstellen's `configure_beta_review` when that day comes.

## macOS

```bash
gh workflow run macos-app.yml -f ref=master     # → DesKilo-X.Y.Z.dmg artifact
```

- `flutter build macos --release` plus `hdiutil`: the DMG is the
  drag-into-Applications window, no extra tooling. Also runs on PRs touching
  `macos/**` and attaches the DMG to the release on a `v*` tag.
- **The Developer ID certificate must be created by the ACCOUNT HOLDER.**
  An App Store Connect API key cannot mint one — Apple answers *"This
  request is forbidden for security reasons - This operation can only be
  performed by the Account Holder"*. Create it once in Xcode (Settings →
  Accounts → Manage Certificates → ＋ → Developer ID Application), export
  the certificate and its private key, then push them into the certs repo:

  ```bash
  cd ios
  MATCH_PASSWORD=<the DesKilo passphrase> \
    bundle exec fastlane match import --type developer_id \
    --git_url git@github.com:fdittgen-png/deskilo-ios-certs.git
  ```

  Until that exists the workflow still builds: it produces a DMG named
  `-unsigned` and logs a warning. It does NOT fail, because a macOS
  pipeline that produces nothing is worse than one that produces something
  honestly labelled.
- **Once signed: notarised by Apple.** Not polish: since
  macOS 15 a downloaded app Apple has not notarised is refused outright
  ("Apple n'a pas pu confirmer que DesKilo ne contenait pas de logiciel
  malveillant") and the old right-click → Open bypass is gone. The
  certificate lives in the same `deskilo-ios-certs` repo as the App Store
  one; mint it once with `-f sync_certs=true`.
- `scripts/sign_and_notarize_macos.sh` signs nested frameworks first and the
  bundle last, hardened runtime on, then submits the DMG to `notarytool`,
  staples the ticket into it and asserts `spctl` accepts it — so a build
  that would be refused on someone's Mac fails in CI instead.
- **PR builds are unsigned** and named `-unsigned.dmg`: a fork has no access
  to the signing secrets, and a five-minute Apple round-trip per PR would be
  absurd. They prove the build and the packaging, nothing more.

## Web (browser)

```bash
gh workflow run web.yml                     # artifact only
gh workflow run web.yml -f deploy=true      # …and publish to GitHub Pages
```

- Runs on every PR touching `lib/**`, `web/**` or `pubspec.yaml`: a change
  that only breaks the browser (a `dart:io` import reaching web code, a
  plugin with no web implementation) fails there instead of in front of a
  user.
- **Publishing is opt-in.** `deploy=true` puts the app on the public Pages
  URL with the committed Supabase URL + publishable key baked in — the same
  pair every store binary ships (RLS is the boundary, ADR 0002). Pages must
  be enabled once in repo Settings → Pages → Source: GitHub Actions.
- `--base-href` is set to `/<repo>/` for a Pages deploy (assets 404 without
  it), and `index.html` is copied to `404.html` so reloading a deep link
  works on a static host.
- What the browser cannot do: NFC badges and camera QR scanning are guarded
  off (`kIsWeb`), and an export downloads through the browser instead of
  landing in a Downloads folder (`file_saver_web.dart`).

## Release checklist (every release)

1. `git tag vX.Y.Z` on master with a green CI run.
2. Bump `version:` in `pubspec.yaml` (name+code) in the release PR.
3. Changelog entry under `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`.
4. `gh workflow run dev-apk.yml -f ref=vX.Y.Z` → smoke-test the artifact on a device.
