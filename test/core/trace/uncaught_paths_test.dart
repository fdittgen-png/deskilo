// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 -- the paths an error can take past every catch reach the trace: an
// error no zone handles arrives at PlatformDispatcher.onError (which is why
// start-up needs no runZonedGuarded), and a failure inside work run with
// tracedCompute is written to the main isolate's trace and rethrown.
import 'package:deskilo/core/trace/trace_hooks.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/core/trace/traced_compute.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

int _fails(int n) => throw StateError('the work failed on $n');

int _double(int n) => n * 2;

void main() {
  test('an error no zone handles is traced by the platform hook, and '
      'keeps propagating', () {
    final onError = FlutterError.onError;
    final dispatcher = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = onError;
      PlatformDispatcher.instance.onError = dispatcher;
    });
    final logger = TraceLogger();
    installGlobalTraceHooks(logger);

    final handled = PlatformDispatcher.instance.onError!(
      StateError('an unawaited future failed'),
      StackTrace.current,
    );

    expect(handled, isFalse, reason: 'the crash semantics stay as they were');
    final entry = logger.entries.single;
    expect(entry.area, 'platform');
    expect(entry.level, TraceLevel.error);
    expect(entry.error, contains('an unawaited future failed'));
  });

  test('a failure inside isolate work is traced once and rethrown', () async {
    final previous = TraceLogger.instance;
    final logger = TraceLogger();
    TraceLogger.instance = logger;
    addTearDown(() => TraceLogger.instance = previous);

    await expectLater(
      tracedCompute(_fails, 7, area: 'images', what: 'a test job'),
      throwsA(anything),
    );
    final entry = logger.entries.single;
    expect(entry.area, 'images');
    expect(entry.level, TraceLevel.error);
    expect(entry.message, contains('a test job failed'));
    expect(entry.error, contains('the work failed on 7'));
  });

  test('a job that succeeds answers its value and writes nothing', () async {
    final previous = TraceLogger.instance;
    final logger = TraceLogger();
    TraceLogger.instance = logger;
    addTearDown(() => TraceLogger.instance = previous);

    expect(await tracedCompute(_double, 21, area: 'images', what: 'x'), 42);
    expect(logger.entries, isEmpty);
  });
}
