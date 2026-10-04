// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — the guide draft editor in the workbench: a recording opened
// from a file becomes a draft whose command step waits for the real
// answer and names its recovery; the author writes an instruction's
// words and marks a step optional; the saved file is a guide the codec
// accepts, with those words and nothing private.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/guide/guide_codec.dart';
import 'package:deskilo/features/task_recorder/presentation/screens/task_workbench_screen.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

void main() {
  testWidgets('open, create a guide draft, write the words, save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = (await recordFixture(BookingJourney.listRefused)).recording;
    final saved = <String, Uint8List>{};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guideStoreProvider.overrideWithValue(null),
          filePickerProvider.overrideWithValue(
            (_) async => XFile.fromData(
              Uint8List.fromList(utf8.encode(encodeRecordingText(r))),
              name: 'task.json',
            ),
          ),
          typedFileSaverProvider.overrideWithValue(({
            required Uint8List bytes,
            required String fileName,
          }) async {
            saved[fileName] = bytes;
            return SavedFile('/Downloads/$fileName');
          }),
          taskOutputGeneratorsProvider.overrideWithValue(const []),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TaskWorkbenchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workbench-choose')));
    await tester.pumpAndSettle();
    final create = find.byKey(const ValueKey('workbench-create-guide'));
    await tester.scrollUntilVisible(
      create,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('Guide draft'), findsOneWidget);
    final confirm = find.byKey(const ValueKey('guide-step-g7'));
    await tester.scrollUntilVisible(
      confirm,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: confirm,
        matching: find.textContaining('Waits for: Booked'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: confirm,
        matching: find.textContaining('If it is refused'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('guide-optional-g1')));
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey('guide-save'));
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final text = utf8.decode(saved['deskilo-guide.json']!);
    final guide = decodeGuideText(text);
    expect(guide.runnable, isTrue);
    expect(guide.guide!.steps.first.optional, isTrue);
    expect(text, isNot(contains('booking.refused')));
    for (final c in [...privateCanaries, ...canaryFragments]) {
      expect(text.contains(c), isFalse, reason: c);
    }
  });

  testWidgets('an instruction gets the author\'s words', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = (await recordFixture(BookingJourney.cancelledReview)).recording;
    final saved = <String, Uint8List>{};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guideStoreProvider.overrideWithValue(null),
          filePickerProvider.overrideWithValue(
            (_) async => XFile.fromData(
              Uint8List.fromList(utf8.encode(encodeRecordingText(r))),
              name: 'task.json',
            ),
          ),
          typedFileSaverProvider.overrideWithValue(({
            required Uint8List bytes,
            required String fileName,
          }) async {
            saved[fileName] = bytes;
            return SavedFile('/Downloads/$fileName');
          }),
          taskOutputGeneratorsProvider.overrideWithValue(const []),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TaskWorkbenchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workbench-choose')));
    await tester.pumpAndSettle();
    final create = find.byKey(const ValueKey('workbench-create-guide'));
    await tester.scrollUntilVisible(
      create,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    final last = find.byKey(const ValueKey('guide-edit-g7'));
    await tester.scrollUntilVisible(
      last,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('guide-text-field')),
      'Close the sheet.',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('guide-save'));
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    final guide = decodeGuideText(utf8.decode(saved['deskilo-guide.json']!))
        .guide!;
    expect(guide.steps.last.text, 'Close the sheet.');
  });
}
