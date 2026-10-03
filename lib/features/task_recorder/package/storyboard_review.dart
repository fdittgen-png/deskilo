// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — the reviewed storyboard, kept inside a task package.
//
// A storyboard is derived from its recording, so the package does not
// copy it: it keeps what the PERSON decided — the order, the omitted
// frames, the captions, the durations, the redactions and the approvals
// — keyed by the step each frame shows, and the recording revision those
// decisions were made for. Reopening the package derives the storyboard
// again and replays the decisions through the storyboard's own edit
// rules, so a redaction still withdraws an approval it would have
// withdrawn, an approval can only land on a drawn illustration, and a
// review made for another revision of the recording is set aside
// (stale) rather than applied to steps it never saw.
//
// Untrusted like the rest of the package: unknown keys, unknown steps,
// overlong captions, invalid rectangles and too many redactions are
// refused, never trimmed into something else.

import 'dart:convert';

import '../../../core/trace/trace_logger.dart';
import '../storyboard/storyboard.dart';

const String storyboardReviewFormat = 'deskilo.task-storyboard-review';
const int storyboardReviewVersion = 1;

/// One frame's decisions.
class FrameReview {
  const FrameReview({
    required this.stepSeq,
    required this.approved,
    required this.omitted,
    required this.caption,
    required this.durationMs,
    this.redactions = const [],
  });

  final int stepSeq;
  final bool approved;
  final bool omitted;
  final String caption;
  final int durationMs;
  final List<NormalizedRect> redactions;
}

/// What a person decided about a storyboard.
class StoryboardReview {
  const StoryboardReview({required this.sourceRevision, required this.frames});

  /// The recording revision the decisions were made for.
  final String sourceRevision;

  /// In the storyboard's order.
  final List<FrameReview> frames;

  factory StoryboardReview.of(Storyboard s) => StoryboardReview(
    sourceRevision: s.sourceRevision,
    frames: [
      for (final f in s.frames)
        FrameReview(
          stepSeq: f.stepSeq,
          approved: f.approved,
          omitted: f.omitted,
          caption: f.caption,
          durationMs: f.durationMs,
          redactions: f.redactions,
        ),
    ],
  );

  Map<String, Object?> toJson() => {
    'format': storyboardReviewFormat,
    'version': storyboardReviewVersion,
    'source_revision': sourceRevision,
    'frames': [
      for (final f in frames)
        {
          'step_seq': f.stepSeq,
          'approved': f.approved,
          'omitted': f.omitted,
          'caption': f.caption,
          'duration_ms': f.durationMs,
          'redactions': [
            for (final r in f.redactions) [r.left, r.top, r.width, r.height],
          ],
        },
    ],
  };

  String toText() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Reads a review strictly; null when anything is off.
  static StoryboardReview? parse(
    String text, {
    StoryboardLimits limits = const StoryboardLimits(),
  }) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return null;
    }
    const rootKeys = {'format', 'version', 'source_revision', 'frames'};
    if (json is! Map ||
        !json.keys.every(rootKeys.contains) ||
        json['format'] != storyboardReviewFormat ||
        json['version'] != storyboardReviewVersion) {
      return null;
    }
    final revision = json['source_revision'];
    final raw = json['frames'];
    if (revision is! String ||
        !RegExp(r'^[0-9a-f]{12}$').hasMatch(revision) ||
        raw is! List ||
        raw.length > 1000) {
      return null;
    }
    const frameKeys = {
      'step_seq',
      'approved',
      'omitted',
      'caption',
      'duration_ms',
      'redactions',
    };
    final frames = <FrameReview>[];
    final seen = <int>{};
    for (final f in raw) {
      if (f is! Map || !f.keys.every(frameKeys.contains)) return null;
      final seq = f['step_seq'];
      final approved = f['approved'];
      final omitted = f['omitted'];
      final caption = f['caption'];
      final duration = f['duration_ms'];
      final rects = f['redactions'] ?? const <Object?>[];
      if (seq is! int ||
          !seen.add(seq) ||
          approved is! bool ||
          omitted is! bool ||
          caption is! String ||
          caption.trim().isEmpty ||
          caption.length > limits.maxCaptionLength ||
          RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F]').hasMatch(caption) ||
          duration is! int ||
          duration < limits.minDurationMs ||
          duration > limits.maxDurationMs ||
          rects is! List ||
          rects.length > limits.maxRedactions) {
        return null;
      }
      final redactions = <NormalizedRect>[];
      for (final r in rects) {
        if (r is! List || r.length != 4 || r.any((v) => v is! num)) {
          return null;
        }
        final rect = NormalizedRect(
          (r[0] as num).toDouble(),
          (r[1] as num).toDouble(),
          (r[2] as num).toDouble(),
          (r[3] as num).toDouble(),
        );
        if (!rect.isValid) return null;
        redactions.add(rect);
      }
      frames.add(
        FrameReview(
          stepSeq: seq,
          approved: approved,
          omitted: omitted,
          caption: caption,
          durationMs: duration,
          redactions: redactions,
        ),
      );
    }
    return StoryboardReview(sourceRevision: revision, frames: frames);
  }
}

/// Why a review was not applied.
enum ReviewOutcome { applied, stale, invalid }

/// Replays [review] on [derived], the storyboard derived again from the
/// same recording, through the storyboard's own edit rules.
({Storyboard storyboard, ReviewOutcome outcome}) applyReview(
  Storyboard derived,
  StoryboardReview review,
) {
  if (review.sourceRevision != derived.sourceRevision) {
    return (storyboard: derived, outcome: ReviewOutcome.stale);
  }
  final steps = derived.frames.map((f) => f.stepSeq).toList();
  if (review.frames.length != steps.length ||
      !review.frames.every((f) => steps.contains(f.stepSeq))) {
    return (storyboard: derived, outcome: ReviewOutcome.invalid);
  }
  try {
    var s = derived;
    // The order first, then what changes the pictures, approvals last:
    // an approval only stands on the picture it was given for.
    for (var to = 0; to < review.frames.length; to++) {
      final from = s.frames.indexWhere(
        (f) => f.stepSeq == review.frames[to].stepSeq,
      );
      if (from != to) s = s.move(from, to);
    }
    for (var i = 0; i < review.frames.length; i++) {
      final f = review.frames[i];
      if (s.frames[i].caption != f.caption) s = s.setCaption(i, f.caption);
      if (s.frames[i].durationMs != f.durationMs) {
        s = s.setDuration(i, f.durationMs);
      }
      for (final r in f.redactions) {
        s = s.addRedaction(i, r);
      }
      if (s.frames[i].omitted != f.omitted) s = s.setOmitted(i, f.omitted);
    }
    for (var i = 0; i < review.frames.length; i++) {
      if (review.frames[i].approved && !s.frames[i].approved) {
        s = s.setApproved(i, true);
      }
    }
    return (storyboard: s, outcome: ReviewOutcome.applied);
  } on StoryboardEditException catch (e, st) {
    TraceLogger.instance.warn(
      'recorder',
      'storyboard review not applied (${e.runtimeType})',
      stackTrace: st,
    );
    return (storyboard: derived, outcome: ReviewOutcome.invalid);
  }
}
