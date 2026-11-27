// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4402 -- a save on the shared guarded path answers instead of showing a
// snackbar: null when it succeeded, the caller's sentence for what it threw
// otherwise; its start, its end and its failure are in the trace, and the
// watcher hears of it as of any guarded command. A guarded read answers its
// value, or the fallback for what it threw, and traces the failure.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/core/trace/guarded.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonShapeException;
import 'package:flutter_test/flutter_test.dart';

class _Watcher implements GuardedCommandWatcher {
  final endings = <(Object?, bool)>[];

  @override
  Object? started(String domain, String message) => message;

  @override
  void ended(Object token, {Object? error, bool pending = false}) => endings.add((error, pending));
}

void main() {
  late TraceLogger logger;
  setUp(() => logger = TraceLogger.instance = TraceLogger());
  tearDown(() => guardedCommandWatcher = null);

  test('a save that succeeds answers null and leaves "started" then "done"', () async {
    final said = await guardSave(
      domain: 'stock',
      message: 'a place was not saved',
      action: () async {},
      problem: (_) => 'never',
    );
    expect(said, isNull);
    final messages = logger.entries.map((e) => e.message).toList();
    expect(messages, containsAll(['a place was not saved — started', 'a place was not saved — done']));
  });

  test('a save that fails answers the sentence of what it threw and traces it', () async {
    final watcher = guardedCommandWatcher = _Watcher();
    final said = await guardSave(
      domain: 'stock',
      message: 'a place was not saved',
      action: () async => throw StateError('refused'),
      problem: (e) => e is StateError ? 'The place was refused.' : 'other',
    );
    expect(said, 'The place was refused.');
    expect(logger.entries.map((e) => e.message), isNot(contains('a place was not saved — done')));
    expect(logger.entries.any((e) => e.level == TraceLevel.warn && e.error!.contains('refused')), isTrue);
    expect(watcher.endings.single.$1, isA<StateError>(), reason: 'the watcher hears of the failure');
  });

  test('a guarded read answers its value, or the fallback of what it threw', () async {
    expect(await guardRead(domain: 'stock', message: 'read', read: () async => 3, fallback: (_) => 0), 3);
    Object? seen;
    final v = await guardRead<int?>(
      domain: 'stock',
      message: 'the variants could not be read',
      read: () async => throw StateError('offline'),
      fallback: (e) {
        seen = e;
        return null;
      },
    );
    expect(v, isNull);
    expect(seen, isA<StateError>());
    expect(logger.entries.any((e) => e.message == 'the variants could not be read' && e.level == TraceLevel.warn), isTrue);
  });

  test('a fault is traced as an error, a refusal the server worded as a warning', () async {
    TraceLevel levelOf(String message) => logger.entries.lastWhere((e) => e.message == message).level;
    // An answer that could not be read is a fault somebody has to look at: an
    // error, which may be reported, on a read and on a save alike.
    await guardRead<int?>(
      domain: 'stock',
      message: 'unreadable read',
      read: () async => throw const JsonShapeException('items', 'unit', 'String', 'null'),
      fallback: (_) => null,
    );
    await guardSave(
      domain: 'stock',
      message: 'unreadable save',
      action: () async => throw const JsonShapeException('items', 'unit', 'String', 'null'),
      problem: (_) => 'no',
    );
    await guardSave(
      domain: 'stock',
      message: 'refused save',
      action: () async => throw const Refusal(code: DkCode.dkl04, message: 'not an open draft'),
      problem: (_) => 'no',
    );
    expect(levelOf('unreadable read'), TraceLevel.error);
    expect(levelOf('unreadable save'), TraceLevel.error);
    expect(levelOf('refused save'), TraceLevel.warn);
  });
}
