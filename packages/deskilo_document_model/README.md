# deskilo_document_model

The typed layout vocabulary (text, image, rule, spacer, table, box, columns, page zones, lengths) and its bounded XML codec. Pure Dart, `publish_to: none`, part of #2592.

## Version and format

Package 0.1.0, not published. The XML root is `<report-layout version="1">` (`LayoutXml.version`). A document without the attribute reads as version 1; a version the reader does not know is refused with `LayoutError.unsupportedVersion`, never guessed. When version 2 exists, every version-1 document must still read: `test/xml_compat_test.dart` pins that.

## Dependencies and licence

Runtime: `xml` (MIT). Dev: `lints`, `test` (BSD-3-Clause). No Flutter, no `package:deskilo`. The package carries the repository
licence (AGPL-3.0-or-later, see the root `LICENSE` and
`LICENSE-EXCEPTIONS.md`).

## Independent evidence

Resolves, analyzes and tests without the app. CI step in
`.github/workflows/quality.yml` runs in this directory:

```
dart pub get && dart analyze --fatal-infos && dart test
```

Host obligations: pass XML that already went through the host's templating pass (the reader knows nothing about `{{ }}`); treat `LayoutException` as a typed refusal.
