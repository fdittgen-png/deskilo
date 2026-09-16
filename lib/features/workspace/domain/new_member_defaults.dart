// SPDX-License-Identifier: 0BSD
//
// #1294 — how a newly joining member starts.
//
// `members.subscription_pct` defaults to 100 and `members.overage_policy`
// to 'blocked' as COLUMN defaults, so a workspace could not say
// otherwise: a template that configured tariffs, hours and features
// still left every new member on a product default.
//
// It lives in `billing_rules.new_member_defaults` rather than in new
// columns, so it travels with the `tariffs` entity that already carries
// `billing_rules` (#1276 S1 gave that entity its merge semantics).
//
// Applied by `join_workspace` and `create_managed_member` on INSERT only.
// Someone re-joining keeps what they had — the server names these
// columns in the insert and never in the `on conflict` branch — and
// changing the rule never rewrites anybody already here.
//
// Pure Dart: no Flutter, no l10n. The CLI imports this layer.
library;

import 'overage_policy.dart';

/// The key inside `billing_rules`.
const String newMemberDefaultsKey = 'new_member_defaults';

/// What a member starts with when nothing is configured — the column
/// defaults, stated here so the UI can show what "unset" actually means
/// instead of an empty field.
const int defaultNewMemberSubscriptionPct = 100;
const OveragePolicy defaultNewMemberOveragePolicy = OveragePolicy.blocked;

/// The workspace's answer to "how does somebody joining start?".
class NewMemberDefaults {
  const NewMemberDefaults({
    this.subscriptionPct = defaultNewMemberSubscriptionPct,
    this.overagePolicy = defaultNewMemberOveragePolicy,
    this.configured = false,
  });

  /// 1–100. The server refuses anything outside that, because
  /// `members_subscription_pct_check` is 1..100 and a stored zero could
  /// never be applied to anybody (#1279 S1 is what makes zero legal).
  final int subscriptionPct;

  /// What happens once the entitlement is used up.
  final OveragePolicy overagePolicy;

  /// Whether the workspace said this, or these are the product defaults.
  /// The difference is worth showing: "nothing chosen" and "chosen to be
  /// the same as the default" read identically otherwise.
  final bool configured;

  /// Reads `billing_rules`. Unknown and malformed values fall back to
  /// the product defaults rather than throwing — an older client must
  /// survive a newer server, and a settings screen that cannot render
  /// is worse than one showing the default.
  factory NewMemberDefaults.fromRules(Map<String, dynamic>? rules) {
    final raw = rules?[newMemberDefaultsKey];
    if (raw is! Map) return const NewMemberDefaults();
    final pct = switch (raw['subscription_pct']) {
      final int n when n >= 1 && n <= 100 => n,
      final String s when int.tryParse(s) != null &&
              int.parse(s) >= 1 &&
              int.parse(s) <= 100 =>
        int.parse(s),
      _ => defaultNewMemberSubscriptionPct,
    };
    return NewMemberDefaults(
      subscriptionPct: pct,
      overagePolicy: OveragePolicy.fromName(
        raw['overage_policy'] is String
            ? raw['overage_policy'] as String
            : null,
      ),
      configured: true,
    );
  }

  /// The value for `set_billing_rule(workspace, 'new_member_defaults', …)`.
  Map<String, Object?> toValue() => {
        'subscription_pct': subscriptionPct,
        'overage_policy': overagePolicy.name,
      };

  NewMemberDefaults copyWith({
    int? subscriptionPct,
    OveragePolicy? overagePolicy,
  }) =>
      NewMemberDefaults(
        subscriptionPct: subscriptionPct ?? this.subscriptionPct,
        overagePolicy: overagePolicy ?? this.overagePolicy,
        configured: true,
      );

  @override
  bool operator ==(Object other) =>
      other is NewMemberDefaults &&
      other.subscriptionPct == subscriptionPct &&
      other.overagePolicy == overagePolicy &&
      other.configured == configured;

  @override
  int get hashCode => Object.hash(subscriptionPct, overagePolicy, configured);
}
