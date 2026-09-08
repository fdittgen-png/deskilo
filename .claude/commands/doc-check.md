---
description: The whole documentation lint — images against references, anchors against the app and the five languages, the generated help against the guides, the setup questionnaire's help links.
---
# /doc-check — is the documentation honest?

```
dart run tool/media.dart check
dart run tool/build_help.dart && git diff --stat assets/help
flutter test test/lint test/features/help test/core/help
```

Then report, as a short list, every one of these that is not true:
1. Every image a guide references exists; every image on disk is
   referenced by at least one guide.
2. `assets/help/` is in step with `docs/wiki/` (the diff above is empty).
3. Every help anchor used in the app exists in all five guides
   (`help_anchor_test`), and every topic string is a substring of a
   heading line in all five (`help_hint_test`).
4. The five guides are structurally parallel: same headings, same
   anchors, same image names.
5. Every parameter with a help symbol in the app has one in
   `web/setup.html`, pointing at an anchor that exists.
6. `.media-workbench/index.md` covers every image and no image is
   described as "".

Fix what is mechanical; list what needs a decision.
