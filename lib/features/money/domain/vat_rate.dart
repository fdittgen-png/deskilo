import '../../../core/data/system_columns.dart';
// SPDX-License-Identifier: 0BSD

/// One VAT rate a workspace charges (0072). A "reduced" rate is not a
/// different EN 16931 category — it is still `S` with its own percentage.
/// #947 — the fiscal GROUP a supply belongs to. The law reasons in
/// groups, not percentages: a rate change by law is one edit on the
/// group, and the EN 16931 category and the outside-base rule follow.
enum VatGroup {
  standard('standard', 'S', false),
  intermediate('intermediate', 'S', false),
  reduced('reduced', 'S', false),
  superReduced('super_reduced', 'S', false),
  zero('zero', 'Z', false),
  exempt('exempt', 'E', false),
  notSubject('not_subject', 'O', false),

  /// A refundable deposit (consigne, Pfand): outside the VAT base where
  /// the law puts it there; on a taxed invoice it cannot be e-invoiced
  /// under EN 16931 beside taxed lines (BR-O-11) — the readiness check
  /// says so.
  deposit('deposit', 'O', true),

  /// Alcohol, sugar drinks: the excise is inside the price and the VAT is
  /// the standard rate — a group because the accountant books it apart.
  excise('excise', 'S', false);

  const VatGroup(this.wire, this.category, this.outsideBase);
  final String wire;

  /// The EN 16931 VAT category code the group carries.
  final String category;
  final bool outsideBase;

  static VatGroup fromWire(String? wire) =>
      values.where((g) => g.wire == wire).firstOrNull ?? VatGroup.standard;
}

/// #947 — the group a bare percentage falls in, by the same rule the
/// database used to back-fill existing rates (0170).
VatGroup vatGroupForPercent(double percent, {String category = 'S'}) {
  if (category == 'E') return VatGroup.exempt;
  if (category == 'O') return VatGroup.notSubject;
  if (percent == 0) return VatGroup.zero;
  if (percent >= 15) return VatGroup.standard;
  if (percent >= 8) return VatGroup.intermediate;
  if (percent >= 4) return VatGroup.reduced;
  return VatGroup.superReduced;
}

class VatRate implements SystemStamped {
  const VatRate({
    this.id = '',
    required this.label,
    required this.percent,
    this.category = 'S',
    this.isDefault = false,
    this.active = true,
    this.groupKey = 'standard',
    this.outsideBase = false,
    this.exemptionReason = '',
    this.validFrom = '1900-01-01',
    this.validTo,
    this.supersedesId = '',
    this.system = SystemColumns.none,
  });

  /// #992 — the server's stamp on this row.
  @override
  final SystemColumns system;

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

  /// #947 — the fiscal group ([VatGroup.wire]).
  final String groupKey;

  /// #947 — outside the VAT base (a refundable deposit).
  final bool outsideBase;

  /// #947 — the reason an exempt or not-subject group prints.
  final String exemptionReason;

  /// #985 — the first day this version is in force (ISO date). Every
  /// rate that never changed starts in 1900.
  final String validFrom;

  /// #985 — the day the next version takes over (ISO date), null while
  /// this one is current.
  final String? validTo;

  /// #985 — the version this one replaced: the family link a change by
  /// law creates. Items keep pointing at the old row; the lookup walks
  /// the family.
  final String supersedesId;

  VatGroup get group => VatGroup.fromWire(groupKey);

  /// Whether this version is dated at all — what the screen prints.
  bool get isDated => validFrom != '1900-01-01' || validTo != null;

  VatRate copyWith({
    String? label,
    double? percent,
    String? category,
    bool? isDefault,
    bool? active,
    String? groupKey,
    bool? outsideBase,
    String? exemptionReason,
    String? validFrom,
    String? validTo,
    bool clearValidTo = false,
    String? supersedesId,
  }) =>
      VatRate(
        id: id,
        label: label ?? this.label,
        percent: percent ?? this.percent,
        category: category ?? this.category,
        isDefault: isDefault ?? this.isDefault,
        active: active ?? this.active,
        groupKey: groupKey ?? this.groupKey,
        outsideBase: outsideBase ?? this.outsideBase,
        exemptionReason: exemptionReason ?? this.exemptionReason,
        validFrom: validFrom ?? this.validFrom,
        validTo: clearValidTo ? null : (validTo ?? this.validTo),
        supersedesId: supersedesId ?? this.supersedesId,
      );

  factory VatRate.fromRow(Map<String, dynamic> row) => VatRate(
        system: SystemColumns.fromRow(row),
        id: row['id'] as String,
        label: row['label'] as String? ?? '',
        percent: (row['percent'] as num?)?.toDouble() ?? 0,
        category: row['category'] as String? ?? 'S',
        isDefault: row['is_default'] as bool? ?? false,
        groupKey: row['group_key'] as String? ?? 'standard',
        outsideBase: row['outside_base'] as bool? ?? false,
        exemptionReason: row['exemption_reason'] as String? ?? '',
        active: row['active'] as bool? ?? true,
        validFrom: row['valid_from'] as String? ?? '1900-01-01',
        validTo: row['valid_to'] as String?,
        supersedesId: row['supersedes_id'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'label': label,
        'percent': percent,
        'category': category,
        'is_default': isDefault,
        'group_key': groupKey,
        'outside_base': outsideBase,
        'exemption_reason': exemptionReason,
        'active': active,
        'valid_from': validFrom,
        'valid_to': validTo,
        'supersedes_id': supersedesId,
      };
}

/// #985 — the value of [rateId]'s family in force on [date]: the Dart
/// twin of `vat_rate_percent_at` (0182). A family is every version
/// linked through [VatRate.supersedesId], either way. Null when the
/// family has no active version at all — the caller falls back to the
/// workspace default.
double? vatPercentAt(List<VatRate> rates, String rateId, DateTime date) {
  final byId = {for (final r in rates) r.id: r};
  final family = <String>{};
  final queue = [rateId];
  while (queue.isNotEmpty) {
    final id = queue.removeLast();
    if (!family.add(id)) continue;
    final me = byId[id];
    if (me != null && me.supersedesId.isNotEmpty) queue.add(me.supersedesId);
    for (final r in rates) {
      if (r.supersedesId == id) queue.add(r.id);
    }
  }
  final day = DateTime(date.year, date.month, date.day);
  bool inWindow(VatRate r) {
    final from = DateTime.tryParse(r.validFrom) ?? DateTime(1900);
    final to = r.validTo == null ? null : DateTime.tryParse(r.validTo!);
    return !from.isAfter(day) && (to == null || to.isAfter(day));
  }

  final candidates = [
    for (final id in family)
      if (byId[id] case final r? when r.active && inWindow(r)) r,
  ];
  if (candidates.isEmpty) {
    final self = byId[rateId];
    return self != null && self.active ? self.percent : null;
  }
  candidates.sort((a, b) {
    final byStart = b.validFrom.compareTo(a.validFrom);
    if (byStart != 0) return byStart;
    return (b.id == rateId ? 1 : 0) - (a.id == rateId ? 1 : 0);
  });
  return candidates.first.percent;
}

/// #985 — the tax point of a billed month (`vat_tax_point`): its last
/// day, or [today] when the month is billed ahead — the prepayment rule.
DateTime vatTaxPoint(String period, DateTime today) {
  final parts = period.split('-');
  final year = int.tryParse(parts[0]) ?? today.year;
  final month = parts.length > 1 ? int.tryParse(parts[1]) ?? today.month : today.month;
  final last = DateTime(year, month + 1, 0);
  final day = DateTime(today.year, today.month, today.day);
  return last.isBefore(day) ? last : day;
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
    // #894 — charges count, and so does a line that NAMES a rate even
    // when it is negative: an avoir reverses the tax it gives back
    // (art. 219). A payment carries no rate and stays out — money
    // moving is not a supply.
    if (line.amountCents <= 0 && line.vatPercent <= 0) continue;
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
