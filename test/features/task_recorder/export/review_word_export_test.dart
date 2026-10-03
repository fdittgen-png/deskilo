// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866 — the Word export through the real review screen.
//
// Invariant: on RecordingReviewScreen, "Export as Word document" saves
// exactly one `.docx` of the edited copy the screen shows through the
// app's FileSaver, and says where it went; a saver that saves nothing is
// reported as a failure, and a browser download as handed over, never as
// a saved document.
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/task_recorder/domain/stored_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/presentation/screens/recording_review_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/recording_fixtures.dart';

Future<void> _pump(WidgetTester tester, TypedFileSaver saver) async {
  final recording = decodeRecordingText(
    fixtureText(BookingJourney.listRefused.file),
  ).recording!;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [typedFileSaverProvider.overrideWithValue(saver)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RecordingReviewScreen(
          stored: StoredRecording(
            id: '0123456789abcdef',
            status: StoredStatus.ended,
            recording: recording,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  final button = find.byKey(const ValueKey('task-recording-export-word'));

  testWidgets('the review screen saves the edited copy as a .docx', (
    tester,
  ) async {
    final saved = <String, Uint8List>{};
    await _pump(tester, ({required bytes, required fileName}) async {
      saved[fileName] = bytes;
      return SavedFile('/downloads/$fileName');
    });
    await tester.scrollUntilVisible(button, 300);
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(saved.keys.single, endsWith('.docx'));
    final document = String.fromCharCodes(
      ZipDecoder()
          .decodeBytes(saved.values.single)
          .files
          .firstWhere((f) => f.name == 'word/document.xml')
          .content,
    );
    expect(document, contains(l.taskExportActionConfirmBooking));
    expect(
      find.text(l.taskExportSaved('/downloads/${saved.keys.single}')),
      findsOneWidget,
    );
  });

  testWidgets('a saver that saves nothing is reported as a failure', (
    tester,
  ) async {
    await _pump(
      tester,
      ({required bytes, required fileName}) async => const SaveFailed(),
    );
    await tester.scrollUntilVisible(button, 300);
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(l.taskExportSaveFailed), findsOneWidget);
  });

  testWidgets('a browser download is reported as handed over', (tester) async {
    await _pump(
      tester,
      ({required bytes, required fileName}) async =>
          DownloadRequested(fileName),
    );
    await tester.scrollUntilVisible(button, 300);
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(l.taskRecorderSaveNoPath), findsOneWidget);
  });
}
