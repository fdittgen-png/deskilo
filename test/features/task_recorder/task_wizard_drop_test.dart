// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3818 — a task file dropped on the task wizard goes where the menu's "add
// from file" sends a picked one: a guide file opens as a draft; a file of
// another kind is refused in words and opens nothing.
import 'dart:convert';

import 'package:deskilo/core/files/file_drop_backend.dart';
import 'package:deskilo/features/task_recorder/data/guide_store.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/guide/builtin_guides.dart';
import 'package:deskilo/features/task_recorder/guide/guide_codec.dart';
import 'package:deskilo/features/task_recorder/presentation/screens/guide_draft_screen.dart';
import 'package:deskilo/features/task_recorder/presentation/screens/task_wizard_screen.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_drop.dart';
import '../../helpers/memory_recorder_log_backend.dart';
import 'fixtures/recording_fixtures.dart';

void main() {
  late FakeFileDrop drop;

  setUp(() => drop = FakeFileDrop());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = await recordFixture(BookingJourney.planConfirmed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...drop.overrides(),
          recorderStoreProvider.overrideWithValue(
            RecorderStore(backend: fixture.backend, namespace: canaryNamespace),
          ),
          guideStoreProvider.overrideWithValue(
            GuideStore(
              backend: MemoryRecorderLogBackend(),
              accountNamespace: canaryNamespace,
            ),
          ),
          recorderScopeProvider.overrideWithValue(canaryScope),
          taskRecorderAvailableProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TaskWizardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a dropped guide file opens as a draft', (tester) async {
    await pump(tester);
    final text = encodeGuideText(
      builtinGuide(
        lookupAppLocalizations(const Locale('en')),
        BuiltinGuide.bookAPlace,
      ),
    );
    drop.drop(
      DroppedItems([FakeDroppedFile('guide.json', bytes: utf8.encode(text))]),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GuideDraftScreen), findsOneWidget);
  });

  testWidgets('a file of another kind is refused and opens nothing', (
    tester,
  ) async {
    await pump(tester);
    drop.drop(DroppedItems([FakeDroppedFile('holiday.png')]));
    await tester.pumpAndSettle();
    expect(find.textContaining('takes .json, .zip'), findsOneWidget);
    expect(find.byType(GuideDraftScreen), findsNothing);
  });

  testWidgets('a file that is no task file is refused in the picker\'s words', (
    tester,
  ) async {
    await pump(tester);
    drop.drop(
      DroppedItems([FakeDroppedFile('notes.json', bytes: utf8.encode('{}'))]),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GuideDraftScreen), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
