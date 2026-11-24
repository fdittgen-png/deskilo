// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4413 -- what was caught becomes one of four failures, and a command one of three outcomes.
import 'dart:async';
import 'dart:io';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/data/app_failure_from.dart';
import 'package:deskilo/core/failure/app_failure.dart';
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
