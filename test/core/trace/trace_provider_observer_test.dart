// SPDX-License-Identifier: 0BSD
//
// #742 — a provider that fails leaves a line in the trace, whichever
// provider it is; and the app's root scope carries the observer.
import 'dart:io';

import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/core/trace/trace_provider_observer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _boom = FutureProvider<int>((ref) async => throw StateError('boom'),
    name: 'boomProvider');

void main() {
  test('a failing provider is logged with its name, error and stack', () async {
    final logger = TraceLogger();
    final previous = TraceLogger.instance;
    TraceLogger.instance = logger;
    addTearDown(() => TraceLogger.instance = previous);

    final container = ProviderContainer(
      observers: const [TraceProviderObserver()],
    );
    addTearDown(container.dispose);
    await expectLater(container.read(_boom.future), throwsStateError);

    final entry = logger.entries.singleWhere((e) => e.area == 'provider');
    expect(entry.message, 'boomProvider failed');
    expect(entry.error, contains('boom'));
    expect(entry.stack, isNotNull);
  });

  test('main.dart installs the observer on the root ProviderScope', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('observers: const [TraceProviderObserver()]'));
  });
}
