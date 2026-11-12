// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 — an enrolled kiosk names itself to the badge function on both
// steps (`x-deskilo-kiosk: <device id>.<credential>`); a device without an
// enrolment sends no such header. The scan's name is the server's: shown
// when it gives one, never made up here. Which device counts is the
// server's decision (pgTAP 400).
import 'dart:convert';

import 'package:deskilo/core/backend/auth_secret_store.dart';
import 'package:deskilo/core/backend/kiosk_credential_store.dart';
import 'package:deskilo/features/auth/data/supabase_auth_repository.dart';
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

class _Secrets implements AuthSecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

const _device = '00000000-0000-4000-8000-000000003675';
final _secret = 'ab' * 32;

void main() {
  late List<http.BaseRequest> asked;

  SupabaseAuthRepository over(
    Map<String, Object?> answer, {
    KioskCredential? kiosk,
  }) {
    asked = [];
    return SupabaseAuthRepository(
      SupabaseClient(
        'https://project.supabase.co',
        'anon-key',
        httpClient: MockClient((request) async {
          asked.add(request);
          return http.Response(
            jsonEncode(answer),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
      ),
      kioskCredential: () async => kiosk,
    );
  }

  final enrolled = KioskCredential(
    workspaceId: 'ws',
    deviceId: _device,
    name: 'Front desk',
    secret: _secret,
  );

  test(
    'an enrolled kiosk sends its credential on the scan and on the PIN',
    () async {
      final repo = over({
        'ok': true,
        'display_name': 'Ana Martin',
      }, kiosk: enrolled);
      await repo.identifyBadge('04a1b2c3d4e5f6');
      await repo.signInWithBadge(uid: '04a1b2c3d4e5f6', pin: '482615');
      expect(asked, hasLength(2));
      for (final request in asked) {
        expect(request.headers['x-deskilo-kiosk'], '$_device.$_secret');
      }
    },
  );

  test('a device without an enrolment sends no kiosk header', () async {
    final repo = over({'ok': true});
    await repo.identifyBadge('04a1b2c3d4e5f6');
    expect(asked.single.headers.containsKey('x-deskilo-kiosk'), isFalse);
  });

  test('the scan greets with the name the server gives, and with none when it gives none', () async {
    final named = await over({
      'ok': true,
      'display_name': 'Ana Martin',
    }, kiosk: enrolled).identifyBadge('04a1b2c3d4e5f6');
    expect(named.value?.displayName, 'Ana Martin');
    final unnamed = await over({
      'ok': true,
      'display_name': '',
    }, kiosk: enrolled).identifyBadge('04a1b2c3d4e5f6');
    expect(unnamed.value?.displayName, '');
  });

  test('the store keeps one enrolment and forgets it', () async {
    final store = InMemoryKioskCredentialStore();
    expect(await store.read(), isNull);
    await store.write(enrolled);
    expect((await store.read())?.header, '$_device.$_secret');
    await store.forget();
    expect(await store.read(), isNull);
  });

  test(
    'a stored value that does not read is no enrolment, under its server',
    () async {
      final secrets = _Secrets();
      final here = SecureKioskCredentialStore(
        secrets,
        Uri.parse('https://a.example'),
      );
      final there = SecureKioskCredentialStore(
        secrets,
        Uri.parse('https://b.example'),
      );
      await here.write(enrolled);
      expect((await here.read())?.deviceId, _device);
      expect(
        await there.read(),
        isNull,
        reason: 'another server never reads it',
      );
      secrets.values.updateAll((_, _) => 'not json');
      expect(await here.read(), isNull);
    },
  );
}
