// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

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
    required DateTime matchedAt,
    @Default('') String byName,
  }) = _InvoiceMatch;

  const InvoiceMatch._();

  bool get pending => status == 'pending';
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
  }) = _Invoice;

  bool get isVoided => voidedAt != null;

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
            ),
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
        attendance: [
          for (final entry in ((row['details'] as Map?)?['attendance']
                  as List? ??
              const []))
            InvoiceAttendance(
              startsAt: (entry as Map)['starts_at'] as String? ?? '',
              endsAt: entry['ends_at'] as String? ?? '',
              space: entry['space'] as String? ?? '',
              status: entry['status'] as String? ?? '',
            ),
        ],
      );
}
