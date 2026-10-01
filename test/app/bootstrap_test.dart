// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2015 — the essential start-up is started once and given a deadline. A
// hang past the deadline shows the "taking longer" screen, a failure the
// "could not start" screen (localized, nothing sensitive), and a late
// success hands over to the real app exactly once. No wall clock: the
// attempt and the deadline are completers.
import 'dart:async';

import 'package:deskilo/app/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'settles ready when the attempt completes before the deadline',
    () async {
      final attempt = Completer<void>();
      final boot = EssentialBoot(attempt.future);
      attempt.complete();
      expect(await boot.settle(Completer<void>().future), BootState.ready);
    },
  );

  test('a never-completing attempt is slow once the deadline passes', () async {
    final boot = EssentialBoot(Completer<void>().future);
    final deadline = Completer<void>();
    final settled = boot.settle(deadline.future);
    deadline.complete();
    expect(await settled, BootState.slow);
  });

  test('a failure settles failed and keeps the error', () async {
    final attempt = Completer<void>();
    final boot = EssentialBoot(attempt.future);
    attempt.completeError(StateError('secure storage'));
    expect(await boot.settle(Completer<void>().future), BootState.failed);
    expect(boot.error, isA<StateError>());
  });

  testWidgets('slow, then a late success hands over exactly once', (
    tester,
  ) async {
    final attempt = Completer<void>();
    final boot = EssentialBoot(attempt.future);
    final deadline = Completer<void>()..complete();
    expect(await boot.settle(deadline.future), BootState.slow);
    var ready = 0;
    await tester.pumpWidget(
      BootRecoveryApp(boot: boot, onReady: () => ready++),
    );
    expect(find.byKey(const ValueKey('boot-slow')), findsOneWidget);
    attempt.complete();
    await tester.pump();
    await tester.pump();
    expect(ready, 1);
  });

  testWidgets('slow, then a late failure says it could not start, in the '
      'device language, without the backend or the error text', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final attempt = Completer<void>();
    final boot = EssentialBoot(attempt.future);
    expect(await boot.settle(Future<void>.value()), BootState.slow);
    var ready = 0;
    await tester.pumpWidget(
      BootRecoveryApp(boot: boot, onReady: () => ready++),
    );
    await tester.pump(); // the slow screen spins: never settle
    attempt.completeError(StateError('https://secret.supabase.co token'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('boot-failed')), findsOneWidget);
    expect(find.text("DesKilo n'a pas pu démarrer"), findsOneWidget);
    expect(find.textContaining('supabase'), findsNothing);
    expect(ready, 0);
  });
}
