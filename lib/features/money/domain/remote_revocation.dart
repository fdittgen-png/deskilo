// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — what an accounting target answered when its connection was
// revoked, and what the person still has to do about it. Pure Dart.
import 'accounting_connection.dart';

/// #2370 — what the target answered when the connection was revoked
/// (RFC 7009), as the edge function recorded it on the revoked connection
/// (`record_accounting_revocation`, service role only).
enum RemoteRevocation {
  /// The target confirmed it forgot the token.
  revoked('revoked'),

  /// The target was asked and did not confirm.
  failed('failed'),

  /// The target documents no revocation, or the connection was made with
  /// a token only the company can withdraw.
  notSupported('not_supported');

  const RemoteRevocation(this.wire);
  final String wire;

  /// Null for a connection revoked before outcomes were recorded, or a
  /// value this build does not know: nothing is then claimed.
  static RemoteRevocation? of(String? wire) {
    for (final v in values) {
      if (v.wire == wire) return v;
    }
    return null;
  }
}

extension RevocationNotice on AccountingConnection {
  /// Whether the person must remove DesKilo in the target's own settings:
  /// the connection is revoked here, and the target did not confirm it
  /// forgot the token (or cannot be asked).
  bool get revocationUnconfirmed =>
      !live &&
      (remoteRevocation == RemoteRevocation.failed ||
          remoteRevocation == RemoteRevocation.notSupported);
}
