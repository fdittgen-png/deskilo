// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the recorder through its real screens: Start only below the
// disclosure and only where the workspace allows it; live controls; a
// labelled note; the private list; a review that leaves steps out as an
// edited copy and previews exactly the file it saves; a saver that gives
// no path, or fails, is said so truthfully; delete removes only the
// private recording. The indicator stays out of the way until the
// recorder was opened, then marks protected and unknown screens.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/task_recorder/application/recorder_controller.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/package/task_package.dart';
import 'package:deskilo/features/task_recorder/presentation/screens/task_recorder_screen.dart';
import 'package:deskilo/features/task_recorder/presentation/widgets/recording_indicator.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/recording_fixtures.dart';

class _Saver {
  Uint8List? bytes;
  String? name;
  SaveOutcome answer = const SavedFile('/Downloads/deskilo-task.json');
  bool fail = false;

  Future<SaveOutcome> call(
      {required Uint8List bytes, required String fileName}) async {
    if (fail) throw StateError('disk full');
    this.bytes = bytes;
    name = fileName;
    return answer;
  }
}

class _Harness {
  _Harness({bool available = true}) {
    container = ProviderContainer(overrides: [
      recorderStoreProvider.overrideWithValue(store),
      recorderScopeProvider.overrideWithValue(canaryScope),
      taskRecorderAvailableProvider.overrideWithValue(available),
      typedFileSaverProvider.overrideWithValue(saver.call),
    ]);
  }

  final store =
      RecorderStore(backend: MemoryRecorderLogBackend(), namespace: canaryNamespace);
  final saver = _Saver();
  late final ProviderContainer container;

  RecorderController get controller => container.read(recorderControllerProvider);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TaskRecorderScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }
}

void main() {
  testWidgets('Start waits for the workspace; the disclosure is always there',
      (tester) async {
    final h = _Harness(available: false);
    await h.pump(tester);
    expect(find.text('Before you record'), findsOneWidget);
    expect(find.textContaining('Nothing is uploaded'), findsOneWidget);
    expect(find.text('Recording is not switched on in this workspace.'),
        findsOneWidget);
    final start = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('task-recorder-start')));
    expect(start.onPressed, isNull);
    expect(h.container.read(recorderControllerProvider).state,
        RecorderState.idle);
    await h.done(tester);
  });

  testWidgets('start, a labelled note, stop: the recording is listed',
      (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.tap(find.byKey(const ValueKey('task-recorder-start')));
    await tester.pumpAndSettle();
    expect(h.controller.state, RecorderState.recording);
    expect(find.byKey(const ValueKey('task-recorder-stop')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('task-recorder-note')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('task-recorder-note-field')), 'Ask first');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(h.controller.snapshot!.steps.single.kind, StepKind.annotation);

    await tester.tap(find.byKey(const ValueKey('task-recorder-stop')));
    await tester.pumpAndSettle();
    expect(h.controller.state, RecorderState.ended);
    expect(find.textContaining('1 steps'), findsOneWidget);
    expect(find.textContaining('Complete'), findsOneWidget);
    await h.done(tester);
  });

  testWidgets('review: leave out, preview, export the edited copy',
      (tester) async {
    final h = _Harness();
    await recordJourney(h.controller, StepClock(), BookingJourney.planConfirmed);
    await h.pump(tester);
    await tester.tap(find.text('Book a desk'));
    await tester.pumpAndSettle();

    expect(find.text('Opened Reserve'), findsOneWidget);
    expect(find.text('Booked'), findsOneWidget);
    final attempt = h.controller.snapshot!.steps
        .firstWhere((s) => s.action == RecorderActions.confirmBooking)
        .seq;
    await tester.tap(find.byKey(ValueKey('task-step-toggle-$attempt')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-recording-edited-note')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('task-recording-preview')));
    await tester.pumpAndSettle();
    final preview = tester
        .widget<SelectableText>(
            find.byKey(const ValueKey('task-recording-preview-text')))
        .data!;
    expect(preview, contains('"kind": "edited"'));

    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('task-recording-export')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-recording-export')));
    await tester.pumpAndSettle();
    final saved = utf8.decode(h.saver.bytes!);
    expect(saved, preview, reason: 'the preview IS the file');
    final decoded = decodeRecordingText(saved);
    expect(decoded.accepted, isTrue);
    expect(decoded.recording!.kind, RecordingKind.edited);
    expect(decoded.recording!.steps.where((s) => s.op != null), isEmpty);
    for (final c in [...privateCanaries, ...canaryFragments]) {
      expect(saved.contains(c), isFalse, reason: c);
    }
    expect(find.text('Saved: /Downloads/deskilo-task.json'), findsOneWidget);
    // The private source is untouched.
    final stored = (await h.store.list()).single;
    expect(stored.recording!.kind, RecordingKind.source);
    expect(stored.recording!.steps.length,
        h.controller.snapshot!.steps.length);
    await h.done(tester);
  });

  testWidgets('a saver without a path, or failing, is said truthfully',
      (tester) async {
    final h = _Harness()..saver.answer = const DownloadRequested('x.json');
    await recordJourney(h.controller, StepClock(), BookingJourney.listRefused);
    await h.pump(tester);
    await tester.tap(find.text('Book a desk'));
    await tester.pumpAndSettle();
    final export = find.byKey(const ValueKey('task-recording-export'));
    await tester.scrollUntilVisible(export, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(find.textContaining('did not say where it went'), findsOneWidget);

    h.saver.answer = const SavedPrivately('/data/private/x.json');
    ScaffoldMessenger.of(tester.element(export)).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(find.text('Kept only inside the app: /data/private/x.json'),
        findsOneWidget);

    h.saver.fail = true;
    ScaffoldMessenger.of(tester.element(export)).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(find.text('The file could not be saved.'), findsOneWidget);
    await h.done(tester);
  });

  testWidgets('the task package export is the same recording, readable back',
      (tester) async {
    final h = _Harness();
    await recordJourney(h.controller, StepClock(), BookingJourney.listRefused);
    await h.pump(tester);
    await tester.tap(find.text('Book a desk'));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('task-recording-export-package'));
    await tester.scrollUntilVisible(button, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(h.saver.name, endsWith('.deskilo-task.zip'));
    final read = readTaskPackage(h.saver.bytes!);
    expect(read.accepted, isTrue, reason: '${read.issues}');
    expect(encodeRecordingText(read.package!.recording),
        encodeRecordingText(h.controller.snapshot!));
    expect(read.package!.transcript, contains('Chose a place'));
    for (final c in [...privateCanaries, ...canaryFragments]) {
      expect(read.package!.transcript!.contains(c), isFalse, reason: c);
    }
    await h.done(tester);
  });

  testWidgets('delete removes the private recording only', (tester) async {
    final h = _Harness();
    await recordJourney(h.controller, StepClock(), BookingJourney.cancelledReview);
    await h.pump(tester);
    await tester.tap(find.text('Book a desk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-recording-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('task-recording-delete-confirm')));
    await tester.pumpAndSettle();
    expect(await h.store.list(), isEmpty);
    expect(find.text('No recordings on this device.'), findsOneWidget);
    await h.done(tester);
  });

  testWidgets('the indicator: nothing until opened, then marks routes',
      (tester) async {
    final h = _Harness();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('home')),
      GoRoute(path: '/auth', builder: (_, _) => const Text('sign in')),
      GoRoute(path: '/calendar', builder: (_, _) => const Text('calendar')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) =>
            RecordingIndicator(router: router, child: child!),
      ),
    ));
    await tester.pumpAndSettle();
    expect(h.container.exists(recorderControllerProvider), isFalse,
        reason: 'the start-up path never creates the recorder');
    expect(find.byKey(const ValueKey('recording-indicator')), findsNothing);

    h.container.read(recorderOpenedProvider.notifier).open();
    await h.controller.start(scope: canaryScope);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recording-indicator')), findsOneWidget);

    router.go('/auth');
    await tester.pumpAndSettle();
    router.go('/calendar');
    await tester.pumpAndSettle();
    expect(h.controller.snapshot!.steps.map((s) => s.kind),
        [StepKind.excluded, StepKind.unrecorded]);
    expect(h.controller.snapshot!.steps.first.protectedCategory,
        ProtectedSurface.authentication);

    await tester.tap(find.byKey(const ValueKey('recording-indicator-pause')));
    await tester.pumpAndSettle();
    expect(h.controller.state, RecorderState.paused);
    await tester.tap(find.byKey(const ValueKey('recording-indicator-stop')));
    await tester.pumpAndSettle();
    expect(h.controller.state, RecorderState.ended);
    expect(find.byKey(const ValueKey('recording-indicator')), findsNothing);
    await h.done(tester);
  });
}
