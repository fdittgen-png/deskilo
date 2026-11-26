<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Data integrity — what a read may answer, what an edit may change, and what a failure is called

## Baseline

- Refs: #4489 (the fast line), #4479 and #4485 (master data), #4413 (one failure root), #4414 (the read-failure view), #4416 (error reports), #3680 (a failed read is not empty)
- Canonical sources: `lib/core/failure/app_failure.dart` (the four failures, the command outcomes), `lib/core/data/app_failure_from.dart` (the one conversion, `runCommand`), `lib/core/trace/guarded.dart` (the guarded save and read), `lib/core/cache/read_failure.dart` (why a read failed), `lib/core/trace/trace_reporter.dart` (what leaves the device)
- This page states the rules every data path keeps, whatever its domain. A domain page (`stock_operations.md`, `commercial-line.md`) states its own on top of them.

## Concepts and identity

| concept | meaning | identity |
|---|---|---|
| required read | a read whose answer decides what a form may file: the VAT rates of an expense, the units of an item | the provider and its scope (workspace, person, installation) |
| empty answer | a successful read that found nothing | the same read; it is a value, not the absence of one |
| failed read | a read that did not answer: no connection, no access, an answer of another shape | the error as caught, classified once by `classifyReadFailure` |
| loaded basis | the record as an editor read it, whole | the record's own id or key |
| edit | what the person changed in the editor's own controls | the field it belongs to; a child (a choice, a label) by its key, never by its position or its text |
| answer | a refusal the server worded, a lost connection, a request held for approval | a `Refusal` with its code, a `TransportFailure` |
| fault | an answer that could not be read, or a defect of the app | `Unreadable`, `Defect`, with the stack of the first catch |
| error report | a fault as it may leave the device | where it was recorded, its kind, its code and its redacted stack; never its sentence |

## Relationships and cardinalities

| question | answer | qualification |
|---|---|---|
| For one required read, how many answers may a form act on? | exactly one, and only a successful one | an empty answer is successful; a failed read is none |
| For one saved edit, how many fields change? | the ones the person changed | every other field, shown by the editor or not, is saved as it was read |
| For one child of a record (a choice of a question), how many keys over its life? | exactly one | its labels, order and state change; its key never does |
| For one stored reference the current list does not offer (a country), how many times is it offered? | once, as it was stored | until the person picks another; it is never cleared by opening or saving |
| For one fault, how many error entries in the trace? | one | at the boundary that caught it first; an adapter above throws it again with the same stack |
| For one fault, how many reports to the installation in an hour? | at most one | repeats are counted on the device and said in the local trace |

## States and transitions

Declared states: `reading`, `answered`, `failed`.

| from | event | guard | to | effects |
|---|---|---|---|---|
| (none) | a form asks for a required read | always | `reading` | nothing is offered and nothing can be filed from the form yet |
| `reading` | the read answers | the answer parses | `answered` | the form offers what was read; an empty answer is offered as empty |
| `reading` | the read throws | always | `failed` | the failure is said in words a person can act on, with a way to ask again; the form does not open, or go on, as if the answer were empty |
| `failed` | the person asks again | always | `reading` | the failed read is dropped and the server is asked again |

## Invariants

| invariant | enforcement |
|---|---|
| a failed required read is never an empty answer | `expenseVatPercents` throws what the read threw; `whenExpenseVatRead` reads the rates before an expense form opens, says a failure and keeps the form closed; the receipt sheet shows `ReadFailureBanner`. `test/lint/failed_read_is_not_empty_test.dart` counts every `.value ?? <empty>` and every guarded read whose fallback is an empty collection, per area, and the counts only fall |
| an edit keeps what it did not touch | an editor builds what it saves from the loaded basis with a copy that changes only what it is given (`WorkspaceField.copyWith` and `asked`, `WorkspaceFieldOption.copyWith`), never from its controls alone |
| a child is edited by its key | `QuestionChoiceDraft` keeps the choice as read; a label is merged per language, the key is never an input; a new line never takes a key in use |
| a stored reference outside the current list is kept | `CountryCatalog.addressCodes` offers the stored country with the catalogue's |
| an unreadable answer is not a defect, and not empty | `appFailureFrom` reads `JsonShapeException` and `CachedReadInvalid` as `Unreadable` |
| the stack of a failure is the stack of its first catch | `CommandRefused.stack` and `CommandUnreached.stack`, set by `runCommand`; `valueOrThrow` throws with it |
| a fault is an error in the trace, an answer a warning | `isReportableFailure`, read by `runCommand` and by the guarded save, read and action; a refusal with one of the server's own `DK` codes is a warning |
| the reporter is bounded and never reports itself | one report at a time, a waiting line of eight, the hourly budget, one report per fault and hour; a line of the reporter's own area is never sent whatever its level; what waited when the reporter stops is not sent |
| what the reporter drops is counted and said | every drop has a reason (repeated, over budget, line full, not sent, not stored) and a line in the local trace; an answer other than `stored` is not counted as stored |

## Processing

A form that needs a required read asks for it before it opens or while it shows a loading state, through `guardRead`, and decides on the three states above. A save passes through `runCommand`, `guardSave` or `runGuarded`: each traces what it caught once, at the level `isReportableFailure` gives it, and answers an outcome or a sentence.

The reporter listens to the trace. It sends an error once, in the person's own installation, while the Privacy switch is on; it is rebuilt when the session, the switch or the installation changes, and what waited is dropped then.

Not delivered, and stated so: the server side of the custom-question save still recreates label rows without their help text and guards the removal of a choice for multi-choice answers only; a `StateError` is still read as a refusal raised before anything was sent, whatever raised it; the units of a picker still fall back to the built-in six when their read fails; an error report carries no occurrence count and no event id, so the installation cannot tell a repeat from a resend.

## Evidence

- `test/features/money/input_vat_test.dart`: rates that could not be read are said and no expense form opens; asking again reads again; input VAT off and a readable catalogue behave as before.
- `test/features/workspace/question_editor_test.dart`: a title-only save keeps the group, the help texts, the place and every rule; the bounds of a date survive; emptying the maximum removes that rule alone; every choice is sent as read; a choice is reworded in one language under the same key; a choice is retired, moved and added, and a new one never takes a key in use.
- `test/features/profile/address_edit_test.dart` and `test/core/country/country_catalog_address_codes_test.dart`: a stored country the catalogue does not offer is shown and saved as it was read.
- `test/core/failure/app_failure_from_test.dart` and `test/core/failure/outcome_or_throw_test.dart`: an unreadable row is `Unreadable`; a command keeps the stack of what it caught and it is thrown again with it; a fault is traced as an error, an answer as a warning.
- `test/core/trace/guard_save_test.dart`: the guarded save and read trace a fault as an error and a coded refusal as a warning.
- `test/core/trace/trace_reporter_test.dart`: the budget, the waiting line, one report per fault and hour, the answer read, the reporter's own lines never sent, nothing sent after it stops.
- Not tested yet: a required read denied or revoked while a form is open; the same rules through the setup questionnaire, an import and a direct call to the server.
