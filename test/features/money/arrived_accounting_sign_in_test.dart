// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3906 — a target's sign-in held for the page that completes it is
// completed by the person it came back to, while it is still worth it:
// sign-out or another account drops it, and an old one is dropped unread.
import 'dart:async';

import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/application/arrived_accounting_sign_in.dart';
import 'package:deskilo/features/money/domain/accounting_sign_in_return.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _back = SignInReturn(state: 'c.s', code: 'C');

class _Session implements SessionSource {
  final controller = StreamController<String?>.broadcast();
  String? id;

  @override
  Stream<String?> authStateChanges() => controller.stream;

  @override
  String? get currentUserId => id;
}

class _Clock implements Clock {
  DateTime at = DateTime(2026, 11, 13, 10);

  @override
  DateTime now() => at;
}

Future<void> _turn() => Future<void>.delayed(Duration.zero);

void main() {
  test('a hold older than the server\'s lifetime is dropped unread', () {
    final clock = _Clock();
    final arrived = ArrivedAccountingSignIn(clock.now)..hold(_back);
    clock.at = clock.at.add(signInReturnLifetime);
    expect(arrived.held, same(_back));
    clock.at = clock.at.add(const Duration(seconds: 1));
    expect(arrived.held, isNull);
    expect(arrived.holds, isFalse);
  });

  test('signing in to complete keeps the hold; signing out or another '
      'account drops it', () async {
    final session = _Session();
    final container = ProviderContainer(
      overrides: [
        sessionSourceProvider.overrideWithValue(session),
        clockProvider.overrideWithValue(_Clock()),
      ],
    );
    addTearDown(container.dispose);
    final arrived = (container..listen(sessionStateProvider, (_, _) {}))
        .read(arrivedAccountingSignInProvider)
      ..hold(_back);
    session.controller.add('user-1');
    await _turn();
    expect(arrived.held, same(_back), reason: 'signed in to complete it');

    session.controller.add(null);
    await _turn();
    expect(arrived.held, isNull, reason: 'signed out');

    arrived.hold(_back);
    session.controller.add('user-1');
    await _turn();
    session.controller.add('user-2');
    await _turn();
    expect(arrived.held, isNull, reason: 'another account');
  });
}
