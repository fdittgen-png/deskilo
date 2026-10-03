// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866 — the Word document as a registered workbench output (#1872).
//
// Invariant: the registry offers exactly one document generator, `docx`,
// whose extension maps to the WordprocessingML MIME type; it is always
// available, produces the same package the review screen saves (in the
// request's language, falling back to English), embeds the reviewed
// storyboard's approved pictures, refuses a storyboard reviewed for
// another revision as stale, and stops when cancelled — never producing
// a partial document.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/export/docx_output_generator.dart';
import 'package:deskilo/features/task_recorder/export/output_registry.dart';
import 'package:deskilo/features/task_recorder/export/task_document.dart';
import 'package:deskilo/features/task_recorder/package/task_output.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_builder.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/recording_fixtures.dart';

TaskRecording _fixture(BookingJourney j) =>
    decodeRecordingText(fixtureText(j.file)).recording!;

Map<String, Uint8List> _unzip(Uint8List bytes) => {
  for (final f in ZipDecoder().decodeBytes(bytes).files)
    if (f.isFile) f.name: Uint8List.fromList(f.content),
};

void main() {
  test('the registry offers one docx document generator', () async {
    final docx = taskOutputGeneratorList()
        .where((g) => g.kind == TaskOutputKind.document)
        .single;
    expect(docx.id, 'docx');
    expect(
      mimeTypeFor('x.${docx.fileExtension}'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(await docx.availability(), isA<TaskOutputAvailable>());
  });

  test(
    'produces the document in the request language, English otherwise',
    () async {
      final r = _fixture(BookingJourney.listRefused);
      for (final (code, tag) in [('fr', 'fr-FR'), ('xx', 'en-US')]) {
        final result = await const DocxOutputGenerator().generate(
          TaskOutputRequest(recording: r, languageCode: code),
        );
        final produced = result as TaskOutputProduced;
        expect(produced.suggestedName, docxFileNameFor(r));
        expect(
          utf8.decode(_unzip(produced.bytes)['docProps/core.xml']!),
          contains('<dc:language>$tag</dc:language>'),
        );
      }
    },
  );

  test('a stale storyboard is refused; a cancel produces nothing', () async {
    final l = lookupAppLocalizations(const Locale('en'));
    final other = buildStoryboard(_fixture(BookingJourney.planConfirmed), l);
    final r = _fixture(BookingJourney.listRefused);
    final stale = await const DocxOutputGenerator().generate(
      TaskOutputRequest(recording: r, languageCode: 'en', storyboard: other),
    );
    expect(
      stale,
      isA<TaskOutputNotProduced>().having(
        (n) => n.reason,
        'reason',
        TaskOutputReason.stale,
      ),
    );
    final cancel = TaskOutputCancel()..cancel();
    expect(
      await const DocxOutputGenerator().generate(
        TaskOutputRequest(recording: r, languageCode: 'en'),
        cancel: cancel,
      ),
      isA<TaskOutputCancelled>(),
    );
  });

  testWidgets('approved pictures of the reviewed storyboard are embedded', (
    tester,
  ) async {
    final r = _fixture(BookingJourney.planConfirmed);
    final l = lookupAppLocalizations(const Locale('en'));
    var sb = buildStoryboard(r, l);
    final i = sb.frames.indexWhere(
      (f) => f.source == IllustrationSource.recreatedScene,
    );
    sb = sb.setApproved(i, true);
    final result = await tester.runAsync(
      () => const DocxOutputGenerator().generate(
        TaskOutputRequest(
          recording: r,
          languageCode: 'en',
          storyboard: sb,
          brightness: Brightness.dark,
        ),
      ),
    );
    final parts = _unzip((result! as TaskOutputProduced).bytes);
    expect(parts.keys.where((k) => k.startsWith('word/media/')), hasLength(1));
  });
}

/// The name the review screen's export uses for the same recording.
String docxFileNameFor(TaskRecording r) =>
    'procedure-book-a-desk-${recordingRevision(r)}.docx';
