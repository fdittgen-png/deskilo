// SPDX-License-Identifier: AGPL-3.0-or-later
// #1791: each callback belongs to one unexpired installation/account flow;
// wrong targets, replay, stale accounts and malformed returns are refused.
import 'package:deskilo/core/backend/auth_callback_guard.dart';
import 'package:flutter_test/flutter_test.dart';

import 'installation_auth_storage_test.dart' show MemorySecrets;

Uri returned(String redirect, {String code = 'one-use-code'}) {
  final uri = Uri.parse(redirect);
  return uri.replace(queryParameters: {...uri.queryParameters, 'code': code});
}

void main() {
  final a = Uri.parse('https://auth.example:8443');
  final b = Uri.parse('https://auth.example:9443');
  final callback = Uri.parse('deskilo://auth-callback');

  test('only the originating installation consumes a callback, once', () async {
    final secrets = MemorySecrets();
    final first = AuthCallbackGuard(secrets, a, callback);
    final second = AuthCallbackGuard(secrets, b, callback);
    final one = returned(await first.begin('social'));
    final two = returned(await second.begin('social'));
    expect(first.claim(two), false);
    expect(second.claim(one), false);
    expect(first.claim(one), true);
    expect(first.claim(one), false);
    expect(second.claim(two), true);
  });

  test(
    'reopen restores the flow; expiry and account switching reject it',
    () async {
      final secrets = MemorySecrets();
      var now = DateTime.utc(2026, 9, 28);
      final first = AuthCallbackGuard(secrets, a, callback, now: () => now);
      final response = returned(await first.begin('link', account: 'original'));
      final restored = AuthCallbackGuard(secrets, a, callback, now: () => now);
      await restored.restore();
      expect(restored.claim(response, account: 'different'), false);
      expect(restored.claim(response, account: 'original'), true);
      now = now.add(const Duration(hours: 2));
      expect(first.claim(response, account: 'original'), false);
    },
  );

  test(
    'cancelled, duplicate-parameter, implicit and foreign-path returns fail',
    () async {
      final guard = AuthCallbackGuard(MemorySecrets(), a, callback);
      final old = returned(await guard.begin('social'));
      final current = returned(await guard.begin('social'));
      expect(guard.claim(old), false);
      expect(guard.claim(current.replace(host: 'another-route')), false);
      expect(guard.claim(Uri.parse('$current&code=another')), false);
      expect(
        guard.claim(current.replace(fragment: 'access_token=foreign')),
        false,
      );
      expect(
        guard.claim(
          current.replace(
            queryParameters: {
              ...current.queryParameters,
              'access_token': 'foreign',
            },
          ),
        ),
        false,
      );
      expect(guard.claim(current), true);
      final flow = guard.flow;
      final later = returned(await guard.begin('social'));
      await guard.finish(flow);
      expect(
        guard.claim(later),
        true,
        reason: 'late completion cannot cancel a newer flow',
      );
    },
  );

  test(
    'web callback is bound to the deployment path and same origin',
    () async {
      final guard = AuthCallbackGuard(
        MemorySecrets(),
        a,
        Uri.parse('https://app.example/deskilo/'),
      );
      final response = returned(await guard.begin('social'));
      expect(guard.claim(response.replace(path: '/')), false);
      expect(guard.claim(response.replace(host: 'other.example')), false);
      expect(guard.claim(response), true);
    },
  );
}
