# Task recorder file formats

The task recorder (#1865) writes and reads three local file formats. All
three are read through one validator each, are untrusted when they come
from a file, and never carry an account, a workspace, a server address,
a token, a request id or a value somebody typed.

| File | Format id | Version | Reader |
|---|---|---|---|
| `*.json` (a recording) | `deskilo.task-recording` | `schema_version` 1 | `lib/features/task_recorder/domain/task_recording_codec.dart` (`decodeRecording`) |
| `*.deskilo-task.zip` (a task package) | `deskilo.task-package` | `package_version` 1, or 2 with a storyboard | `lib/features/task_recorder/package/task_package.dart` (`readTaskPackage`) |
| `deskilo-guide.json` (a guide draft) | `deskilo.task-guide` | `schema_version` 1 | `lib/features/task_recorder/guide/guide_codec.dart` (`decodeGuideText`) |

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

* Recording, review, JSON and package export: Help → *Record this task*
  (`/task-recorder`, needs the workspace feature `taskRecorder`).
* The local workbench, with no account: Help → *Open a task file*
  (`/task-workbench`). It opens a recording or a package, edits a
  private copy, saves it again, reviews the storyboard, makes the
  registered outputs (Word today; video when its generator is
  registered) and creates a guide draft.
* Registering a new output: implement `TaskOutputGenerator`
  (`package/task_output.dart`) and add it to
  `export/output_registry.dart`.
* Recording a new form: register its surface, actions and outcomes in
  `domain/action_registry.dart`, call `recordTaskStep` /
  `recordTaskAttempt` (`presentation/recorder_seam.dart`) at the
  callbacks that already exist, classify its route in
  `coverage/coverage_manifest.dart` (recorded, excluded with its
  protected category, or planned with its owner), and add words for the
  new identifiers in `presentation/recorder_labels.dart`.
* Offline: in a browser, the workbench's *Keep it on this device* card
  registers `web/task_tool_sw.js` (network first; only this app's own
  GET requests and the static font/engine hosts; never a backend call
  or a write). The installed web app also offers the workbench as a
  shortcut. On a native build the app is already local.
