// SPDX-License-Identifier: 0BSD

/// What an invoice CHARGES FOR (#802, migration 0142).
///
/// A subscription is paid in advance, so its invoice has to exist before
/// the month it covers; what the month actually cost — overage,
/// accessories, services, packages, adjustments — cannot be known until
/// the month ends. One document could never be both, so there are two.
enum InvoiceKind {
  /// The historical whole-month document: every pre-0142 invoice, and
  /// still what issuing by hand produces.
  full,

  /// The monthly fee, issued AHEAD of the period it covers.
  subscription,

  /// Everything the month actually cost, issued once it is over.
  usage,

  /// Several invoices regrouped into one (#803).
  settlement;

  static InvoiceKind fromWire(String? raw) =>
      InvoiceKind.values.asNameMap()[raw ?? ''] ?? InvoiceKind.full;

  /// Whether this document charges the fee for a month still to come.
  /// The reader needs telling: an invoice dated 28 August for September
  /// otherwise looks like a mistake.
  bool get isInAdvance => this == InvoiceKind.subscription;
}

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

  factory BillingRules.fromJson(Map<String, dynamic> json) => BillingRules(
        subscriptionAuto: json[keySubscriptionAuto] != false,
        subscriptionAdvanceDays:
            ((json[keySubscriptionAdvanceDays] as num?)?.toInt() ?? 3)
                .clamp(minAdvanceDays, maxAdvanceDays),
        usageAuto: json[keyUsageAuto] != false,
        usageWhenZero: json[keyUsageWhenZero] == true,
      );

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
  static const int maxAdvanceDays = 28;

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
  final firstOfMonth = DateTime(period.year, period.month);
  return firstOfMonth.subtract(Duration(days: rules.subscriptionAdvanceDays));
}
