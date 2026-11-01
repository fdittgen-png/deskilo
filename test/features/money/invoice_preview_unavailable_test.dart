// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A preview that could not be read or decoded is UNAVAILABLE in the issue
// form: it never reads as an empty month or a total of 0, and nothing can be
// issued from it. The decoder's own refusals are pinned in
// invoice_preview_decoding_test.dart; this is the screen that shows them.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/screens/invoices.dart';

/// The server's answer to `preview_invoice` does not decode.
class _MalformedPreview extends FakeMoneyRepository {
  @override
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  }) async => throw const JsonShapeException(
    'preview_invoice',
    'total_cents',
    'whole number',
    'null',
  );
}

void main() {
  testWidgets('a malformed preview is unavailable: no empty month, no total, '
      'and Issue stays disabled', (tester) async {
    final money = _MalformedPreview();
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-member-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('invoice-preview-unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('invoice-preview-empty')),
      findsNothing,
      reason: 'a failed read is not an empty month',
    );
    expect(
      find.byKey(const ValueKey('invoice-preview-total')),
      findsNothing,
      reason: 'a failed read is not a total of 0',
    );
    final submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('invoice-submit')),
    );
    expect(submit.onPressed, isNull);
    expect(money.invoices, isEmpty);
  });
}
