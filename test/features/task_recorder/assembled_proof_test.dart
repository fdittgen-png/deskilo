// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1886 — the assembled proof, end to end on one host, through the real
// producers and an independent reader at each step:
//   1. a genuine booking recorded by the real controller into the real
//      store, with a cancelled review and a refused attempt before the
//      confirmed one, private canaries thrown at the capture boundary;
//   2. saved as a task package;
//   3. opened in a clean workbench import (no account, no workspace),
//      a private copy edited (the cancelled review left out);
//   4. a Word document made by the REGISTERED generator and read back as
//      a plain ZIP + XML (not through the writer that made it);
//   5. a guide compiled from the copy, saved, re-read by the guide codec
//      and followed on real outcome events to completion;
//   6. one mutation (a step's action, a package byte) refused by the real
//      parser, not a test double.
// Canaries are checked in every artefact. The caption track comes from
// the registered generator and is read back as plain WebVTT; the MP4 runs
// only where the platform encoder answers its probe and is reported NOT
// RUN otherwise: this proof never fakes an encoder (the device run is
// integration_test/task_video_encoder_test.dart).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/features/task_recorder/application/workbench_import.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/recording_edit.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/export/output_registry.dart';
import 'package:deskilo/features/task_recorder/guide/guide_codec.dart';
import 'package:deskilo/features/task_recorder/guide/guide_compiler.dart';
import 'package:deskilo/features/task_recorder/guide/guide_runner.dart';
import 'package:deskilo/features/task_recorder/package/task_output.dart';
import 'package:deskilo/features/task_recorder/package/task_package.dart';
import 'package:deskilo/features/task_recorder/presentation/recorder_labels.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'fixtures/recording_fixtures.dart';

void _clean(String where, String text) {
  for (final c in [...privateCanaries, ...canaryFragments]) {
    expect(text.contains(c), isFalse, reason: '$where carries "$c"');
  }
}

void main() {
  testWidgets('record → package → clean import → Word + guide', (tester) async {
    // 1. A genuine recording, into the real store.
    final backend = MemoryRecorderLogBackend();
    final store = RecorderStore(backend: backend, namespace: canaryNamespace);
    final clock = StepClock();
    final c = fixtureController(store, clock);
    await c.start(scope: canaryScope, title: 'Book a desk');
    void step(String a, [Map<String, Object?> legit = const {}]) {
      clock.tick();
      c.record(a, payload: canaryPayload(legit));
    }

    step(RecorderActions.openReserve);
    step(RecorderActions.selectResource, {'view_mode': 'plan'});
    step(RecorderActions.cancelReview);
    step(RecorderActions.selectResource, {'view_mode': 'list'});
    clock.tick();
    final first = c.attempt(
      RecorderActions.confirmBooking,
      payload: canaryPayload({'for_whom': 'self'}),
    );
    c.outcome(
      first,
      RecorderOutcomes.bookingRefused,
      payload: canaryPayload({'refusal': 'conflict'}),
    );
    clock.tick();
    final second = c.attempt(
      RecorderActions.confirmBooking,
      payload: canaryPayload({'for_whom': 'self'}),
    );
    c.outcome(
      second,
      RecorderOutcomes.bookingConfirmed,
      payload: canaryPayload({'check_in': 'no'}),
    );
    final recording = (await c.stop())!;
    await c.dispose();
    expect(recording.completeness, Completeness.complete);
    _clean('the store', backend.logs.values.join());

    // 2. A task package.
    final en = lookupAppLocalizations(const Locale('en'));
    final package = writeTaskPackage(
      recording,
      transcript: recordingTranscript(en, recording),
    );
    for (final f in ZipDecoder().decodeBytes(package).files) {
      _clean('package ${f.name}', utf8.decode(f.content));
    }

    // 3. Another device: a clean import, a private copy.
    final opened = openTaskFile(package) as WorkbenchOpened;
    expect(opened.runnable, isTrue);
    final cancelSeq = opened.recording.steps
        .firstWhere((s) => s.action == RecorderActions.cancelReview)
        .seq;
    final copy = editedCopy(opened.recording, {cancelSeq});
    expect(copy.kind, RecordingKind.edited);
    expect(copy.sourceDigest, recordingDigest(recording));

    // 4. Word, from the registered generator, read back independently.
    final word = taskOutputGeneratorList().firstWhere(
      (g) => g.kind == TaskOutputKind.document,
    );
    final made = await tester.runAsync(
      () =>
          word.generate(TaskOutputRequest(recording: copy, languageCode: 'fr')),
    );
    final docx = (made! as TaskOutputProduced).bytes;
    final parts = {
      for (final f in ZipDecoder().decodeBytes(docx).files)
        if (f.isFile) f.name: f.content,
    };
    expect(
      parts.keys,
      containsAll(['[Content_Types].xml', 'word/document.xml']),
    );
    final body = XmlDocument.parse(utf8.decode(parts['word/document.xml']!));
    final text = body.findAllElements('w:t').map((e) => e.innerText).join(' ');
    expect(text, contains('Book a desk'));
    for (final p in parts.entries) {
      if (p.key.endsWith('.xml')) _clean('docx ${p.key}', utf8.decode(p.value));
    }

    // 5. A guide from the copy, saved, re-read, followed.
    final guideText = encodeGuideText(compileGuide(copy));
    _clean('the guide', guideText);
    final guide = decodeGuideText(guideText);
    expect(guide.runnable, isTrue);
    final run = GuideRun(guide.guide!);
    for (final s in guide.guide!.steps) {
      if (s.action == null) {
        run.acknowledge();
        continue;
      }
      var token = run.onAction(s.action!);
      if (s.isCommand) {
        run.onOutcome(RecorderOutcomes.bookingRefused, token: token);
        run.acknowledge(); // the recovery instruction
        token = run.onAction(s.action!);
        run.onOutcome(RecorderOutcomes.bookingConfirmed, token: token);
      }
    }
    expect(run.state, GuideRunState.completed);

    // 6. Mutations meet the real parsers.
    final tampered =
        jsonDecode(encodeRecordingText(copy)) as Map<String, Object?>;
    ((tampered['steps']! as List).first as Map)['action'] = 'payments.pay_all';
    expect(decodeRecording(tampered).runnable, isFalse);
    final flipped = Uint8List.fromList(package)..[package.length ~/ 2] ^= 0xff;
    expect(openTaskFile(flipped), isA<WorkbenchRefused>());

    // Captions, from the registered generator, read back as WebVTT.
    final captions = taskOutputGeneratorList().firstWhere(
      (g) => g.kind == TaskOutputKind.captions,
    );
    final vttMade = await tester.runAsync(
      () => captions.generate(
        TaskOutputRequest(recording: copy, languageCode: 'fr'),
      ),
    );
    final vtt = utf8.decode((vttMade! as TaskOutputProduced).bytes);
    expect(vtt.startsWith('WEBVTT'), isTrue);
    expect('-->'.allMatches(vtt).length, greaterThan(1));
    _clean('the caption track', vtt);

    // Video: the registered generator, only where its encoder answers.
    final video = taskOutputGeneratorList().firstWhere(
      (g) => g.kind == TaskOutputKind.video,
    );
    final availability = await tester.runAsync(video.availability);
    if (availability is TaskOutputAvailable) {
      final mp4Made = await tester.runAsync(
        () => video.generate(
          TaskOutputRequest(recording: copy, languageCode: 'fr'),
        ),
      );
      final mp4 = (mp4Made! as TaskOutputProduced).bytes;
      expect(ascii.decode(mp4.sublist(4, 8)), 'ftyp');
    } else {
      debugPrint(
        'assembled proof: MP4 NOT RUN (no platform encoder on this host)',
      );
    }
  });
}
