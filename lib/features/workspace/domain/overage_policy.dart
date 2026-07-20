// SPDX-License-Identifier: MIT

/// How a member is treated once they have used their whole monthly
/// half-day entitlement (migration 0041). Persisted by name — never
/// rename a value.
enum OveragePolicy {
  /// No booking past the entitlement (+ confirmed extensions). The member
  /// must request extra half-days or buy a package. The default.
  blocked,

  /// Pay-as-you-go: the member may book past the entitlement; every extra
  /// half-day bills at the fee band's overage rate.
  payg,

  /// The member must buy a pre-defined package of days first.
  package;

  /// Parses the server's `overage_policy` text, tolerant of unknown /
  /// missing values (older `member_statement` bodies omit the field).
  static OveragePolicy fromName(String? name) {
    return OveragePolicy.values
            .where((p) => p.name == name)
            .firstOrNull ??
        OveragePolicy.blocked;
  }
}
