// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1916 / #2603 -- when the issue form may issue and what it says when it
// may not, as a table on the decision (no taps): the form only maps each
// answer to its widgets.
import 'package:deskilo/features/money/domain/invoice_issue_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InvoiceIssueReadiness r(
    List<String> missing, {
    String? member = 'm1',
    int lines = 1,
    String reason = '',
  }) => InvoiceIssueReadiness(
    memberId: member,
    lineCount: lines,
    missing: missing,
    correctionReason: reason,
  );

  final table =
      <String, (InvoiceIssueReadiness, bool, InvoiceIssueBlock, bool)>{
        'complete: issues': (r([]), true, InvoiceIssueBlock.none, false),
        'no member chosen': (
          r([], member: null),
          false,
          InvoiceIssueBlock.none,
          false,
        ),
        'nothing to invoice': (
          r(['seller_address'], lines: 0),
          false,
          InvoiceIssueBlock.none,
          false,
        ),
        'essentials missing (#1916)': (
          r(['seller_address', 'buyer_name']),
          false,
          InvoiceIssueBlock.missing,
          false,
        ),
        'an unreviewed treatment is issued outside the app (#1917)': (
          r(['vat_treatment_unreviewed', 'buyer_name']),
          false,
          InvoiceIssueBlock.external,
          false,
        ),
        'invoicing off wins over every other key': (
          r(['vat_treatment_unreviewed', 'invoice_feature_disabled']),
          false,
          InvoiceIssueBlock.disabled,
          false,
        ),
        'a correction reason is asked when named (#2440)': (
          r(['correction_reason']),
          false,
          InvoiceIssueBlock.missing,
          true,
        ),
        'a typed correction reason stays shown': (
          r([], reason: 'R1'),
          true,
          InvoiceIssueBlock.none,
          true,
        ),
      };

  for (final MapEntry(key: name, value: (state, issues, block, asks))
      in table.entries) {
    test(name, () {
      expect(state.canIssue, issues);
      expect(state.block, block);
      expect(state.asksCorrectionReason, asks);
    });
  }
}
