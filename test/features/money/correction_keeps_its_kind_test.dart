// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3994 — the Demo issues a correction of the kind of the invoice it
// replaces, as the server does (0786): a month with a subscription and a
// usage invoice can have its usage invoice corrected; a correction of
// another kind is refused (DKI08).
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<({FakeMoneyRepository money, String subscription, String usage})>
  twoInvoices() async {
    final money = FakeMoneyRepository();
    final subscription = await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: '2026-09',
      kind: InvoiceKind.subscription,
    );
    final usage = await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: '2026-09',
      kind: InvoiceKind.usage,
    );
    return (money: money, subscription: subscription, usage: usage);
  }

  test(
    'a correction sent as a full invoice is of the kind it replaces',
    () async {
      final (:money, :subscription, :usage) = await twoInvoices();
      final id = await money.createInvoice(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: '2026-09',
        replacesId: usage,
      );
      expect(
        money.invoices.firstWhere((i) => i.id == id).kind,
        InvoiceKind.usage,
      );
      expect(
        money.invoices.firstWhere((i) => i.id == subscription).isVoided,
        isFalse,
        reason: 'the month\'s other invoice stands',
      );
    },
  );

  test('a correction of another kind is refused', () async {
    final (:money, :subscription, :usage) = await twoInvoices();
    await expectLater(
      money.createInvoice(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: '2026-09',
        replacesId: subscription,
        kind: InvoiceKind.usage,
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', DkCode.dki08)),
    );
    expect(usage, isNotEmpty);
  });
}
