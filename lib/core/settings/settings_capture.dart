// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2589 C1 -- an operation takes the settings it runs on ONCE, with the
// identity they were read for, before it awaits anything. The result is an
// immutable value: a later switch of workspace, account or backend cannot
// retarget it, and two captures never merge because their revision text is
// equal. This is the value #2561's operation contexts carry; it is not a
// second settings store and not a global "current settings".
import 'package:meta/meta.dart';

import '../cache/cache_scope.dart';
import 'settings.dart';

/// Who and where a snapshot was read for. Equal revisions on two
/// identities say nothing about authorization or target.
@immutable
class SettingsIdentity {
  const SettingsIdentity({
    required this.installation,
    required this.workspaceId,
    required this.principal,
  });

  /// The installation (backend origin) the settings were read from.
  final String installation;

  /// The workspace, or null for the installation's own platform view.
  final String? workspaceId;

  /// The signed-in user the read was made for.
  final String principal;

  @override
  bool operator ==(Object other) =>
      other is SettingsIdentity &&
      other.installation == installation &&
      other.workspaceId == workspaceId &&
      other.principal == principal;

  @override
  int get hashCode => Object.hash(installation, workspaceId, principal);

  @override
  String toString() => 'SettingsIdentity($installation, $workspaceId)';
}

/// The settings snapshot of one operation: identity + immutable [settings].
@immutable
class SettingsCapture {
  const SettingsCapture(this.identity, this.settings);

  final SettingsIdentity identity;
  final SettingsSet settings;

  /// A key for a cache or an in-flight operation: the identity AND both
  /// revisions. Equal revision text under different identities differs.
  String get cacheKey => cacheDigest('settings-capture', [
        identity.installation,
        identity.workspaceId ?? '',
        identity.principal,
        settings.fingerprint,
      ], 24);

  @override
  bool operator ==(Object other) =>
      other is SettingsCapture && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}

/// Reads [source] for [identity]. The identity is a parameter, not read
/// again after the await: whatever is selected while the read is in flight,
/// the capture belongs to the identity the caller named.
Future<SettingsCapture> captureSettings(
  SettingsSource source,
  SettingsIdentity identity,
) async =>
    SettingsCapture(identity, await source.load(identity.workspaceId));
