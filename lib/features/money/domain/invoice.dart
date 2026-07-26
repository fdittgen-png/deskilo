// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

part 'invoice.freezed.dart';

/// One line of an invoice (0060).
@freezed
sealed class InvoiceLine with _$InvoiceLine {
  const factory InvoiceLine({
    required String label,
    required int amountCents,
  }) = _InvoiceLine;
}

/// An IMMUTABLE invoice from the archive (0060): every displayed detail
/// is a SNAPSHOT taken at issue time — names, addresses and the issuer
/// can change later without ever rewriting an issued document. The
/// [signature] is the server's SHA-256 fingerprint over the canonical
/// content, printed on the PDF as the digital signature.
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
  }) = _Invoice;

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
              label: (line as Map)['label'] as String,
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
      );
}
