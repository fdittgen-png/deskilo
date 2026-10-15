// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in installation_auth_storage_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'dart:async';

import 'package:deskilo/core/backend/auth_secret_store.dart';

class MemorySecrets implements AuthSecretStore {
  final values = <String, String>{};
  Completer<void>? delay;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    await delay?.future;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}
