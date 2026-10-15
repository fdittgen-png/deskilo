// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- a customer's exemption certificate: resale, nonprofit, government
// or another kind, for one state or (`*`) every state that takes a multistate
// form (SST, MTC). The seller keeps it to justify an untaxed sale; an invoice
// it took lines out of cites it. Written through `set_tax_exemption_certificate`
// and ended through `end_tax_exemption_certificate` (migration 0434): a
// certificate is never deleted, an issued invoice cites it.
import '../../../core/data/json_reader.dart';

/// The kinds the server accepts.
const List<String> taxExemptionKinds = [
  'resale',
  'nonprofit',
  'government',
  'other',
];

class TaxExemptionCertificate {
  const TaxExemptionCertificate({
    required this.id,
    required this.kind,
    required this.state,
    required this.number,
    required this.validFrom,
    this.validTo,
  });

  final String id;
  final String kind;
  final String state;
  final String number;

  /// ISO days; [validTo] is null while the certificate has no end.
  final String validFrom;
  final String? validTo;

  /// Whether it is in force on the ISO day [on].
  bool inForceOn(String on) =>
      validFrom.compareTo(on) <= 0 &&
      (validTo == null || validTo!.compareTo(on) >= 0);

  factory TaxExemptionCertificate.fromRow(Map<Object?, Object?> row) {
    final r = JsonReader.of(row, context: 'tax_exemption_certificate');
    return TaxExemptionCertificate(
      id: r.string('id'),
      kind: r.string('kind'),
      state: r.string('state'),
      number: r.string('number'),
      validFrom: r.string('valid_from'),
      validTo: r.stringOrNull('valid_to'),
    );
  }
}

/// A certificate to record (`set_tax_exemption_certificate`); [validTo] null
/// leaves it open-ended.
class TaxExemptionCertificateDraft {
  const TaxExemptionCertificateDraft({
    required this.workspaceId,
    required this.memberId,
    required this.kind,
    required this.state,
    required this.number,
    required this.validFrom,
    this.validTo,
  });

  final String workspaceId;
  final String memberId;
  final String kind;

  /// A two-letter state, or `*` for a multistate certificate.
  final String state;
  final String number;
  final DateTime validFrom;
  final DateTime? validTo;
}
