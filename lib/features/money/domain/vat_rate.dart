// SPDX-License-Identifier: 0BSD

/// One VAT rate a workspace charges (0072). A "reduced" rate is not a
/// different EN 16931 category — it is still `S` with its own percentage.
class VatRate {
  const VatRate({
    this.id = '',
    required this.label,
    required this.percent,
    this.category = 'S',
    this.isDefault = false,
    this.active = true,
  });

  /// '' for a rate the owner has just added and not saved yet.
  final String id;

  /// The owner's own word for it ('Standard', 'Réduit 5,5 %').
  final String label;

  /// 0–99.99. Zero means the rate itself carries no tax; which EN 16931
  /// category that is then follows the workspace's declared regime.
  final double percent;

  /// BT-118 (UNCL5305): `S` taxed, `Z` zero-rated, `E` exempt, `O`
  /// outside the scope.
  final String category;

  /// What subscriptions, overage, supplements and adjustments use — and
  /// what a new service starts on. Exactly one per workspace.
  final bool isDefault;

  final bool active;

  VatRate copyWith({
    String? label,
    double? percent,
    String? category,
    bool? isDefault,
    bool? active,
  }) =>
      VatRate(
        id: id,
        label: label ?? this.label,
        percent: percent ?? this.percent,
        category: category ?? this.category,
        isDefault: isDefault ?? this.isDefault,
        active: active ?? this.active,
      );

  factory VatRate.fromRow(Map<String, dynamic> row) => VatRate(
        id: row['id'] as String,
        label: row['label'] as String? ?? '',
        percent: (row['percent'] as num?)?.toDouble() ?? 0,
        category: row['category'] as String? ?? 'S',
        isDefault: row['is_default'] as bool? ?? false,
        active: row['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'label': label,
        'percent': percent,
        'category': category,
        'is_default': isDefault,
        'active': active,
      };
}

/// The VAT contained in a gross amount.
///
/// **Prices in DesKilo are VAT-inclusive**: what the owner types is what
/// the member pays, and the tax is extracted from it. Turning VAT on
/// therefore never changes what anyone owes — the same money, now with the
/// tax shown.
///
/// This is the split, applied PER LINE, mirrored verbatim in migration
/// 0072 and cross-pinned by test:
///
///     net = round(gross × 100 / (100 + percent));   vat = gross − net
///
/// Every total is then a plain sum of lines, so the breakdown, the net
/// total and the payable amount all tie back to the ledger with nothing to
/// reconcile.
({int netCents, int vatCents}) vatSplit(int grossCents, double percent) {
  if (percent <= 0) return (netCents: grossCents, vatCents: 0);
  final net = (grossCents * 100 / (100 + percent)).round();
  return (netCents: net, vatCents: grossCents - net);
}

/// One line of an invoice's VAT breakdown — a rate, and what it applies
/// to. Snapshotted at issue time (0072); pre-0072 invoices carry none.
class InvoiceVatTotal {
  const InvoiceVatTotal({
    required this.percent,
    required this.category,
    required this.grossCents,
    required this.netCents,
    required this.vatCents,
  });

  final double percent;
  final String category;
  final int grossCents;
  final int netCents;
  final int vatCents;

  factory InvoiceVatTotal.fromJson(Map<dynamic, dynamic> json) =>
      InvoiceVatTotal(
        percent: (json['percent'] as num?)?.toDouble() ?? 0,
        category: json['category'] as String? ?? 'S',
        grossCents: (json['gross_cents'] as num?)?.toInt() ?? 0,
        netCents: (json['net_cents'] as num?)?.toInt() ?? 0,
        vatCents: (json['vat_cents'] as num?)?.toInt() ?? 0,
      );
}

/// Builds the breakdown from lines the same way the server does — used for
/// the issue PREVIEW, where no invoice exists yet. One entry per rate,
/// highest first, charges only: a credit is money moving, not a supply.
List<InvoiceVatTotal> vatTotalsOf(
  Iterable<({int amountCents, double vatPercent})> lines, {
  required String zeroCategory,
}) {
  final gross = <double, int>{};
  final net = <double, int>{};
  for (final line in lines) {
    if (line.amountCents <= 0) continue;
    final split = vatSplit(line.amountCents, line.vatPercent);
    gross[line.vatPercent] = (gross[line.vatPercent] ?? 0) + line.amountCents;
    net[line.vatPercent] = (net[line.vatPercent] ?? 0) + split.netCents;
  }
  final percents = gross.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final percent in percents)
      InvoiceVatTotal(
        percent: percent,
        category: percent > 0 ? 'S' : zeroCategory,
        grossCents: gross[percent]!,
        netCents: net[percent]!,
        vatCents: gross[percent]! - net[percent]!,
      ),
  ];
}
