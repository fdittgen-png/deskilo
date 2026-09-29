// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1652 — an invitation issued on ANOTHER server survives the server
// switch and the restart it needs, so the person does not paste it
// again after signing in there. It is a secret: it lives in the
// platform's secure storage (never in preferences, logs or the route),
// for one hour, and it is only offered back on the server it names.
// Offered back means typed into the Join field — never joined.
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/auth_secret_store.dart';
import '../../../core/backend/backend_settings.dart';
import '../../../core/time/clock.dart';
import '../domain/invite_uri.dart';

part 'pending_invitation.g.dart';

abstract class PendingInvitationStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecurePendingInvitationStore implements PendingInvitationStore {
  const SecurePendingInvitationStore([
    this._secrets = const PlatformAuthSecretStore(),
  ]);
  final AuthSecretStore _secrets;
  static const _key = 'deskilo.invitation.pending';

  @override
  Future<String?> read() => _secrets.read(_key);

  @override
  Future<void> write(String? value) =>
      value == null ? _secrets.delete(_key) : _secrets.write(_key, value);
}

class InMemoryPendingInvitationStore implements PendingInvitationStore {
  InMemoryPendingInvitationStore([this.value]);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

@Riverpod(keepAlive: true)
PendingInvitationStore pendingInvitationStore(Ref ref) =>
    const SecurePendingInvitationStore();

class PendingInvitations {
  const PendingInvitations(this._store, this._clock);
  final PendingInvitationStore _store;
  final Clock _clock;

  static const lifetime = Duration(hours: 1);

  /// Keeps [text] for the server [invitation] names. A legacy code names
  /// none, so there is nothing to carry.
  Future<void> keep(InvitationDescriptor invitation, String text) async {
    final origin = canonicalBackendUrl(invitation.target?.endpoint.url ?? '');
    if (origin == null) return;
    await _store.write(
      jsonEncode({
        'v': 1,
        'origin': origin,
        'text': text,
        'expires': _clock.now().add(lifetime).toUtc().toIso8601String(),
      }),
    );
  }

  /// The kept invitation, when it is for [active] and still fresh. A
  /// stale or unreadable one is dropped; one for another server stays.
  Future<String?> offeredOn(BackendEndpoint? active) async {
    final Object? json;
    try {
      json = jsonDecode(await _store.read() ?? 'null');
    } on FormatException {
      await _store.write(null);
      return null;
    }
    if (json is! Map<String, dynamic>) return null;
    final expires = DateTime.tryParse(json['expires'] as String? ?? '');
    final text = json['text'];
    if (json['v'] != 1 ||
        expires == null ||
        text is! String ||
        !_clock.now().isBefore(expires)) {
      await _store.write(null);
      return null;
    }
    if (active == null || canonicalBackendUrl(active.url) != json['origin']) {
      return null;
    }
    return text;
  }

  /// Joined, or set aside: nothing is kept.
  Future<void> clear() => _store.write(null);
}

@riverpod
PendingInvitations pendingInvitations(Ref ref) => PendingInvitations(
  ref.watch(pendingInvitationStoreProvider),
  ref.watch(clockProvider),
);

/// #1652 — an invitation link the OS just opened the app with. Held in
/// memory only (the link carries the secret; it is never written to
/// preferences or kept in the location), until the join field takes it.
/// Taking it fills the field; it never joins.
class ArrivedInvitations {
  String? _link;

  void hold(String link) => _link = link;

  String? take() {
    final link = _link;
    _link = null;
    return link;
  }
}

@Riverpod(keepAlive: true)
ArrivedInvitations arrivedInvitations(Ref ref) => ArrivedInvitations();

/// Whether [uri] is an invitation link as the platform hands it over.
bool isInvitationLink(Uri uri) => uri.scheme == 'deskilo' && uri.host == 'join';
