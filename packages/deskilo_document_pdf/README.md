# deskilo_document_pdf

Renders a `deskilo_document_model` layout to A4 PDF pages. Pure Dart, `publish_to: none`, part of #2592.

## Version and format

Package 0.1.0, not published. It reads the model's current XML version only through the model package; it has no format of its own.

## Dependencies and licence

Runtime: `deskilo_document_model` (path, same repository), `pdf` (Apache-2.0). Dev: `lints`, `test`. No Flutter, no `package:deskilo`. The package carries the repository
licence (AGPL-3.0-or-later, see the root `LICENSE` and
`LICENSE-EXCEPTIONS.md`).

## Independent evidence

Resolves, analyzes and tests without the app. CI step in
`.github/workflows/quality.yml` runs in this directory:

```
dart pub get && dart analyze --fatal-infos && dart test
```

Host obligations: supply fonts, images, recipient text and, optionally, a markup renderer; a markup element without one reports a diagnostic instead of being dropped. #4160: `reportBlockWidgets` draws the model's report blocks (images come from the host's map by name; a name it does not hold draws nothing; `maxImageHeight` caps an image in a hard band), and `reportWatermarkForeground` paints the one diagonal word a document wears. Which word is the host's policy (an invoice's proforma/void/copy priority stays in the app); an empty word paints nothing.
