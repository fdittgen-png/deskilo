// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import '../../../core/settings/setting_defaults.g.dart';
import '../../../core/time/calendar_days.dart';

// The kind moved to its own file (#3402), where the invoice model reads it;
// importers of this file keep reading it here until the sweep.
export 'invoice_kind.dart';

/// When the two automatic invoice runs happen, stored in
/// `workspaces.billing_rules` (migration 0142).
///
/// Every field is a decision an owner can defend to their members, which
/// is why none of them is hard-coded: when the subscription invoice
/// arrives, whether the end-of-month one is raised at all, and whether a
/// member who owes nothing extra still gets the document that says so.
class BillingRules {
  const BillingRules({
    this.subscriptionAuto = true,
    this.subscriptionAdvanceDays = 3,
    this.usageAuto = true,
    this.usageWhenZero = false,
  });

  factory BillingRules.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'billing_rules');
    return BillingRules(
      subscriptionAuto: r.boolOr(keySubscriptionAuto, fallback: true),
      subscriptionAdvanceDays: (r.intOrNull(keySubscriptionAdvanceDays) ?? 3)
          .clamp(minAdvanceDays, maxAdvanceDays),
      usageAuto: r.boolOr(keyUsageAuto, fallback: true),
      usageWhenZero: r.boolOr(keyUsageWhenZero, fallback: false),
    );
  }

  /// Whether the nightly run issues subscription invoices at all. Off,
  /// the owner issues them by hand like any other invoice.
  final bool subscriptionAuto;

  /// How many days BEFORE the month starts its subscription invoice is
  /// issued. 0 means on the first of the month itself.
  final int subscriptionAdvanceDays;

  /// Whether the nightly run issues the end-of-month difference invoice.
  final bool usageAuto;

  /// Whether that invoice is raised even when the month cost nothing
  /// extra — a document reading zero, which is a CONFIRMATION rather
  /// than a demand: the member sees the subscription covered everything.
  /// Off, no extras means no invoice.
  final bool usageWhenZero;

  /// The server clamps to the same bounds (`least(greatest(…, 0), 28)`).
  /// 28 because a longer lead would cross into the month before last and
  /// stop meaning "just before the month starts".
  static const int minAdvanceDays = 0;
  static const int maxAdvanceDays = SettingDefaults.billingMaxAdvanceDays;

  static const String keySubscriptionAuto = 'subscription_auto';
  static const String keySubscriptionAdvanceDays = 'subscription_advance_days';
  static const String keyUsageAuto = 'usage_auto';
  static const String keyUsageWhenZero = 'usage_when_zero';

  static const BillingRules defaults = BillingRules();

  Map<String, Object> toJson() => {
        keySubscriptionAuto: subscriptionAuto,
        keySubscriptionAdvanceDays: subscriptionAdvanceDays,
        keyUsageAuto: usageAuto,
        keyUsageWhenZero: usageWhenZero,
      };

  BillingRules copyWith({
    bool? subscriptionAuto,
    int? subscriptionAdvanceDays,
    bool? usageAuto,
    bool? usageWhenZero,
  }) =>
      BillingRules(
        subscriptionAuto: subscriptionAuto ?? this.subscriptionAuto,
        subscriptionAdvanceDays:
            subscriptionAdvanceDays ?? this.subscriptionAdvanceDays,
        usageAuto: usageAuto ?? this.usageAuto,
        usageWhenZero: usageWhenZero ?? this.usageWhenZero,
      );

  @override
  bool operator ==(Object other) =>
      other is BillingRules &&
      other.subscriptionAuto == subscriptionAuto &&
      other.subscriptionAdvanceDays == subscriptionAdvanceDays &&
      other.usageAuto == usageAuto &&
      other.usageWhenZero == usageWhenZero;

  @override
  int get hashCode => Object.hash(
        subscriptionAuto,
        subscriptionAdvanceDays,
        usageAuto,
        usageWhenZero,
      );
}

/// The day the subscription invoice for [period] is due to be issued,
/// under [rules] — the answer to "when will my members see it?", which
/// the settings screen states rather than leaving the owner to work out
/// from a number of days.
///
/// [period] is the month CHARGED (its first day); the invoice lands that
/// many days earlier, which for a lead longer than the previous month is
/// simply that month's first day.
DateTime subscriptionIssueDay(DateTime period, BillingRules rules) {
  // #1231 — calendar arithmetic, not a Duration. Subtracting 168 hours
  // from 1 November lands at 23:00 on 24 October in a zone that fell
  // back in the week, and the members would see the invoice a day early.
  return addCalendarDays(
    DateTime(period.year, period.month),
    -rules.subscriptionAdvanceDays,
  );
}
