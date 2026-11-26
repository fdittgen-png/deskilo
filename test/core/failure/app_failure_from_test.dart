// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4413 -- what was caught becomes one of four failures, and a command one of three outcomes.
import 'dart:async';
import 'dart:io';

import 'package:deskilo/core/cache/read_failure.dart';
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/data/app_failure_from.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonShapeException;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthRetryableFetchException, PostgrestException;

void main() {
  test('a server refusal keeps its code, sentence and details', () {
    final f = appFailureFrom(const PostgrestException(message: 'not an open draft', code: DkCode.dkl04, details: 'r-1'));
    expect(f, isA<Refusal>().having((r) => r.code, 'code', DkCode.dkl04).having((r) => r.details, 'details', 'r-1'));
  });

  test('a gateway status is a transport failure: the commit is unknown', () {
    final f = appFailureFrom(const PostgrestException(message: 'Bad gateway', code: '502'));
    expect(f, isA<TransportFailure>().having((t) => t.status, 'status', 502));
  });

  test('a local StateError is a refusal raised before anything was sent', () {
    expect(appFailureFrom(StateError('nothing to pay')), isA<Refusal>().having((r) => r.code, 'code', isNull));
  });

  test('a lost socket, a timeout and an auth fetch that did not answer are transport failures', () {
    expect(appFailureFrom(const SocketException('down')), isA<TransportFailure>());
    expect(appFailureFrom(TimeoutException('slow')), isA<TransportFailure>());
    expect(appFailureFrom(AuthRetryableFetchException(message: 'offline')), isA<TransportFailure>());
  });

  test('an unreadable answer and a defect are told apart', () {
    expect(appFailureFrom(const FormatException('bad json')), isA<Unreadable>());
    expect(appFailureFrom(ArgumentError('bug')), isA<Defect>());
    const done = Refusal(code: 'X');
    expect(identical(appFailureFrom(done), done), isTrue, reason: 'a converted failure passes through');
  });

  test('a row of the wrong shape and a cached read that did not parse are unreadable, never a defect', () {
    const shape = JsonShapeException('invoices', 'total', 'num', 'String');
    expect(appFailureFrom(shape), isA<Unreadable>().having((u) => u.cause, 'cause', same(shape)));
    expect(appFailureFrom(const CachedReadInvalid('vat-rates', shape)), isA<Unreadable>());
  });

  test('a command keeps the stack of what it caught, on a refusal and on a failure', () async {
    Never deep() => throw const PostgrestException(message: 'no', code: DkCode.dkc07);
    final refused = await runCommand<int>(() async => deep());
    expect((refused as CommandRefused<int>).stack.toString(), contains('deep'));
    final lost = await runCommand<int>(() async => throw const SocketException('down'));
    expect((lost as CommandUnreached<int>).stack, isNotNull);
  });

  test('an unreadable answer or a defect is traced as an error; a refusal or a lost connection as a warning', () async {
    final levels = <String, TraceLevel>{};
    final sub = TraceLogger.instance.added.listen((e) => levels[e.message.split(':').first] = e.level);
    await runCommand<int>(() async => throw const JsonShapeException('t', 'k', 'int', 'null'), what: 'unreadable');
    await runCommand<int>(() async => throw ArgumentError('bug'), what: 'defect');
    await runCommand<int>(() async => throw const PostgrestException(message: 'no', code: DkCode.dkc07), what: 'refused');
    await runCommand<int>(() async => throw const SocketException('down'), what: 'lost');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(levels, {
      'unreadable': TraceLevel.error,
      'defect': TraceLevel.error,
      'refused': TraceLevel.warn,
      'lost': TraceLevel.warn,
    });
  });

  test('a command answers done, refused or unreached', () async {
    expect(await runCommand(() async => 7), isA<CommandDone<int>>().having((d) => d.value, 'value', 7));
    expect(
      await runCommand<int>(() async => throw const PostgrestException(message: 'no', code: DkCode.dkc07)),
      isA<CommandRefused<int>>().having((r) => r.refusal.code, 'code', DkCode.dkc07),
    );
    expect(
      await runCommand<int>(() async => throw const SocketException('down')),
      isA<CommandUnreached<int>>().having((u) => u.failure, 'failure', isA<TransportFailure>()),
    );
  });
}
