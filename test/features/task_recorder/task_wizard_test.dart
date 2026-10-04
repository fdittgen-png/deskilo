// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The task wizard: guides, recordings and tools in one screen. A recording
// becomes a guide in one tap (from the recordings list, or through "Add a
// guide"); the guides are kept on the device, can be started, edited and
// deleted (after a confirmation), and the recordings list never shows one.
import 'package:deskilo/features/task_recorder/data/guide_store.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/presentation/screens/task_wizard_screen.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

Future<({ProviderContainer container, GuideStore guides, String recordingId})>
_pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fixture = await recordFixture(BookingJourney.planConfirmed);
  final recordings = RecorderStore(
    backend: fixture.backend,
    namespace: canaryNamespace,
  );
  final guides = GuideStore(
    backend: MemoryRecorderLogBackend(),
    accountNamespace: canaryNamespace,
  );
  final container = ProviderContainer(
    overrides: [
      recorderStoreProvider.overrideWithValue(recordings),
      guideStoreProvider.overrideWithValue(guides),
      recorderScopeProvider.overrideWithValue(canaryScope),
      taskRecorderAvailableProvider.overrideWithValue(true),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TaskWizardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    guides: guides,
    recordingId: '0123456789abcdef0123456789abcdef',
  );
}

void main() {
  testWidgets('one screen: guides, recordings and tools', (tester) async {
    final h = await _pump(tester);
    expect(find.text('Task wizard'), findsOneWidget);
    expect(_key('task-wizard-add-guide'), findsOneWidget);
    expect(_key('task-wizard-no-guides'), findsOneWidget);
    expect(_key('task-wizard-start-builtin-bookAPlace'), findsOneWidget);
    expect(_key('task-wizard-record'), findsOneWidget);
    expect(_key('task-wizard-recording-${h.recordingId}'), findsOneWidget);
    expect(_key('task-wizard-open-file'), findsOneWidget);
  });

  testWidgets('a recording becomes a guide in one tap, kept on the device', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(_key('task-wizard-make-guide-${h.recordingId}'));
    await tester.pumpAndSettle();
    expect(_key('task-wizard-guide-added'), findsOneWidget);
    final kept = await h.guides.list();
    expect(kept, hasLength(1));
    expect(kept.single.guide.title, 'Book a desk');
    expect(_key('task-wizard-no-guides'), findsNothing);
    expect(
      find.byKey(ValueKey('task-wizard-guide-${kept.single.id}')),
      findsOneWidget,
    );
    // A guide is not a recording: the recordings list is unchanged.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'task-wizard-recording-',
            ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Add a guide offers a recording, and picking one adds it', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(_key('task-wizard-add-guide'));
    await tester.pumpAndSettle();
    expect(_key('task-wizard-add-from-recording'), findsOneWidget);
    expect(_key('task-wizard-add-from-file'), findsOneWidget);
    await tester.tap(_key('task-wizard-add-from-recording'));
    await tester.pumpAndSettle();
    await tester.tap(_key('task-wizard-pick-${h.recordingId}'));
    await tester.pumpAndSettle();
    expect(await h.guides.list(), hasLength(1));
  });

  testWidgets('a guide is deleted only after a confirmation', (tester) async {
    final h = await _pump(tester);
    await tester.tap(_key('task-wizard-make-guide-${h.recordingId}'));
    await tester.pumpAndSettle();
    final id = (await h.guides.list()).single.id;
    await tester.tap(_key('task-wizard-menu-$id'));
    await tester.pumpAndSettle();
    await tester.tap(_key('task-wizard-delete-$id'));
    await tester.pumpAndSettle();
    expect(await h.guides.list(), hasLength(1), reason: 'not yet');
    await tester.tap(_key('task-wizard-delete-confirm'));
    await tester.pumpAndSettle();
    expect(await h.guides.list(), isEmpty);
    expect(_key('task-wizard-no-guides'), findsOneWidget);
  });
}
