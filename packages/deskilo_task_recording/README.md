# deskilo_task_recording

The semantic task-recording core (#2593). Pure Dart, `publish_to: none`.
The host supplies an `ActionRegistry`; nothing here knows an application.

## What is in the package

- Immutable step, segment and completeness models, the bounded codec and
  decoder, the minimization mechanism (`task_recording*.dart`,
  `safe_payload.dart`, `step_values.dart`, `recording_edit.dart`).
- The writer and sink contracts (`recording_sink.dart`).
- The versioned catalogue types (`action_catalogue.dart`).
- The guide model and its state machine (`task_guide.dart`, `guide_run.dart`).
- `CapturePolicy` and `CataloguePolicy` (`capture_policy.dart`).
- `ReplayAuthorizer`, `ActionExecutor` and `ReplayCoordinator` (`replay.dart`).

Not in the package: the guide codec and compiler (they need the app's
destination registry), every surface, action, outcome and payload name, and
every user-facing string.

## Format and API versions

| Thing | Constant | Value | Rule |
|---|---|---|---|
| Recording format | `taskRecordingFormat` | `deskilo.task-recording` | marker every encoded recording starts with |
| Recording schema | `taskRecordingSchemaVersion` | 3 | 3 = safe page reference on every step; 2 = opt-in typed values; 1 = legacy. Older schemas stay readable; the writer picks the lowest schema that holds the content (`schemaVersionOf`). |
| Guide format | `taskGuideFormat` | `deskilo.task-guide` | marker of an encoded guide |
| Guide schema | `taskGuideSchemaVersion` | 3 | newest version this build writes and reads; 1 and 2 read unchanged |
| Action version | `ActionSpec.version` | per action, default 1 | a recording or guide names the version it was made against; replay refuses an unknown action or version |
| Package | `pubspec.yaml` | 0.1.0 | not published; a breaking change to a public type or a schema bump is a minor bump while 0.x |

A schema is only ever raised, never reinterpreted. A new field is optional
for older readers or the schema number goes up.

## Host adapter obligations

A host that binds this package must:

1. Build one `ActionRegistry` with every surface, action (with its version),
   outcome and payload vocabulary it records. Nothing outside the registry is
   captured; an unknown name is dropped, never stored.
2. Provide a `RecordingWriter` that is bounded and never blocks the caller:
   a failed or stalled write costs completeness, never the user's action.
3. Provide a `ReplayAuthorizer` that answers from the CURRENT account,
   membership, rights, feature and workspace at the moment of the question.
   A recording or a guide is never a permission.
4. Provide an `ActionExecutor` that runs the existing command (with its own
   confirmation and its own server-side checks), and reports the actual
   outcome. An unknown outcome is never repeated.
5. Keep the fixed replay order of `ReplayCoordinator`: known action and
   version, current scope, authorize now, confirmation, execute, record the
   outcome.
6. Keep the guide codec/compiler (if any) decoding every schema the package
   still reads.

The neutral host in `example/inspection_checklist.dart` implements all of
the above with a fake writer; its tests are the executable form of this list.

## Dependencies and licence

Runtime: `crypto` (BSD-3-Clause) and `meta` (BSD-3-Clause). Dev: `lints`,
`test` (BSD-3-Clause). No Flutter, no `package:deskilo`, no path dependency;
`test/independence_test.dart` pins this. The package is part of the
repository and carries its licence (AGPL-3.0-or-later, see the root
`LICENSE` and `LICENSE-EXCEPTIONS.md`); every source file has the SPDX line.

## Independent evidence

The package resolves, analyzes and tests without the app. CI runs, in this
directory (`.github/workflows/quality.yml`, step "Tests of the task
recording package"):

```
dart pub get && dart analyze --fatal-infos && dart test
```

Recorded at C3: `dart pub get` resolved 50 packages in the package alone,
`dart analyze --fatal-infos` reported no issues, `dart test` passed.
