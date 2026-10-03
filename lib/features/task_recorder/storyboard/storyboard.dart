// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — the ONE reviewed storyboard the Word document and the video
// both read.
//
// A storyboard is derived from one frozen recording (its content
// revision is kept) and holds, per recorded step: the narrative title
// and detail lines, where its picture comes from, the logical region to
// emphasise, the caption and alt text, a bounded presentation duration
// and whether a person approved the illustration. The semantic step id
// (`stepSeq`) is the identity; the emphasis rectangle is image-relative
// and only ever DRAWN, never used to replay a tap.
//
// Every edit returns a new storyboard with the next revision, so an
// export frozen on one revision cannot be changed under it, and every
// edit that changes what a frame's picture shows withdraws that frame's
// approval: a stale approved picture cannot survive a privacy edit.
import 'safe_scene.dart';

/// Where a frame's picture comes from. A recreated scene is labelled as
/// an illustration everywhere it appears, never as a screenshot.
enum IllustrationSource {
  /// Drawn off-screen from the allow-listed scene model.
  recreatedScene,

  /// A text slide made from the step's safe facts.
  textSlide,

  /// A protected surface: an exclusion card, never its content.
  exclusionCard,
}

/// What the recording says about a frame's step.
enum FrameStatus {
  /// Captured by the recorder.
  observed,

  /// Written by a person while editing; not observed.
  authored,

  /// A command with no answer, or a step this build cannot describe.
  gap,

  /// A protected surface.
  excluded,
}

/// A rectangle relative to the illustration, each value within 0..1.
class NormalizedRect {
  const NormalizedRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  bool get isValid =>
      left >= 0 &&
      top >= 0 &&
      width > 0 &&
      height > 0 &&
      left + width <= 1.0001 &&
      top + height <= 1.0001;

  @override
  bool operator ==(Object other) =>
      other is NormalizedRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// Bounds every storyboard lives within.
class StoryboardLimits {
  const StoryboardLimits({
    this.minDurationMs = 2000,
    this.maxDurationMs = 15000,
    this.defaultDurationMs = 4000,
    this.maxCaptionLength = 200,
    this.maxRedactions = 8,
    this.maxIllustrated = 60,
  });

  final int minDurationMs;
  final int maxDurationMs;
  final int defaultDurationMs;
  final int maxCaptionLength;
  final int maxRedactions;

  /// Frames past this many get a text slide instead of a drawn scene:
  /// the visual coverage is bounded, the procedure is not.
  final int maxIllustrated;
}

/// One step of the storyboard.
class StoryboardFrame {
  const StoryboardFrame({
    required this.stepSeq,
    required this.title,
    required this.details,
    required this.caption,
    required this.altText,
    required this.source,
    required this.status,
    required this.durationMs,
    this.scene,
    this.highlight,
    this.redactions = const [],
    this.attemptSeq,
    this.omitted = false,
    this.approved = false,
  });

  /// The recorded step this frame shows: its semantic identity.
  final int stepSeq;
  final String title;
  final List<String> details;

  /// The on-video instruction and the document's caption.
  final String caption;
  final String altText;
  final IllustrationSource source;
  final FrameStatus status;
  final int durationMs;

  /// The allow-listed scene, for [IllustrationSource.recreatedScene].
  final SafeScene? scene;

  /// The logical control to emphasise, image-relative.
  final NormalizedRect? highlight;

  /// Opaque boxes painted over the finished picture before encoding.
  final List<NormalizedRect> redactions;

  /// On an outcome: the step of the command it answers. Ordering keeps
  /// the outcome after it.
  final int? attemptSeq;
  final bool omitted;

  /// Whether a person approved this frame's illustration for export.
  final bool approved;

  /// What the rendered picture depends on: two frames with the same key
  /// render the same pixels, and a cache keyed by it cannot serve a
  /// picture from before a redaction.
  int get renderKey => Object.hash(source, scene, Object.hashAll(redactions));

  StoryboardFrame copyWith({
    String? caption,
    int? durationMs,
    List<NormalizedRect>? redactions,
    bool? omitted,
    bool? approved,
  }) {
    final pictureChanged = caption != null || redactions != null;
    return StoryboardFrame(
      stepSeq: stepSeq,
      title: title,
      details: details,
      caption: caption ?? this.caption,
      altText: altText,
      source: source,
      status: status,
      durationMs: durationMs ?? this.durationMs,
      scene: scene,
      highlight: highlight,
      redactions: redactions ?? this.redactions,
      attemptSeq: attemptSeq,
      omitted: omitted ?? this.omitted,
      approved: approved ?? (pictureChanged ? false : this.approved),
    );
  }
}

/// A refused edit. The storyboard it was asked of is unchanged.
class StoryboardEditException implements Exception {
  const StoryboardEditException(this.reason);

  /// `order`, `bounds` or `noIllustration`.
  final String reason;

  @override
  String toString() => 'StoryboardEditException($reason)';
}

/// A reviewed storyboard revision.
class Storyboard {
  Storyboard({
    required this.revision,
    required this.sourceRevision,
    required this.languageCode,
    required List<StoryboardFrame> frames,
    this.limits = const StoryboardLimits(),
  }) : frames = List.unmodifiable(frames);

  /// Increases with every edit.
  final int revision;

  /// The content revision of the recording it was derived from.
  final String sourceRevision;
  final String languageCode;
  final List<StoryboardFrame> frames;
  final StoryboardLimits limits;

  /// The frames an export shows, in order.
  Iterable<StoryboardFrame> get included => frames.where((f) => !f.omitted);

  Storyboard _next(List<StoryboardFrame> frames) => Storyboard(
    revision: revision + 1,
    sourceRevision: sourceRevision,
    languageCode: languageCode,
    frames: frames,
    limits: limits,
  );

  Storyboard _edit(int index, StoryboardFrame Function(StoryboardFrame) f) {
    if (index < 0 || index >= frames.length) {
      throw const StoryboardEditException('bounds');
    }
    return _next([...frames]..[index] = f(frames[index]));
  }

  /// Moves frame [from] to [to]. Refused when an outcome would come
  /// before the command it answers.
  Storyboard move(int from, int to) {
    if (from < 0 || from >= frames.length || to < 0 || to >= frames.length) {
      throw const StoryboardEditException('bounds');
    }
    final list = [...frames];
    list.insert(to, list.removeAt(from));
    final position = {for (var i = 0; i < list.length; i++) list[i].stepSeq: i};
    for (var i = 0; i < list.length; i++) {
      final attempt = list[i].attemptSeq;
      if (attempt != null && (position[attempt] ?? -1) > i) {
        throw const StoryboardEditException('order');
      }
    }
    return _next(list);
  }

  Storyboard setOmitted(int index, bool omitted) =>
      _edit(index, (f) => f.copyWith(omitted: omitted));

  /// Clamped to the limits.
  Storyboard setDuration(int index, int ms) => _edit(
    index,
    (f) => f.copyWith(
      durationMs: ms.clamp(limits.minDurationMs, limits.maxDurationMs),
    ),
  );

  /// Withdraws the frame's approval.
  Storyboard setCaption(int index, String caption) {
    final trimmed = caption.trim();
    if (trimmed.isEmpty || trimmed.length > limits.maxCaptionLength) {
      throw const StoryboardEditException('bounds');
    }
    return _edit(index, (f) => f.copyWith(caption: trimmed));
  }

  /// Adds an opaque redaction; withdraws the frame's approval.
  Storyboard addRedaction(int index, NormalizedRect rect) {
    if (!rect.isValid) throw const StoryboardEditException('bounds');
    return _edit(index, (f) {
      if (f.redactions.length >= limits.maxRedactions) {
        throw const StoryboardEditException('bounds');
      }
      return f.copyWith(redactions: [...f.redactions, rect]);
    });
  }

  /// Approves (or withdraws) the frame's illustration.
  Storyboard setApproved(int index, bool approved) => _edit(index, (f) {
    if (approved && f.source != IllustrationSource.recreatedScene) {
      throw const StoryboardEditException('noIllustration');
    }
    return f.copyWith(approved: approved);
  });
}
