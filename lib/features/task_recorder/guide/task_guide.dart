// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — a guided task: a reviewed procedure derived from a recording.
//
// Declarative steps only:
//   * instruction — words to read; the person acknowledges them;
//   * perform     — the person does a registered action on a real form;
//                   for a command, the step waits for a NAMED outcome;
//   * manual      — something the recorder could not see (a protected or
//                   uninstrumented screen); acknowledged, never verified.
// A perform step may carry ONE level of recovery (what to do when the
// command is refused); there are no jumps, loops, expressions, scripts
// or downloaded code, and nothing in a guide ever enters a value or
// starts a command by itself.
//
// A guide's expected outcome is the author's expectation, not a claim
// that the original person achieved it: the compiler keeps the source
// recording's digest for provenance and drops what it observed.

import '../domain/action_registry.dart';

/// The format marker of an encoded guide.
const String taskGuideFormat = 'deskilo.task-guide';

/// The guide schema version this build writes and the newest it reads.
/// 2 (#1867 live guide): a perform step may name its control ([GuideStep.
/// target]) and the app message it shows ([GuideStep.label]). Schema 1
/// guides read unchanged — they simply carry no target.
/// 3 adds an explicit, registered destination to every kind of step.
const int taskGuideSchemaVersion = 3;

/// What a guide step asks of the person.
enum GuideStepKind {
  instruction('instruction'),
  perform('perform'),
  manual('manual');

  const GuideStepKind(this.wire);
  final String wire;

  static GuideStepKind? fromWire(Object? raw) =>
      values.where((v) => v.wire == raw).firstOrNull;
}

/// The bounds a guide lives within.
class GuideLimits {
  const GuideLimits({
    this.maxSteps = 100,
    this.maxRecoverySteps = 5,
    this.maxTextLength = 500,
    this.maxTitleLength = 120,
    this.maxBytes = 256 * 1024,
  });

  final int maxSteps;
  final int maxRecoverySteps;
  final int maxTextLength;
  final int maxTitleLength;
  final int maxBytes;
}

/// One step of a guide.
class GuideStep {
  const GuideStep({
    required this.id,
    required this.kind,
    this.action,
    this.expectedOutcomes = const {},
    this.text,
    this.optional = false,
    this.recovery = const [],
    this.manualCategory,
    this.target,
    this.label,
    this.destination,
  });

  /// Unique within the guide: 'g1', 'g2', 'g1r1'.
  final String id;
  final GuideStepKind kind;

  /// On a perform step: the registered action the person does.
  final String? action;

  /// On a perform step for a command: the outcomes that complete it.
  final Set<String> expectedOutcomes;

  /// The author's words. Untrusted when imported; shown as text only.
  final String? text;

  /// Whether the person may skip it. A skipped step is "skipped", never
  /// "done".
  final bool optional;

  /// On a command step: what to do when it is refused. One level only.
  final List<GuideStep> recovery;

  /// On a manual step: which kind of protected screen it stands for, if
  /// any ('payment', 'authentication', …), from [ProtectedSurface].
  final ProtectedSurface? manualCategory;

  /// On a perform step: the control or screen it happens on, as the
  /// recorder names it — a string key from the generated vocabulary, its
  /// `{}` pattern, a route pattern, or a command's message. The live guide
  /// finds the mounted control by it; a step without one matches its
  /// action anywhere.
  final String? target;

  /// The app message (by key) the control showed, to say what to tap.
  final String? label;

  /// A registered page, optionally a known Me tab. Never a record ID.
  final String? destination;

  bool get isCommand => expectedOutcomes.isNotEmpty;

  GuideStep copyWith({
    String? text,
    bool? optional,
    String? destination,
    List<GuideStep>? recovery,
  }) => GuideStep(
    id: id,
    kind: kind,
    action: action,
    expectedOutcomes: expectedOutcomes,
    text: text ?? this.text,
    optional: optional ?? this.optional,
    recovery: recovery ?? this.recovery,
    manualCategory: manualCategory,
    target: target,
    label: label,
    destination: destination ?? this.destination,
  );
}

/// A guide: a title, its steps, and where it came from.
class TaskGuide {
  TaskGuide({
    required this.actionContractVersion,
    required List<GuideStep> steps,
    this.title,
    this.sourceDigest,
  }) : steps = List.unmodifiable(steps);

  final int actionContractVersion;
  final String? title;

  /// The digest of the recording it was derived from (provenance only).
  final String? sourceDigest;
  final List<GuideStep> steps;

  /// Every registered action the guide needs, recovery included.
  Set<String> get requiredActions => {
    for (final s in steps) ...[
      if (s.action != null) s.action!,
      for (final r in s.recovery)
        if (r.action != null) r.action!,
    ],
  };
}
