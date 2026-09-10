// SPDX-License-Identifier: 0BSD
//
// #1086 — `_invokeBadge` documents its own contract: "a missing
// deployment (404) and a dead network are the SAME answer to the caller
// — `unavailable`". It only held for the 404. Every other infrastructure
// failure — a 500 from the function, a socket error on a tablet whose
// Wi-Fi dropped — was rethrown, and neither caller in the sheet has a
// catch. The spinner stayed up and the button stayed disabled forever,
// with nothing on screen, at the door of the space.
import 'dart:convert';

import 'package:deskilo/features/auth/data/supabase_auth_repository.dart';
import 'package:deskilo/features/auth/domain/badge_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryStorage extends GotrueAsyncStorage {
  final Map<String, String> _items = {};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _items[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}

void main() {
  SupabaseAuthRepository repositoryOver(MockClient client) =>
      SupabaseAuthRepository(
        SupabaseClient(
          'https://project.supabase.co',
          'anon-key',
          httpClient: client,
          authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
        ),
      );

  test('a 500 from the function reads as unavailable, never as refused',
      () async {
    final repo = repositoryOver(MockClient((_) async =>
        http.Response(jsonEncode({'error': 'boom'}), 500,
            headers: {'content-type': 'application/json'})));

    final identify = await repo.identifyBadge('uid-1');
    expect(identify.ok, isFalse);
    expect(identify.failure, BadgeSignInFailure.unavailable);

    final signIn = await repo.signInWithBadge(uid: 'uid-1', pin: '1234');
    expect(signIn.ok, isFalse);
    expect(signIn.failure, BadgeSignInFailure.unavailable);
  });

  test('a dead network reads as unavailable', () async {
    final repo = repositoryOver(MockClient((_) async {
      throw const SocketException('no route to host');
    }));

    final identify = await repo.identifyBadge('uid-1');
    expect(identify.failure, BadgeSignInFailure.unavailable);

    final signIn = await repo.signInWithBadge(uid: 'uid-1', pin: '1234');
    expect(signIn.failure, BadgeSignInFailure.unavailable);
  });

  test('a real refusal is still a refusal, not unavailable', () async {
    final repo = repositoryOver(MockClient((_) async => http.Response(
        jsonEncode({'ok': false, 'reason': 'locked'}), 200,
        headers: {'content-type': 'application/json'})));

    final identify = await repo.identifyBadge('uid-1');
    expect(identify.failure, BadgeSignInFailure.locked);
  });
}

class SocketException implements Exception {
  const SocketException(this.message);
  final String message;
  @override
  String toString() => 'SocketException: $message';
}
