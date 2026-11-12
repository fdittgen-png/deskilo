// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 — this device's enrolment as a kiosk of one business, on this
// server. The credential is handed over once, at enrolment, and kept only
// here, in the platform's secure storage under a key of this server's
// origin: a switch of server never sends one server's credential to
// another. It outlives sign-out on purpose: badge sign-in runs signed out,
// and the badge function is asked with it (`x-deskilo-kiosk`). The server
// keeps only its hash; a lost device is remedied by revoking it there.
// Neither the credential nor its header is ever logged.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../trace/trace_logger.dart';
import 'auth_callback_guard.dart';
import 'auth_secret_store.dart';
import 'installation_auth_storage.dart';

/// This device's enrolment: the business, the device and its credential.
class KioskCredential {
  const KioskCredential({
    required this.workspaceId,
    required this.deviceId,
    required this.name,
    required this.secret,
  });

  final String workspaceId;
  final String deviceId;

  /// The name the device was enrolled under.
  final String name;
  final String secret;

  /// The badge function's header: `<device id>.<credential>`.
  String get header => '$deviceId.$secret';

  String _encode() => jsonEncode({
    'workspace_id': workspaceId,
    'device_id': deviceId,
    'name': name,
    'secret': secret,
  });

  static KioskCredential? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final r = JsonReader.of(jsonDecode(raw), context: 'kiosk enrolment');
      final c = KioskCredential(
        workspaceId: r.string('workspace_id'),
        deviceId: r.string('device_id'),
        name: r.stringOr('name'),
        secret: r.string('secret'),
      );
      return c.workspaceId.isEmpty || c.deviceId.isEmpty || c.secret.isEmpty
          ? null
          : c;
    } on Object catch (e, st) {
      // A value that does not read is no enrolment; the value itself is
      // never logged.
      TraceLogger.instance.warn(
        'kiosk',
        'stored kiosk enrolment unreadable — treated as none',
        error: e.runtimeType,
        stackTrace: st,
      );
      return null;
    }
  }
}

/// Where this device keeps its enrolment.
abstract interface class KioskCredentialStore {
  Future<KioskCredential?> read();
  Future<void> write(KioskCredential credential);

  /// Forgets the enrolment on this device (the server's record stays until
  /// it is revoked there).
  Future<void> forget();
}

/// The platform's secure storage, under this server's origin.
@visibleForTesting
class SecureKioskCredentialStore implements KioskCredentialStore {
  SecureKioskCredentialStore(this._secrets, Uri origin)
    : _key = installationAuthNamespace(origin, 'kiosk.device');

  final AuthSecretStore _secrets;
  final String _key;

  @override
  Future<KioskCredential?> read() async =>
      KioskCredential._decode(await _secrets.read(_key));

  @override
  Future<void> write(KioskCredential credential) =>
      _secrets.write(_key, credential._encode());

  @override
  Future<void> forget() => _secrets.delete(_key);
}

/// An enrolment held in memory: the Demo and tests.
class InMemoryKioskCredentialStore implements KioskCredentialStore {
  InMemoryKioskCredentialStore([this._held]);

  KioskCredential? _held;

  @override
  Future<KioskCredential?> read() async => _held;

  @override
  Future<void> write(KioskCredential credential) async => _held = credential;

  @override
  Future<void> forget() async => _held = null;
}

/// The badge function's header for this device's enrolment, or none.
Future<Map<String, String>?> kioskBadgeHeaders(
  KioskCredentialStore store,
) async {
  final held = await store.read();
  return held == null ? null : {'x-deskilo-kiosk': held.header};
}

/// This device's enrolment store, for the server the app was started on.
final kioskCredentialStoreProvider = Provider<KioskCredentialStore>((ref) {
  final origin = bootAuthCallbackGuard?.origin;
  return origin == null
      ? InMemoryKioskCredentialStore()
      : SecureKioskCredentialStore(const PlatformAuthSecretStore(), origin);
});
