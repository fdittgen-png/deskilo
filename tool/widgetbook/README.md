# Shared-control catalogue

Built with [Widgetbook 3.25.0](https://pub.dev/packages/widgetbook/versions/3.25.0) (MIT), this catalogue presents real shared controls, Deskilo themes and translations.
Fixtures are synthetic and reset when addons/knobs change; no backend, bootstrap, cloud integration or generator runs.

From the repository root, using the SDK pinned by `.flutter-version`:

```bash
bash tool/widgetbook/verify.sh
cd tool/widgetbook
export BOT=true CI=true FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true
flutter run --no-pub -d chrome --web-hostname 127.0.0.1
```

`verify.sh` enforces the SDK and lock, analyzes, tests, and builds with local renderer resources; CI `widgetbook.yml` runs it.
Root analysis excludes this independent tool package; business packages stay covered. `worktree_prepare.py` does not discover it.
Screenshots are not goldens; viewport/platform simulation does not prove native execution. Existing structural guards remain in `test/core/ui/` and `test/ux/experience_guards.dart`.
