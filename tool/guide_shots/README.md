# Guide screenshots

Re-shoots every screenshot of the user guide and the setup guide from a built web app, in the Demo workspace,
in each guide language. The contract is `docs/guide/AUTHORING.md`; the specs are `shots/<chapter>.json`.

```
mkdir /tmp/pw && cd /tmp/pw && npm i playwright-core        # once; needs a Chromium (the Playwright cache works)
flutter build web --release -o /tmp/guide-web
PW_DIR=/tmp/pw node tool/guide_shots/capture.mjs --web /tmp/guide-web --repo .                    # all, all languages
PW_DIR=/tmp/pw node tool/guide_shots/capture.mjs --web /tmp/guide-web --lang fr,de --chapter 02   # a chapter
PW_DIR=/tmp/pw node tool/guide_shots/capture.mjs --web /tmp/guide-web --only user-reserve-plan    # one screen
dart run tool/build_user_guide.dart && dart run tool/build_help.dart && dart run tool/build_guide_site.dart
```

- Files: `docs/wiki/images/<id>[--part].<lang>.b<commit>.jpg`; a re-shoot from a newer build writes the new name and
  removes the old one. `docs/wiki/images/_shots.<lang>.json` records build, version and date.
- A shot waits until the screen stopped moving and no spinner is left, clicks tip bubbles away (`keepTips` keeps one),
  and grows the window until a long form no longer scrolls; `parts` cut out one control (`from`/`to` labels).
- Steps: `hash`, `click` (text, `@arbKey`, `@arbKey|name=value`, or a list of alternatives; `via` for a tab behind the
  overflow button), `at`, `type`, `fill`, `scroll`, `press`, `css`, `eval`, `wait`. A `url` shot photographs a static
  page of the build (the setup wizard) without entering the demo.
- On a failure the runner leaves a screenshot of the screen it was stuck on in `$TMPDIR/guide-shots-fail-*.png`.
- Defaults (1.2 device pixels, quality 62) keep a screenshot near 20 KB: the in-app help bundles five languages.
