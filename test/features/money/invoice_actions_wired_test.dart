// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1217 — "None of the buttons actually works."
//
// `InvoiceDetailSheet`'s buttons never acted; they popped an
// `InvoiceAction` and left the CALLER to run it. Six surfaces opened
// that sheet and three of them awaited the future and threw the result
// away, so Download PDF, Quick view, Share PDF and E-invoice were inert
// on the member's own Invoices tab, on an invoice opened from the
// agenda, and on one opened from a message reference — while the same
// buttons worked from the three admin lists.
//
// The trace proved it by its silence: every user action goes through
// `runGuarded`, which logs a start even when the action fails (#1012),
// and there was no line at all.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../lint/lint_sources.dart';

void main() {
  test('the sheet returns nothing a caller could drop', () {
    final src = File(
      'lib/features/money/presentation/widgets/invoice_detail_sheet.dart',
    ).readAsStringSync();

    expect(
      src,
      contains('Future<void> showInvoiceDetailSheet('),
      reason: 'a returned value the compiler lets you discard WAS the bug. '
          'The sheet dispatches its own action now, so there is nothing '
          'to forget to use.',
    );
    expect(
      src,
      contains('await runInvoiceAction('),
      reason: 'and it dispatches it here, once',
    );
  });

  test('no caller opens the sheet without a ref to act through', () {
    final offenders = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      final src = file.readAsStringSync();
      var from = 0;
      while (true) {
        final at = src.indexOf('showInvoiceDetailSheet(', from);
        if (at < 0) break;
        from = at + 1;
        // Its own declaration, not a call.
        if (src.startsWith('Future<void> showInvoiceDetailSheet(',
            at - 'Future<void> '.length)) {
          continue;
        }
        // The arguments run to the matching close paren; `ref:` must be
        // among them or the sheet has no way to run what it is asked.
        final args = src.substring(at, (at + 600).clamp(0, src.length));
        if (!args.contains('ref: ')) offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'these open the invoice sheet without handing it a ref, so '
            'its buttons would pop an action nothing can run');
  });
}
