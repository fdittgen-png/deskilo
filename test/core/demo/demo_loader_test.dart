// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3848 -- entering the Demo waits for its deferred library: the app's own
// loading state while it is fetched, a said failure with a retry when it
// cannot be, and the Demo itself once it is.
import 'dart:async';

import 'package:deskilo/core/demo/demo_loader.dart';
import 'package:deskilo/core/demo/presentation/demo_environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _gate(Future<void> Function() loader) => ProviderScope(
  overrides: [demoLibraryLoaderProvider.overrideWithValue(loader)],
  child: DemoGate(
    child: Builder(
      builder: (context) => Text(
        DemoEnvironment.maybeOf(context) == null ? 'live' : 'in the demo',
        textDirection: TextDirection.ltr,
      ),
    ),
  ),
);

/// Lets the load, the rebuild and the retry's rebuild run.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // On the Dart VM the deferred library is part of the program: loading it
  // completes at once. Done here so a test's fake clock never waits on it.
  setUpAll(loadDemoLibrary);

  testWidgets('shows the loading state until the library is there', (
    tester,
  ) async {
    final fetched = Completer<void>();
    await tester.pumpWidget(
      _gate(() async {
        await fetched.future;
      }),
    );
    await tester.pump();
    expect(find.byKey(DemoGate.loadingKey), findsOneWidget);
    expect(find.text('in the demo'), findsNothing);

    fetched.complete();
    await _settle(tester);
    expect(find.byKey(DemoGate.loadingKey), findsNothing);
    expect(find.text('in the demo'), findsOneWidget);
  });

  testWidgets('a failed fetch says so and a retry asks again', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _gate(() async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
      }),
    );
    await _settle(tester);
    expect(find.byKey(DemoGate.failedKey), findsOneWidget);
    expect(find.byKey(DemoGate.retryKey), findsOneWidget);
    expect(find.text('in the demo'), findsNothing);

    await tester.tap(find.byKey(DemoGate.retryKey));
    await _settle(tester);
    expect(attempts, 2);
    expect(find.byKey(DemoGate.failedKey), findsNothing);
    expect(find.text('in the demo'), findsOneWidget);
  });
}
