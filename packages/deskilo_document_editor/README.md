# deskilo_document_editor

Editing primitives for ordered document elements: selection, insert, reorder, delete, caret-safe token insertion and an undo/redo history. Pure Dart, `publish_to: none`, part of #2592.

## Version and format

Package 0.1.0, not published. It has no serialized format; it edits in-memory lists.

## Dependencies and licence

Runtime: none. Dev: `lints`, `test` (BSD-3-Clause). No Flutter, no `package:deskilo`. The package carries the repository
licence (AGPL-3.0-or-later, see the root `LICENSE` and
`LICENSE-EXCEPTIONS.md`).

## Independent evidence

Resolves, analyzes and tests without the app. CI step in
`.github/workflows/quality.yml` runs in this directory:

```
dart pub get && dart analyze --fatal-infos && dart test
```

Host obligations: own the element list and the persistence; the package only computes the next list and selection.
