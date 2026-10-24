// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 — the favourite heart of My spaces, kept on the account by the
// workspace's qualified reference (`set_workspace_favorite_ref_v1`, 9999).
// The personal home marks a space of its own the person may mark, or one
// of another installation they hold a membership fact in force for; any
// other reference is refused and nothing is written.

/// Why the personal home did not keep a favourite.
enum AccountFavoriteRefusal {
  /// The reference is malformed, or names no space of that home (22023).
  unknownReference,

  /// The person holds no relationship the home can verify (42501), or the
  /// session is not one the home accepts.
  noRelationship,

  /// The home has no such writer yet (an older installation).
  unsupported,
}

/// The personal home refused the favourite: nothing was written there.
class AccountFavoriteRefused implements Exception {
  const AccountFavoriteRefused(this.reason, {this.detail});

  final AccountFavoriteRefusal reason;
  final String? detail;

  @override
  String toString() => 'AccountFavoriteRefused(${reason.name}'
      '${detail == null ? '' : ': $detail'})';
}

/// The refusal a SQLSTATE stands for, or null when it is not one.
AccountFavoriteRefusal? accountFavoriteRefusalOf(String? code) =>
    switch (code) {
      '22023' => AccountFavoriteRefusal.unknownReference,
      '42501' || 'P0001' => AccountFavoriteRefusal.noRelationship,
      'PGRST202' || '42883' => AccountFavoriteRefusal.unsupported,
      _ => null,
    };
