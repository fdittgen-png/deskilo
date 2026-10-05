# Task recorder file formats

The task recorder (#1865) writes and reads three local file formats. All
three are read through one validator each, are untrusted when they come
from a file, and never carry an account, a workspace, a server address,
a token, a request id or a value somebody typed.

| File | Format id | Version | Reader |
|---|---|---|---|
| `*.json` (a recording) | `deskilo.task-recording` | `schema_version` 1 | `lib/features/task_recorder/domain/task_recording_codec.dart` (`decodeRecording`) |
| `*.deskilo-task.zip` (a task package) | `deskilo.task-package` | `package_version` 1, or 2 with a storyboard | `lib/features/task_recorder/package/task_package.dart` (`readTaskPackage`) |
| `deskilo-guide.json` (a guide draft) | `deskilo.task-guide` | `schema_version` 2 (reads 1) | `lib/features/task_recorder/guide/guide_codec.dart` (`decodeGuideText`) |

## The recording

A recording is a list of steps, each naming a **registered** surface,
action and (for a command) outcome from
`domain/action_registry.dart` (`action_contract_version` 1). Payload
values are categories from the finite vocabulary in
`domain/safe_payload.dart`; anything else is the placeholder
`withheld`. Times are milliseconds since the recording started. A
command is recorded as an `attempted` step with a recording-local alias
(`op1`, `op2`, …) *before* the command runs; its outcome
(`confirmed`, `pending`, `refused`, `outcome_unknown`) answers that
alias. `kind` is `source` or `edited`; an edited copy names its source
by `source_digest` (SHA-256 of the source's segments, steps and end) and
keeps each step's original `source_seq`. `completeness` is `complete`,
`partial` or `interrupted`; a recording may claim less than it earned,
never more.

Unknown keys are refused anywhere. A step naming an action this build
does not know is kept as an `unrecorded` step without payload, and the
recording reads as a transcript only (not runnable).

Limits (`RecordingLimits`): 500 steps, 512 KiB, 30 minutes, 50
segments, 8 prerequisites, title 120 and note 500 characters.

## The task package

`<name>.deskilo-task.zip` contains exactly:

| Path | Required | What |
|---|---|---|
| `manifest.json` | yes | format, `package_version`, product, the recording's summary (`schema_version`, `action_contract_version`, `kind`, `completeness`) and the size and SHA-256 of every other file, plus the maker's `claims` |
| `recording.json` | yes | the recording above, byte for byte the plain export |
| `transcript.md` | no | the steps as readable text in the maker's language |
| `storyboard.json` | no (version 2) | the reviewed storyboard's decisions (`deskilo.task-storyboard-review` version 1): per recorded step, its order, omitted, caption, duration, redactions and approval, and the recording revision they were made for |
| `media/<name>.(png\|jpg\|jpeg\|webp\|mp4\|webm\|vtt)` | no | approved images, video and captions, each listed in the manifest |

A checksum says a file is the one the manifest listed — not who made it,
not that it is true, not that anybody may use it. `claims` (at most 8
lower-case keys, 200 characters each) are shown as what the file says
and grant nothing; every import is a private, untrusted draft.

Reading is fail-closed: the package is refused when it is larger than
64 MiB, not a zip, has more than 64 entries, has any path outside the
table above (so traversal, absolute, drive or UNC paths, backslashes,
upper case, non-ASCII names, nested archives and scripts are refused),
a duplicate entry, a symbolic link, an encrypted entry, a compression
other than stored or deflate, an entry whose inflated size passes its
cap (1 MiB for text, 48 MiB for media, 96 MiB in all — counted while
inflating, so a forged size or a zip bomb stops at the cap), inflated
bytes that differ from the declared size, an unlisted, missing or
altered file, a manifest that disagrees with its recording, or a
recording the recording validator refuses. Errors are fixed codes; a
file name from the package is never echoed or used as a path.

The same recording always packs to the same bytes (fixed timestamps).

The storyboard itself is not copied: reopening a package derives it again
from the recording and replays the decisions through the storyboard's own
edit rules (a redaction still withdraws an approval, an approval only
lands on a drawn illustration). A review made for another recording
revision is set aside, not applied. The approved illustrations travel as
`media/frame-<step>.png`, listed in the manifest like any media.

## The guide draft

Steps are `instruction`, `perform` (a registered action; for a command,
`expected_outcomes` from that action's outcomes) and `manual`. A
command step may carry one level of `recovery` steps. There are no
jumps, loops, expressions or scripts. Limits (`GuideLimits`): 100 steps,
5 recovery steps, 500 characters of text, 256 KiB.

## Versioning

* Adding an action, an outcome, a surface, a payload field or a value
  keeps every version number: older readers keep such steps as
  unrecorded/transcript-only.
* Removing or changing the meaning of an identifier bumps
  `action_contract_version`; identifiers are never reused.
* A structural change to a file bumps its `schema_version` /
  `package_version`. Readers refuse a newer version than they know.
* The shared fixtures in `test/features/task_recorder/fixtures/` are
  produced by the real recorder and pinned byte for byte
  (`recording_fixtures_test.dart`); regenerate them with
  `UPDATE_RECORDER_FIXTURES=1` when the producer changes on purpose.

## Where the tools are

* Recording, review, JSON and package export: Help → *Record this task*,
  the drawer's or Me → Account's *Record a task* (`/task-recorder`,
  needs the workspace feature `taskRecorder`).
* The local workbench, with no account: Help → *Open a task file*
  (`/task-workbench`). It opens a recording or a package, edits a
  private copy, saves it again, reviews the storyboard, makes the
  registered outputs (Word, silent MP4 where supported, and WebVTT captions) and creates a guide draft.
* Registering a new output: implement `TaskOutputGenerator`
  (`package/task_output.dart`) and add it to
  `export/output_registry.dart`.
* Recording a new form: give every control a `ValueKey<String>` and
  guard its commands with `runGuarded`: the generic layer then records
  it (below). For precise steps (categories such as a period or a
  refusal reason), register its surface, actions and outcomes in
  `domain/action_registry.dart`, call `recordTaskStep` /
  `recordTaskAttempt` (`presentation/recorder_seam.dart`) at the
  callbacks that already exist, classify its route in
  `domain/coverage_manifest.dart` (recorded, excluded with its
  protected category, or planned with its owner), and add words for the
  new identifiers in `presentation/recorder_labels.dart`; a seam wins
  over the generic layer for the same tap or command.
* Offline: in a browser, the workbench's *Keep it on this device* card
  registers `web/task_tool_sw.js` and verifies a complete, hashed build
  snapshot before reporting readiness. Online requests remain network-first;
  only manifest-listed assets can be served offline, never backend responses.
  A failed update preserves the previous complete snapshot. Removal waits
  for cache deletion. Browser storage eviction revokes readiness.
  Build with `--no-web-resources-cdn`, then run
  `dart run tool/task_tool_manifest.dart` (included in the web workflow). The installed web app also offers the workbench as a
  shortcut. On a native build the app is already local.

## The generic layer (#2142)

On every screen that is neither protected nor the recorder's own,
`presentation/ui_capture.dart` notes, while a recording is live:

| Step | Named by | Never |
|---|---|---|
| `ui.open_screen` | the route PATTERN (`/member/:memberId`), and its bar's title when that is one of the app's messages | the path, an id, a query |
| `ui.tap` | the control's string key — a literal of the source, or its pattern with the dynamic parts as `{}` (`perm-{}-{}`) — and the first app message it shows | coordinates, text that is not an app message |
| `ui.commit_field` | the field's key and its decoration's label, when the field loses focus | the value (it is never read) |
| `ui.command` (+ result) | the literal `message:` of its `runGuarded` call; the result is done, pending (held for validation), refused (with its category) or unknown | the error text, the data sent |
| `ui.open_window` / `ui.close_window` | — (a dialog, sheet or menu on the root navigator) | its contents |

The names come from `domain/ui_vocabulary.g.dart` and
`presentation/ui_labels.g.dart`, generated by
`dart run tool/recorder_vocabulary.dart` (`--report` also prints how
many controls have no key, per feature). A key, message or label the
lists do not know is recorded as a gap (*an unnamed control*), never as
raw text, so a list that lags the source is safe. Labels are stored as
message KEYS and shown back in the reader's language. Reading a file,
an older build drops a generic name it does not know rather than
refusing the file. `test/lint/recorder_keys_test.dart` keeps the
number of unkeyed controls falling.


## Operational boundaries

A guide completes a command only from that attempt's result token. Duplicate,
unrelated, previous-run and pre-pause results cannot complete a new attempt.
Guide edits use atomic replacement, preserving the saved version on failure.
Unnamed, unknown and dynamic identity-pattern controls become manual steps;
authors should explain them before sharing. Manual means acknowledged, not
verified. Multiple matching controls produce no arbitrary pointer.

Booking/calendar, roles/validation and generic safe capture remain available.
Protected screens remain manual/excluded; planned semantic adapters and
workspace/global publication are not supplied by generic capture/file sharing.
Physical-device and stock-reader qualification remain separate release evidence.
`node tool/web/task_offline_probe.mjs` tests the real worker in fresh Chromium:
offline reopening, corrupt updates, eviction, backend exclusion and removal.
