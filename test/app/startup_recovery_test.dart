// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#2015): the REAL initializeApp, with any one of its four stages
// thrown or hung, ends in the recovery screen — never a crash, never a second
// attempt, never an unhandled future — and a late outcome after the deadline
// hands over (or fails) exactly once. The screen stays readable at a narrow
// width and twice the text size. The stages are the seams of initializeApp;
// nothing here touches the Supabase singleton.
import 'dart:async';

import 'package:deskilo/app/app_initializer.dart';
import 'package:deskilo/app/bootstrap.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StartupStages _stages({
  Future<void> Function()? restore,
  Future<void> Function()? supabase,
  Future<void> Function()? attach,
  Future<Never> Function()? read,
}) =>
    StartupStages(
      // #2343 — a server is stored: a build without a default only reaches
      // this start-up after the first-start choice stored one.
      readStored: read ?? () async => referenceEndpoint,
      restoreGuard: (_) => (restore ?? () async {})(),
      initializeSupabase: ({
        required url,
        required key,
        required dispatch,
        required secrets,
        required origin,
      }) =>
          (supabase ?? () async {})(),
      attachCallback: (_, _, _) => (attach ?? () async {})(),
    );

void main() {
  final failures = <String, StartupStages>{
    'preferences': _stages(read: () async => throw StateError('prefs')),
    'secure store': _stages(restore: () async => throw StateError('keychain')),
    'supabase': _stages(supabase: () async => throw StateError('init')),
    'callback': _stages(attach: () async => throw StateError('attach')),
  };

  for (final entry in failures.entries) {
    test('a thrown ${entry.key} stage settles failed, with no stray error',
        () async {
      final stray = <Object>[];
      await runZonedGuarded(() async {
        final boot = EssentialBoot(initializeApp(stages: entry.value));
        expect(await boot.settle(Completer<void>().future), BootState.failed);
        expect(boot.error, isA<StateError>());
      }, (e, _) => stray.add(e));
      expect(stray, isEmpty);
    });
  }

  test('a hung stage is slow at the deadline; its late error fails once',
      () async {
    final stray = <Object>[];
    await runZonedGuarded(() async {
      final hung = Completer<void>();
      final boot = EssentialBoot(
          initializeApp(stages: _stages(supabase: () => hung.future)));
      expect(await boot.settle(Future<void>.value()), BootState.slow);
      var changes = 0;
      boot.state.addListener(() => changes++);
      hung.completeError(StateError('late'));
      await pumpEventQueue();
      expect(boot.state.value, BootState.failed);
      expect(changes, 1);
    }, (e, _) => stray.add(e));
    expect(stray, isEmpty);
  });

  test('a hung stage that finishes late hands over ready, once', () async {
    final hung = Completer<void>();
    final boot = EssentialBoot(
        initializeApp(stages: _stages(restore: () => hung.future)));
    expect(await boot.settle(Future<void>.value()), BootState.slow);
    var changes = 0;
    boot.state.addListener(() => changes++);
    hung.complete();
    await pumpEventQueue();
    expect(boot.state.value, BootState.ready);
    expect(changes, 1);
  });

  for (final failed in [false, true]) {
    testWidgets(
        'the ${failed ? 'failed' : 'slow'} screen reads at 320dp and 2× text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final attempt = Completer<void>();
      final boot = EssentialBoot(attempt.future);
      if (failed) attempt.completeError(StateError('x'));
      await boot.settle(Future<void>.value());
      await tester.pumpWidget(BootRecoveryApp(boot: boot, onReady: () {}));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final title = find.byKey(ValueKey(failed ? 'boot-failed' : 'boot-slow'));
      expect(title, findsOneWidget);
      expect(tester.getSemantics(title).label, isNotEmpty);
    });
  }
}
