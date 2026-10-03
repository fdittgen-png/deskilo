// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — the shared storyboard and its safe scene model.
//
// Invariant: a recording's storyboard has exactly one frame per step in
// order, outcomes linked to (and kept after) their commands, scenes only
// for known surfaces and never beyond the illustration bound, nothing
// approved by default; every word a scene can draw belongs to the closed
// SceneLabels set in all five languages, and a recording made with
// canaries at every capture boundary yields scenes EQUAL to the committed
// fixture's; every edit is a new revision that leaves the old one intact,
// and an edit to a frame's picture withdraws its approval and changes its
// render key. PNG safety refuses malformed, tampered or oversized files
// before decoding and strips every non-picture chunk.
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/storyboard/png_safety.dart';
import 'package:deskilo/features/task_recorder/storyboard/safe_scene.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_builder.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/recording_fixtures.dart';

AppLocalizations _l(String code) => lookupAppLocalizations(Locale(code));

TaskRecording _fixture(BookingJourney j) =>
    decodeRecordingText(fixtureText(j.file)).recording!;

Uint8List _chunk(String type, List<int> data) {
  final body = [...type.codeUnits, ...data];
  final crc = getCrc32(body);
  final len = data.length;
  return Uint8List.fromList([
    len >> 24 & 255,
    len >> 16 & 255,
    len >> 8 & 255,
    len & 255,
    ...body,
    crc >> 24 & 255,
    crc >> 16 & 255,
    crc >> 8 & 255,
    crc & 255,
  ]);
}

/// A structurally valid 2x1 PNG carrying a tEXt chunk with a canary.
Uint8List _pngWithText({int width = 2, int height = 1}) {
  final ihdr = [
    width >> 24 & 255,
    width >> 16 & 255,
    width >> 8 & 255,
    width & 255,
    height >> 24 & 255,
    height >> 16 & 255,
    height >> 8 & 255,
    height & 255,
    8,
    2,
    0,
    0,
    0,
  ];
  final raw = <int>[
    for (var y = 0; y < height; y++) ...[
      0,
      for (var x = 0; x < width; x++) ...[1, 2, 3],
    ],
  ];
  return Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ..._chunk('IHDR', ihdr),
    ..._chunk('tEXt', 'Author\u0000$kCanaryMemberName'.codeUnits),
    ..._chunk('IDAT', const ZLibEncoder().encode(raw)),
    ..._chunk('tIME', [7, 234, 10, 2, 12, 0, 0]),
    ..._chunk('IEND', const []),
  ]);
}

void main() {
  group('derivation', () {
    for (final journey in BookingJourney.values) {
      test('${journey.file}: one frame per step, nothing approved', () {
        final r = _fixture(journey);
        final sb = buildStoryboard(r, _l('en'));
        expect(sb.revision, 1);
        expect(sb.sourceRevision, recordingDigest(r).substring(0, 12));
        expect(sb.frames.map((f) => f.stepSeq), [
          for (final s in r.steps) s.seq,
        ]);
        expect(sb.frames.every((f) => !f.approved && !f.omitted), isTrue);
        for (final (i, f) in sb.frames.indexed) {
          final step = r.steps[i];
          if (f.attemptSeq != null) {
            expect(
              sb.frames.indexWhere((x) => x.stepSeq == f.attemptSeq),
              lessThan(i),
            );
          }
          expect(
            f.source == IllustrationSource.recreatedScene,
            f.scene != null,
          );
          if (f.scene != null) {
            expect(f.highlight, isNotNull, reason: 'step ${step.seq}');
            expect(f.highlight!.isValid, isTrue);
            for (final e in f.scene!.elements) {
              expect(e.rect.isValid, isTrue);
            }
          }
          expect(
            f.durationMs,
            inInclusiveRange(sb.limits.minDurationMs, sb.limits.maxDurationMs),
          );
        }
      });
    }

    test('the plan path and the list path draw different bodies', () {
      final plan = buildStoryboard(
        _fixture(BookingJourney.planConfirmed),
        _l('en'),
      );
      final list = buildStoryboard(
        _fixture(BookingJourney.listRefused),
        _l('en'),
      );
      Set<SceneElementKind> kinds(Storyboard sb) => {
        for (final f in sb.frames)
          for (final e in f.scene?.elements ?? const <SceneElement>[]) e.kind,
      };
      expect(kinds(plan), contains(SceneElementKind.desk));
      expect(kinds(plan), isNot(contains(SceneElementKind.listRow)));
      expect(kinds(list), contains(SceneElementKind.listRow));
    });

    test('a refused and an unknown outcome stay what they are', () {
      final refused = buildStoryboard(
        _fixture(BookingJourney.listRefused),
        _l('en'),
      );
      final l = _l('en');
      expect(
        refused.frames.map((f) => f.title),
        contains(l.taskExportResult(l.taskExportOutcomeRefused)),
      );
      final unknown = buildStoryboard(
        _fixture(BookingJourney.unknownOutcome),
        _l('en'),
      );
      expect(
        unknown.frames.map((f) => f.title),
        contains(l.taskExportResult(l.taskExportOutcomeUnknown)),
      );
      expect(
        unknown.frames.map((f) => f.title),
        isNot(contains(l.taskExportResult(l.taskExportOutcomeConfirmed))),
      );
    });

    test('illustrations are bounded; the rest become text slides', () {
      final sb = buildStoryboard(
        _fixture(BookingJourney.planConfirmed),
        _l('en'),
        limits: const StoryboardLimits(maxIllustrated: 2),
      );
      expect(sb.frames.where((f) => f.scene != null), hasLength(2));
      expect(
        sb.frames,
        hasLength(_fixture(BookingJourney.planConfirmed).steps.length),
      );
    });

    test('an unknown action gets a gap text slide, not a scene', () {
      final r = decodeRecordingText(fixtureText('degrade_unknown_action'))
          .recording!;
      final sb = buildStoryboard(r, _l('en'));
      final gap = sb.frames.where((f) => f.status == FrameStatus.gap).toList();
      expect(gap, isNotEmpty);
      expect(gap.every((f) => f.scene == null), isTrue);
    });
  });

  group('privacy of the scene model', () {
    for (final code in ['en', 'fr', 'de', 'es', 'it']) {
      test('$code: every drawable word is in the closed label set', () {
        final words = SceneLabels(_l(code)).all;
        for (final j in BookingJourney.values) {
          for (final f in buildStoryboard(_fixture(j), _l(code)).frames) {
            for (final text in f.scene?.texts ?? const <String>[]) {
              expect(
                text.split(' · '),
                everyElement(isIn(words)),
                reason: '${j.file} step ${f.stepSeq}: $text',
              );
            }
          }
        }
      });
    }

    for (final j in BookingJourney.values) {
      test('${j.file}: canaries at capture change no scene', () async {
        final recorded = await recordFixture(j);
        final live = buildStoryboard(recorded.recording, _l('en'));
        final committed = buildStoryboard(_fixture(j), _l('en'));
        expect(
          live.frames.map((f) => f.scene),
          committed.frames.map((f) => f.scene),
        );
        for (final f in live.frames) {
          final all = [
            f.title,
            ...f.details,
            f.caption,
            f.altText,
            ...?f.scene?.texts,
          ];
          for (final c in [...privateCanaries, ...canaryFragments]) {
            expect(
              all.any((t) => t.toLowerCase().contains(c.toLowerCase())),
              isFalse,
              reason: c,
            );
          }
        }
      });
    }
  });

  group('revisions', () {
    Storyboard sb() =>
        buildStoryboard(_fixture(BookingJourney.planConfirmed), _l('en'));
    int sceneIndex(Storyboard s) => s.frames.indexWhere(
      (f) => f.source == IllustrationSource.recreatedScene,
    );

    test('an outcome cannot move before its command', () {
      final s = sb();
      final outcome = s.frames.indexWhere((f) => f.attemptSeq != null);
      expect(
        () => s.move(outcome, outcome - 1),
        throwsA(isA<StoryboardEditException>()),
      );
      final moved = s.move(0, 1);
      expect(moved.revision, 2);
      expect(moved.frames[1].stepSeq, s.frames[0].stepSeq);
      expect(s.frames[0].stepSeq, 1, reason: 'the old revision is untouched');
    });

    test('a redaction withdraws approval and changes the render key', () {
      final s = sb();
      final i = sceneIndex(s);
      final approved = s.setApproved(i, true);
      expect(approved.frames[i].approved, isTrue);
      final redacted = approved.addRedaction(
        i,
        const NormalizedRect(0, 0, 0.5, 0.5),
      );
      expect(redacted.frames[i].approved, isFalse);
      expect(redacted.frames[i].renderKey, isNot(approved.frames[i].renderKey));
      expect(redacted.revision, approved.revision + 1);
      expect(
        () => s.addRedaction(i, const NormalizedRect(0.8, 0, 0.5, 0.5)),
        throwsA(isA<StoryboardEditException>()),
      );
    });

    test('caption edits withdraw approval; omission and duration keep it', () {
      final s = sb();
      final i = sceneIndex(s);
      final approved = s.setApproved(i, true);
      expect(
        approved.setCaption(i, 'Pick tomorrow').frames[i].approved,
        isFalse,
      );
      expect(approved.setOmitted(i, true).frames[i].approved, isTrue);
      expect(
        approved.setDuration(i, 999999).frames[i].durationMs,
        s.limits.maxDurationMs,
      );
      expect(
        approved.setDuration(i, 1).frames[i].durationMs,
        s.limits.minDurationMs,
      );
      expect(
        () => s.setCaption(i, '  '),
        throwsA(isA<StoryboardEditException>()),
      );
    });

    test('only a recreated scene can be approved', () {
      final s = sb();
      final text = s.frames.indexWhere(
        (f) => f.source != IllustrationSource.recreatedScene,
      );
      expect(
        () => s.setApproved(text, true),
        throwsA(isA<StoryboardEditException>()),
      );
    });
  });

  group('PNG safety', () {
    test('metadata chunks are stripped; the picture chunks stay', () {
      final png = _pngWithText();
      expect(pngChunkTypes(png), ['IHDR', 'tEXt', 'IDAT', 'tIME', 'IEND']);
      final clean = stripPngMetadata(png);
      expect(pngChunkTypes(clean), ['IHDR', 'IDAT', 'IEND']);
      expect(String.fromCharCodes(clean).contains('CANARY'), isFalse);
      expect(readPngHeader(clean), (width: 2, height: 1));
    });

    test(
      'malformed, tampered and oversized files are refused before decode',
      () {
        final png = _pngWithText();
        Matcher refused(String reason) => throwsA(
          isA<PngRejected>().having((e) => e.reason, 'reason', reason),
        );
        expect(
          () => stripPngMetadata(Uint8List.fromList([...png]..[0] = 0)),
          refused('signature'),
        );
        expect(
          () => stripPngMetadata(Uint8List.sublistView(png, 0, png.length - 5)),
          refused('truncated'),
        );
        final tampered = Uint8List.fromList(png);
        tampered[40] ^= 0xff;
        expect(() => stripPngMetadata(tampered), refused('crc'));
        expect(
          () => stripPngMetadata(_pngWithText(width: 5000)),
          refused('dimensions'),
        );
        expect(
          () => stripPngMetadata(
            _pngWithText(width: 2000, height: 2000),
            limits: const PngLimits(maxPixels: 1000000),
          ),
          refused('dimensions'),
        );
      },
    );
  });
}
