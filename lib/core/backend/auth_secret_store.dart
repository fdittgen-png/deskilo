// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Native credentials use the platform key store. On web this protects data
/// at rest only: JavaScript running in the application's origin can access it.
abstract interface class AuthSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformAuthSecretStore implements AuthSecretStore {
  const PlatformAuthSecretStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
