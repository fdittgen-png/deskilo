// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2354 — what VIES said, the last time a member's VAT number was asked.
enum ViesStatus {
  /// Never checked.
  none,

  /// VIES found the number valid: evidence of a business customer.
  valid,

  /// VIES knows the number is not valid.
  invalid,

  /// VIES (or the member state behind it) did not answer: no evidence,
  /// and a reverse charge waits.
  unavailable;

  static ViesStatus fromWire(String? wire) =>
      values.firstWhere((s) => s.name == wire, orElse: () => none);
}

/// The last check of a member's VAT number (`members.vies_*`, 0404),
/// written only by the `vies-check` edge function.
class ViesCheck {
  const ViesCheck({
    this.vatId = '',
    this.status = ViesStatus.none,
    this.consultation = '',
    this.checkedAt,
    this.detail = '',
  });

  /// The number as checked.
  final String vatId;
  final ViesStatus status;

  /// The VIES consultation number, the evidence a reverse charge keeps.
  final String consultation;
  final DateTime? checkedAt;

  /// What VIES said when it did not answer.
  final String detail;

  static const ViesCheck none = ViesCheck();

  /// From the member columns (`vies_status`, …) or the function's answer
  /// (`status`, …).
  factory ViesCheck.fromRow(Map<String, dynamic> row) {
    String text(String key) => (row['vies_$key'] ?? row[key]) as String? ?? '';
    final at = (row['vies_checked_at'] ?? row['checked_at']) as String?;
    return ViesCheck(
      vatId: text('vat_id'),
      status: ViesStatus.fromWire(text('status')),
      consultation: text('consultation'),
      checkedAt: at == null ? null : DateTime.parse(at).toLocal(),
      detail: text('detail'),
    );
  }
}
