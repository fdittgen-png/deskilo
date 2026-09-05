// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

import 'billing_rules.dart';
import 'vat_rate.dart';

part 'invoice.freezed.dart';

/// One position of an invoice. Since 0062 positions are DERIVED from
/// the month's tracked data — [kind] names the source (subscription |
/// overage | accessories | level | office | desk | service | package |
/// adjustment), [label] carries its data (the pct, the catalog
/// description), and the client renders localized wording per kind.
/// Legacy 0060 free-form lines have an empty [kind] and render their
/// [label] verbatim.
@freezed
sealed class InvoiceLine with _$InvoiceLine {
  const factory InvoiceLine({
    @Default('') String kind,
    required String label,
    @Default(1) int quantity,
    required int amountCents,

    /// The VAT rate this position was taxed at (0072). Prices are
    /// INCLUSIVE, so [amountCents] is the gross and the tax is extracted
    /// from it with `vatSplit`. 0 = no VAT (every pre-0072 line, and every
    /// credit — money moving is not a supply).
    @Default(0.0) double vatPercent,

    /// #831 — on a settlement, the number of the source invoice this
    /// position was carried over from; '' on every other document.
    @Default('') String sourceNumber,
  }) = _InvoiceLine;
}

/// One annex activity row (0064): a confirmed ledger movement of the
/// invoiced month, with its booking date. Credits carry negative
/// amounts.
@freezed
sealed class InvoiceDetailEntry with _$InvoiceDetailEntry {
  const factory InvoiceDetailEntry({
    required String on,
    required String category,
    @Default('') String label,
    required int amountCents,
  }) = _InvoiceDetailEntry;
}

/// One annex attendance row (0064): a reservation of the invoiced
/// month. Timestamps are the workspace's local wall clock, snapshotted
/// as 'yyyy-MM-ddTHH:mm'.
@freezed
sealed class InvoiceAttendance with _$InvoiceAttendance {
  const factory InvoiceAttendance({
    required String startsAt,
    required String endsAt,
    @Default('') String space,
    @Default('') String status,
  }) = _InvoiceAttendance;
}

/// An invoice's payment MATCH (0067): the lifecycle metadata beside the
/// immutable document. `pending` while a validation quorum decides;
/// rejects delete the match (the invoice reopens), so a loaded match is
/// either awaiting validation or standing.
@freezed
sealed class InvoiceMatch with _$InvoiceMatch {
  const factory InvoiceMatch({
    required String invoiceId,
    required int paidCents,
    required String resolution,
    @Default('') String note,
    @Default('confirmed') String status,
    // 0068 — the REGISTERED payment this match consumed.
    String? paymentLedgerId,
    required DateTime matchedAt,
    @Default('') String byName,

    /// #504 — when the outstanding remainder of an under-paid match was
    /// written off through the validation framework. Null = the
    /// invoice is STILL OPEN and owed.
    DateTime? writeoffAt,

    /// #841 — the event that had to be validated before this match
    /// stood. Null on matches recorded before the column was read, and
    /// on the ones no rule ever governed.
    String? eventId,
  }) = _InvoiceMatch;

  const InvoiceMatch._();

  bool get pending => status == 'pending';
}

/// One party of an invoice as the document FROZE it (0069) — the legal
/// identity EN 16931 needs and the flat 0060 snapshot never carried.
///
/// One shape for both sides: the buyer simply leaves the seller-only
/// fields ([legalId], [vatRegime], [taxExemptionReason]) empty. Legacy
/// invoices carry no parties at all; the presentation layer rebuilds them
/// from the flat snapshot plus the live workspace identity (sellerOf).
@freezed
sealed class InvoiceParty with _$InvoiceParty {
  const factory InvoiceParty({
    @Default('') String name,

    /// #886 — the organisation the person is invoiced through (BT-45,
    /// the buyer's trading name); '' for a private person.
    @Default('') String company,

    /// BT-35 — one line; legacy free-text addresses land here whole.
    @Default('') String street,

    /// BT-37.
    @Default('') String city,

    /// BT-38.
    @Default('') String postalCode,

    /// BT-40 / BT-55 — ISO 3166-1 alpha-2, mandatory on both parties.
    @Default('') String country,

    /// BT-31 (seller) / BT-48 (buyer).
    @Default('') String vatId,

    /// BT-30, the company register number — the seller identifier a
    /// category-O invoice is allowed to carry.
    @Default('') String legalId,

    /// Wire value of [VatRegime]; seller only.
    @Default('not_subject') String vatRegime,

    /// Free-text exemption reason (BT-120); seller only.
    @Default('') String taxExemptionReason,

    /// #886 — the contact the document is sent to (BT-43 / BT-42).
    @Default('') String email,
    @Default('') String phone,
  }) = _InvoiceParty;

  /// Reads one party out of the invoice's `parties` jsonb. Named away
  /// from `fromJson` on purpose: that name would make freezed reach for
  /// json_serializable and demand a generated part file.
  factory InvoiceParty.fromSnapshot(Map<dynamic, dynamic> json) => InvoiceParty(
    name: json['name'] as String? ?? '',
    company: json['company'] as String? ?? '',
    street: json['street'] as String? ?? '',
    city: json['city'] as String? ?? '',
    postalCode: json['postal_code'] as String? ?? '',
    country: json['country'] as String? ?? '',
    vatId: json['vat_id'] as String? ?? '',
    legalId: json['legal_id'] as String? ?? '',
    vatRegime: json['vat_regime'] as String? ?? 'not_subject',
    taxExemptionReason: json['tax_exemption_reason'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
  );
}

/// One invoice folded into a settlement (#804), snapshotted when it was
/// regrouped — number, period, kind, total AND its positions, so the
/// settlement stays readable as a trail back to what it consolidated
/// even if a source is corrected afterwards.
@freezed
sealed class SettledSource with _$SettledSource {
  const factory SettledSource({
    required String invoiceId,
    required String number,
    String? period,
    @Default(InvoiceKind.full) InvoiceKind kind,
    required int totalCents,
    @Default([]) List<InvoiceLine> lines,
  }) = _SettledSource;

  factory SettledSource.fromSnapshot(Map<dynamic, dynamic> json) =>
      SettledSource(
        invoiceId: json['invoice_id'] as String? ?? '',
        number: json['number'] as String? ?? '',
        period: json['period'] as String?,
        kind: InvoiceKind.fromWire(json['kind'] as String?),
        totalCents: (json['total_cents'] as num?)?.toInt() ?? 0,
        lines: [
          for (final line in (json['lines'] as List? ?? const []))
            InvoiceLine(
              kind: (line as Map)['kind'] as String? ?? '',
              label: line['label'] as String? ?? '',
              quantity: (line['quantity'] as num?)?.toInt() ?? 1,
              amountCents: (line['amount_cents'] as num?)?.toInt() ?? 0,
              vatPercent: (line['vat_percent'] as num?)?.toDouble() ?? 0,
              sourceNumber: line['source_number'] as String? ?? '',
            ),
        ],
      );
}

/// An IMMUTABLE invoice from the archive (0060): every displayed detail
/// is a SNAPSHOT taken at issue time — names, addresses and the issuer
/// can change later without ever rewriting an issued document. The
/// [signature] is the server's SHA-256 fingerprint over the canonical
/// content, printed on the PDF as the digital signature.
///
/// Correction (0061): a wrong invoice is tagged erroneous ([voidedAt],
/// the sole one-way change the server permits) and re-issued as a
/// replacement carrying [replacesInvoiceId] (technical reference) and
/// [replacesNumber] (snapshot for display and the PDF).
@freezed
sealed class Invoice with _$Invoice {
  const Invoice._();

  const factory Invoice({
    required String id,
    required String workspaceId,
    required String memberId,
    required String number,
    required DateTime issuedAt,
    String? period,
    required String title,
    required List<InvoiceLine> lines,
    required int totalCents,
    required String currency,
    required String memberName,
    required String memberAddress,
    required String workspaceName,
    required String workspaceAddress,
    required String issuerName,
    required String signature,
    DateTime? voidedAt,
    @Default('') String voidedByName,
    String? replacesInvoiceId,
    @Default('') String replacesNumber,
    // 0064 — the optional SNAPSHOTTED annex; compact invoices carry
    // neither.
    @Default(false) bool detailed,
    @Default([]) List<InvoiceDetailEntry> detailLedger,
    @Default([]) List<InvoiceAttendance> attendance,
    // 0069 — the parties' legal identity, snapshotted for the e-invoice.
    // Null on pre-0069 documents.
    InvoiceParty? sellerParty,
    InvoiceParty? buyerParty,
    // 0072 — the VAT breakdown as issued, one entry per rate. Empty on
    // pre-0072 invoices and on workspaces that charge no VAT.
    @Default([]) List<InvoiceVatTotal> vatTotals,

    /// #802 (0142) — what this document charges for: the subscription of
    /// a month still to come, what a finished month actually cost, a
    /// regrouping of several, or the historical whole month. Every
    /// pre-0142 row reads [InvoiceKind.full], which is what it is.
    @Default(InvoiceKind.full) InvoiceKind kind,

    /// #804 — the settlement that now carries this invoice's balance.
    /// The document itself is untouched: it stays exactly as issued and
    /// simply stops being separately owed.
    String? settledByInvoiceId,

    /// #804 — on a settlement, what it consolidated.
    @Default([]) List<SettledSource> settles,
  }) = _Invoice;

  /// Sum of the positive positions — the gross the invoice charges before
  /// its month's payments are netted off.
  int get chargesCents => lines
      .where((line) => line.amountCents > 0)
      .fold(0, (sum, line) => sum + line.amountCents);

  /// The tax contained in those charges. 0 when no VAT applies.
  int get vatCents => vatTotals.fold(0, (sum, total) => sum + total.vatCents);

  /// The charges without their tax.
  int get netCents => vatTotals.isEmpty
      ? chargesCents
      : vatTotals.fold(0, (sum, total) => sum + total.netCents);

  /// Whether this document actually carries tax — the PDF and the exports
  /// only show a breakdown when there is one.
  bool get hasVat => vatCents > 0;

  bool get isVoided => voidedAt != null;

  /// #831 — regrouped into a settlement and not voided: documentation
  /// only, every operation happens on the settlement.
  bool get isFolded => settledByInvoiceId != null && !isVoided;

  /// The breakdown the documents render, one entry per rate.
  ///
  /// The SNAPSHOT wins whenever there is one: it is what the signature
  /// covers. Only a pre-0072 invoice falls back to deriving it, and there
  /// every line carries 0 %, so the fallback yields the single zero-rated
  /// entry those documents always showed.
  List<InvoiceVatTotal> vatBreakdown({required String zeroCategory}) =>
      vatTotals.isNotEmpty
      ? vatTotals
      : vatTotalsOf([
          for (final line in lines)
            (amountCents: line.amountCents, vatPercent: line.vatPercent),
        ], zeroCategory: zeroCategory);

  factory Invoice.fromRow(Map<String, dynamic> row) => Invoice(
    id: row['id'] as String,
    workspaceId: row['workspace_id'] as String,
    memberId: row['member_id'] as String,
    number: row['number'] as String,
    issuedAt: DateTime.parse(row['issued_at'] as String).toLocal(),
    period: row['period'] as String?,
    title: row['title'] as String,
    lines: [
      for (final line in (row['lines'] as List? ?? const []))
        InvoiceLine(
          kind: (line as Map)['kind'] as String? ?? '',
          label: line['label'] as String? ?? '',
          quantity: (line['quantity'] as num?)?.toInt() ?? 1,
          amountCents: (line['amount_cents'] as num).toInt(),
          vatPercent: (line['vat_percent'] as num?)?.toDouble() ?? 0,
          sourceNumber: line['source_number'] as String? ?? '',
        ),
    ],
    kind: InvoiceKind.fromWire(row['kind'] as String?),
    settledByInvoiceId: row['settled_by_invoice_id'] as String?,
    settles: [
      for (final source in (row['settles'] as List? ?? const []))
        SettledSource.fromSnapshot(source as Map),
    ],
    totalCents: (row['total_cents'] as num).toInt(),
    currency: row['currency'] as String,
    memberName: row['member_name'] as String? ?? '',
    memberAddress: row['member_address'] as String? ?? '',
    workspaceName: row['workspace_name'] as String? ?? '',
    workspaceAddress: row['workspace_address'] as String? ?? '',
    issuerName: row['issuer_name'] as String? ?? '',
    signature: row['signature'] as String,
    voidedAt: row['voided_at'] == null
        ? null
        : DateTime.parse(row['voided_at'] as String).toLocal(),
    voidedByName: row['voided_by_name'] as String? ?? '',
    replacesInvoiceId: row['replaces_invoice_id'] as String?,
    replacesNumber: row['replaces_number'] as String? ?? '',
    detailed: row['details'] != null,
    detailLedger: [
      for (final entry
          in ((row['details'] as Map?)?['ledger'] as List? ?? const []))
        InvoiceDetailEntry(
          on: (entry as Map)['on'] as String? ?? '',
          category: entry['category'] as String? ?? '',
          label: entry['description'] as String? ?? '',
          amountCents: (entry['amount_cents'] as num?)?.toInt() ?? 0,
        ),
    ],
    vatTotals: [
      for (final total in (row['vat_totals'] as List? ?? const []))
        InvoiceVatTotal.fromJson(total as Map),
    ],
    sellerParty: switch ((row['parties'] as Map?)?['seller']) {
      final Map<dynamic, dynamic> seller => InvoiceParty.fromSnapshot(seller),
      _ => null,
    },
    buyerParty: switch ((row['parties'] as Map?)?['buyer']) {
      final Map<dynamic, dynamic> buyer => InvoiceParty.fromSnapshot(buyer),
      _ => null,
    },
    attendance: [
      for (final entry
          in ((row['details'] as Map?)?['attendance'] as List? ?? const []))
        InvoiceAttendance(
          startsAt: (entry as Map)['starts_at'] as String? ?? '',
          endsAt: entry['ends_at'] as String? ?? '',
          space: entry['space'] as String? ?? '',
          status: entry['status'] as String? ?? '',
        ),
    ],
  );
}
