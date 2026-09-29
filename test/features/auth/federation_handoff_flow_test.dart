// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648 — the handoff contract, driven through the real controller,
// repository, callback guard, dispatcher and isolated SDK exchange. Only the
// system browser and the target's HTTP answers are fakes.
import 'package:deskilo/features/auth/application/federation_handoff_controller.dart';
import 'package:deskilo/features/auth/domain/federation_port.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/federation_fixture.dart';

void main() {
  late FederationTarget target;
  late ProviderContainer container;

  ProviderContainer containerFor(FederationTarget t) {
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(t.repository)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    target = FederationTarget('https://target.example');
    addTearDown(target.dispose);
    container = containerFor(target);
  });

  FederationHandoffController controller([ProviderContainer? c]) =>
      (c ?? container).read(federationHandoffControllerProvider.notifier);
  FederationHandoffState state([ProviderContainer? c]) =>
      (c ?? container).read(federationHandoffControllerProvider);

  test('a double tap opens ONE browser and says it is waiting', () async {
    final first = controller().start();
    final second = controller().start();
    expect(state().stage, FederationStage.opening);
    await Future.wait([first, second]);
    expect(target.launches, hasLength(1));
    expect(state().stage, FederationStage.waiting);
    expect(target.calls, isNot(contains('/auth/v1/signup')));
  });

  test('coming back to the app without a return keeps waiting, once, and '
      'never relaunches', () async {
    await controller().start();
    for (var i = 0; i < 3; i++) {
      controller().resumed();
    }
    await pumpEventQueue();
    expect(
      state().stage,
      FederationStage.waiting,
      reason: 'regaining focus is not a cancellation',
    );
    expect(target.launches, hasLength(1));
    expect(target.calls, isEmpty, reason: 'nothing exchanged, nothing asked');
  });

  test('a delayed return completes the sign-in on the target, then the '
      'panel steps aside', () async {
    await controller().start();
    controller().resumed();
    final stages = <FederationStage?>[];
    container.listen(
      federationHandoffControllerProvider,
      (_, next) => stages.add(next.stage),
    );
    expect(
      await target.deliver(target.returnFor({'code': 'target-code'})),
      true,
    );
    await pumpEventQueue();
    expect(stages.first, FederationStage.completing);
    expect(state().stage, isNull);
    expect(state().failure, isNull);
    expect(target.active.auth.currentUser?.id, 'target-person');
    expect(target.launches, hasLength(1));
    expect(
      target.calls,
      isNot(contains('/auth/v1/signup')),
      reason: 'no second registration',
    );
    expect(target.secrets.values, isEmpty, reason: 'verifier scrubbed');
  });

  test('cancel restores the previous context and a late return is refused, '
      'not exchanged', () async {
    await controller().start();
    final late = target.returnFor({'code': 'target-code'});
    await controller().cancel();
    expect(state().stage, isNull);
    expect(state().failure, isNull);
    expect(await target.deliver(late), false);
    await pumpEventQueue();
    expect(target.calls, isNot(contains('/auth/v1/token')));
    expect(target.active.auth.currentUser, isNull);
    expect(target.secrets.values, isEmpty);
    expect(state().stage, isNull, reason: 'no surprise navigation or stage');
  });

  for (final (name, query, failure) in [
    (
      'the person refused',
      {'error': 'access_denied'},
      FederationFailure.refused,
    ),
    (
      'the provider is switched off',
      {'error': 'server_error', 'error_code': 'provider_disabled'},
      FederationFailure.providerMissing,
    ),
    (
      'an existing account collides',
      {'error': 'server_error', 'error_code': 'identity_already_exists'},
      FederationFailure.unlinkedAccount,
    ),
  ]) {
    test('provider refusal: $name → its own next action', () async {
      await controller().start();
      expect(await target.deliver(target.returnFor(query)), true);
      await pumpEventQueue();
      expect(state().failure, failure);
      expect(state().stage, isNull);
      expect(target.active.auth.currentUser, isNull);
      expect(target.calls, isNot(contains('/auth/v1/token')));
    });
  }

  for (final (name, arrange, failure) in [
    (
      'the Deskilo identity is bound to another account here',
      (FederationTarget t) => t.binding = {
        'status': 'conflict',
        'reason': 'subject_bound_to_another_user',
      },
      FederationFailure.unlinkedAccount,
    ),
    (
      'this account is bound to another Deskilo identity',
      (FederationTarget t) => t.binding = {
        'status': 'conflict',
        'reason': 'local_user_bound_elsewhere',
      },
      FederationFailure.wrongAccount,
    ),
    (
      'the server speaks for another authority',
      (FederationTarget t) => t.advertisedIssuer = 'https://other.example',
      FederationFailure.incompatibleServer,
    ),
    (
      'the server does not answer',
      (FederationTarget t) => t.tokenStatus = 503,
      FederationFailure.network,
    ),
  ]) {
    test('verification: $name → no session, a distinct failure', () async {
      arrange(target);
      await controller().start();
      await target.deliver(target.returnFor({'code': 'target-code'}));
      await pumpEventQueue();
      expect(state().failure, failure);
      expect(
        target.active.auth.currentUser,
        isNull,
        reason: 'an unproved session never replaces the context',
      );
      expect(target.calls, isNot(contains('/auth/v1/signup')));
    });
  }

  test(
    'a server without Deskilo sign-in fails before any browser opens',
    () async {
      target.authority = null;
      await controller().start();
      expect(state().failure, FederationFailure.providerMissing);
      expect(target.launches, isEmpty);
    },
  );

  test(
    'a browser that cannot open is said so, and the flow is scrubbed',
    () async {
      target.browserOpens = false;
      await controller().start();
      expect(state().failure, FederationFailure.browserUnavailable);
      expect(target.secrets.values, isEmpty);
      await controller().start();
      expect(
        target.launches,
        hasLength(2),
        reason: 'retry is a second explicit attempt: a second launch',
      );
    },
  );

  test('a flow that expired while away is reported as expired on resume, '
      'not relaunched', () async {
    var now = DateTime.utc(2026, 9, 28, 12);
    final slow = FederationTarget('https://slow.example', now: () => now);
    addTearDown(slow.dispose);
    final c = containerFor(slow);
    await controller(c).start();
    now = now.add(const Duration(hours: 2));
    controller(c).resumed();
    await pumpEventQueue();
    expect(state(c).failure, FederationFailure.expired);
    expect(slow.launches, hasLength(1));
    expect(await slow.deliver(slow.returnFor({'code': 'target-code'})), false);
  });

  test('an abandoned attempt A never lands on the retry B', () async {
    await controller().start();
    final returnA = target.returnFor({'code': 'code-a'});
    await controller().cancel();
    await controller().start();
    expect(target.launches, hasLength(2));
    expect(
      await target.deliver(returnA),
      false,
      reason: 'A no longer owns the callback',
    );
    await pumpEventQueue();
    expect(state().stage, FederationStage.waiting);
    expect(target.calls, isNot(contains('/auth/v1/token')));
  });

  test('two parallel target flows: each return is owned by exactly one '
      'target, and A never answers B', () async {
    final other = FederationTarget('https://target-b.example');
    addTearDown(other.dispose);
    final b = containerFor(other);
    await controller().start();
    await controller(b).start();
    final returnA = target.returnFor({'code': 'code-a'});
    final returnB = other.returnFor({'code': 'code-b'});
    expect(await other.deliver(returnA), false, reason: 'not B\'s callback');
    expect(await target.deliver(returnB), false, reason: 'not A\'s callback');
    expect(await target.deliver(returnA), true);
    await pumpEventQueue();
    expect(target.active.auth.currentUser?.id, 'target-person');
    expect(other.active.auth.currentUser, isNull);
    expect(
      state(b).stage,
      FederationStage.waiting,
      reason: 'A\'s result is not B\'s',
    );
    expect(other.calls, isEmpty);
  });

  test('reopened after the app was stopped: the restored flow shows as '
      'waiting, is never relaunched, and its return still completes', () async {
    await controller().start();
    final returned = target.returnFor({'code': 'target-code'});
    // A new process: the controller is rebuilt over the same guard, which
    // restores its pending flow from the protected store.
    await target.guard.restore();
    final reopened = containerFor(target);
    expect(state(reopened).stage, FederationStage.waiting);
    controller(reopened).resumed();
    expect(target.launches, hasLength(1));
    expect(await target.deliver(returned), true);
    await pumpEventQueue();
    expect(state(reopened).stage, isNull);
    expect(target.active.auth.currentUser?.id, 'target-person');
  });

  test('a return opened on another device finds no pending flow there and '
      'is refused, not exchanged', () async {
    await controller().start();
    final returned = target.returnFor({'code': 'target-code'});
    final otherDevice = FederationTarget('https://target.example');
    addTearDown(otherDevice.dispose);
    expect(await otherDevice.deliver(returned), false);
    expect(otherDevice.calls, isEmpty);
    expect(otherDevice.active.auth.currentUser, isNull);
  });
}
