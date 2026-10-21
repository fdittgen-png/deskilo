// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1916 / #2603 -- whether the issue form may issue, and what it tells the
// person when it may not, as a decision on what the server answered
// (`invoice_essentials_missing`, the keys it names) instead of conditions
// inside the form's build. The form maps each answer to its widgets; the
// table test pins the rule.
//
// Pure Dart.
library;

/// Which explanation the issue form shows above a blocked submit.
enum InvoiceIssueBlock {
  /// Nothing is missing, or there is nothing to issue yet.
  none,

  /// Essentials are missing: the list says which.
  missing,

  /// The VAT treatment is not one the app issues (#1917): issue it outside
  /// the app.
  external,

  /// Invoicing is off in this workspace.
  disabled,
}

/// The form's state, read as the server's readiness answer.
class InvoiceIssueReadiness {
  const InvoiceIssueReadiness({
    required this.memberId,
    required this.lineCount,
    required this.missing,
    this.correctionReason = '',
  });

  final String? memberId;
  final int lineCount;

  /// The keys the server names as missing.
  final List<String> missing;
  final String correctionReason;

  /// Submit is offered only when the server would issue it.
  bool get canIssue => memberId != null && lineCount > 0 && missing.isEmpty;

  /// The banner's explanation; [InvoiceIssueBlock.none] hides it.
  InvoiceIssueBlock get block => lineCount == 0 || missing.isEmpty
      ? InvoiceIssueBlock.none
      : missing.contains('invoice_feature_disabled')
      ? InvoiceIssueBlock.disabled
      : missing.contains('vat_treatment_unreviewed')
      ? InvoiceIssueBlock.external
      : InvoiceIssueBlock.missing;

  /// #2440 -- the correction reason is asked only when the server names it,
  /// and stays while one is typed.
  bool get asksCorrectionReason =>
      lineCount > 0 &&
      (missing.contains('correction_reason') || correctionReason.isNotEmpty);
}
