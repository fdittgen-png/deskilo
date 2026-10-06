# ADR 0037 — A recording may capture values, by the person's choice

**Status:** accepted · **Date:** 2026-10-06

## Context

The task recorder was private by construction: a step names a registered
action and a finite-vocabulary payload, and a field change says which field
was committed, never its value. That guarantee is right for a recording made
to teach a task. It is wrong for a recording attached to an issue: a developer
who receives "the user opened Reserve, picked a day and a period, typed a
reason" cannot reproduce the problem without the day, the period and the
reason. The owner asked for the recording to carry the values of each
operation, so the file alone is enough.

## Decision

A recording may capture values, and only when the person chooses it for that
recording.

* **Opt-in, per recording.** A switch on the start screen ("Capture values
  (for issue reports)"), off every time and never remembered. The recording
  says so in its header (`values_mode: captured`, schema 2); an ordinary
  recording is still written as schema 1 and carries no value, so every
  existing guarantee and every existing file is unchanged.
* **A separate typed channel**, not the payload: `values` on a step, a map of
  short names to a bounded text, a number, a flag, or a redaction marker
  (`step_values.dart`). The finite-vocabulary payload keeps its strict
  validator and still says WHICH field and WHICH category.
* **Redaction is not optional.** A field that hides what is typed, or whose
  autofill hint, key or label says it holds a credential, a payment
  identifier, a tax or national identifier or personal contact data, is
  recorded as redacted with only its length — with the switch on. Protected
  surfaces (sign-in, payment, provider, secrets, messenger, identity,
  operator) stay one excluded marker. Ids never enter.
* **The validator is the gate.** A file cannot carry values it does not
  declare, values of another shape, or more than the recorder would have
  kept; an older build refuses a schema-2 file.
* **Leaving the app is a decision.** Saving or sharing a recording that holds
  values asks for a confirmation; the transcript and the Word document list
  the values so the person sees exactly what travels.

## Consequences

* An issue can carry a recording that reproduces it: dates, periods, the
  resource, quantities, the text typed into ordinary fields, the state of
  switches.
* The canary guarantees stay for every recording that did not opt in, and for
  the redacted classes even when it did; new tests pin both.
* A free-text field the redaction words do not name (a field called "Notes")
  is kept when the switch is on: that is what the person asked for, and the
  confirmation before saving says it.
* A control the generic layer cannot see as a tap (a switch, a checkbox, a
  chip) is noted only while values are captured; the other recordings are
  unchanged.
