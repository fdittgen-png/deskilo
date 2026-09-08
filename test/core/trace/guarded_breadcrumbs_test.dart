// SPDX-License-Identifier: 0BSD
//
// #1012 — every guarded action leaves its start and its end in the
// trace: a button that "does nothing" shows a start with no end.
import 'package:deskilo/core/trace/guarded.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TraceLogger logger;
  setUp(() => logger = TraceLogger.instance = TraceLogger());

  Future<void> run(WidgetTester tester, Future<void> Function() action) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => runGuarded(context,
                domain: 'workspace',
                message: 'workspace XML export failed',
                errorText: 'It failed.',
                action: action),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('a success leaves "started" then "done"', (tester) async {
    await run(tester, () async {});
    final messages = logger.entries.map((e) => e.message).toList();
    expect(messages, contains('workspace XML export — started'));
    expect(messages, contains('workspace XML export — done'));
  });

  testWidgets('a failure leaves "started" then the error, never "done"',
      (tester) async {
    await run(tester, () async => throw StateError('boom'));
    final messages = logger.entries.map((e) => e.message).toList();
    expect(messages, contains('workspace XML export — started'));
    expect(messages, isNot(contains('workspace XML export — done')));
    expect(logger.entries.any((e) => e.level == TraceLevel.error && e.error!.contains('boom')), isTrue);
  });
}
