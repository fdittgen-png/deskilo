// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Offsetting a member's claim against one of their open invoices: which
// invoices are offered, what the command refuses before sending, and the
// dialog from the To-pay row to the claim that fell.
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/features/money/application/purchase_commands.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/widgets/purchase_offset_dialog.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, List<Override> overrides) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: body)),
  ),
);

Invoice _invoice(String id, String member, int cents, {DateTime? voided}) =>
    Invoice(
      id: id,
      workspaceId: 'ws',
      memberId: member,
      number: 'F-$id',
      issuedAt: DateTime(2026, 9, 28),
      title: id,
      lines: [InvoiceLine(label: id, amountCents: cents)],
      totalCents: cents,
      currency: 'EUR',
      memberName: 'Alex',
      memberAddress: '',
      workspaceName: 'W',
      workspaceAddress: '',
      issuerName: 'I',
      signature: 's',
      voidedAt: voided,
    );

PayableRow _claim() => PayableRow.fromJson({
  'obligation': {
    'id': 'o1',
    'purchase_id': 'p1',
    'creditor_kind': 'member',
    'creditor_id': 'm1',
    'amount_cents': 12000,
    'currency': 'EUR',
    'state': 'open',
    'revision': 1,
    'paid_cents': 0,
    'mine': false,
    'allocations': <Object?>[],
    'applied_cents': 0,
    'remaining_cents': 12000,
    'applied_invoice': null,
  },
  'purchase': {
    'kind': 'member_receipt',
    'state': 'approved',
    'category': 'cleaning',
    'original_reference': '',
    'received_on': '2026-10-17',
    'legacy': false,
  },
});

void main() {
  test('the permission the money screen asks for is the catalogue\'s', () {
    expect(
      purchaseOffsetPermission,
      WorkspacePermission.issueInvoices.wireName,
    );
  });

  test(
    'only the claimant\'s open invoices are offered, with what they owe',
    () {
      final invoices = [
        _invoice('a', 'm1', 4500),
        _invoice('b', 'm1', 3500),
        _invoice('c', 'm1', 3500),
        _invoice('d', 'm1', 3500, voided: DateTime(2026, 10)),
        _invoice('e', 'm2', 3500),
        _invoice('f', 'm1', -1500),
      ];
      final matches = {
        'a': InvoiceMatch(
          invoiceId: 'a',
          paidCents: 4500,
          resolution: 'exact',
          matchedAt: DateTime(2026, 10),
        ),
        'b': InvoiceMatch(
          invoiceId: 'b',
          paidCents: 1000,
          resolution: 'under_accepted',
          matchedAt: DateTime(2026, 10),
        ),
      };
      final open = openInvoicesOf('m1', invoices, matches);
      expect(open.map((o) => o.invoice.id), ['b', 'c']);
      expect(open.map((o) => o.dueCents), [2500, 3500]);
    },
  );

  test('the command sends nothing for an offset that cannot be', () async {
    final repo = FakePurchaseRepository()..payables.add(_claim());
    final commands = PurchaseCommands(repo);
    final claim = repo.payables.single.obligation;
    Future<PurchaseObligation?> go(int cents, int due) => commands.offset(
      'ws',
      claim,
      invoiceId: 'i1',
      invoiceDueCents: due,
      amountCents: cents,
      requestId: 'r$cents',
    );
    expect(await go(0, 3500), isNull);
    expect(await go(3501, 3500), isNull, reason: 'more than the invoice owes');
    expect(await go(12001, 99999), isNull, reason: 'more than the claim has');
    expect(repo.payables.single.obligation.paidCents, 0);
    final done = await go(3500, 3500);
    expect(done?.paidCents, 3500);
    expect(done?.remainingCents, 8500);
    expect(done?.allocations.single.isOffset, isTrue);
    expect(done?.allocations.single.reversible, isFalse);
  });

  testWidgets('the offset button follows the permissions; the dialog settles', (
    tester,
  ) async {
    final repo = FakePurchaseRepository()..payables.add(_claim());
    Future<void> open({required bool canOffset}) async {
      await tester.pumpWidget(
        _app(
          PurchasesView(
            workspaceId: 'ws',
            canCapture: false,
            canPay: true,
            canOffset: canOffset,
          ),
          [
            purchaseRepositoryProvider.overrideWithValue(repo),
            memberLabelsProvider.overrideWithValue({'m1': 'Alex'}),
            invoicesProvider.overrideWith(
              (ref) async => [_invoice('a', 'm1', 4500)],
            ),
            invoiceMatchesProvider.overrideWith((ref) async => {}),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('To pay'));
      await tester.pumpAndSettle();
    }

    await open(canOffset: false);
    expect(find.byKey(const ValueKey('payable-offset-o1')), findsNothing);

    await open(canOffset: true);
    await tester.tap(find.byKey(const ValueKey('payable-offset-o1')));
    await tester.pumpAndSettle();
    // Nothing chosen: nothing sent.
    await tester.tap(find.byKey(const ValueKey('offset-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('offset-invalid')), findsOneWidget);
    expect(repo.payables.single.obligation.paidCents, 0);

    await tester.tap(find.byKey(const ValueKey('offset-invoice')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('F-a').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('offset-save')));
    await tester.pumpAndSettle();
    final claim = repo.payables.single.obligation;
    expect(claim.paidCents, 4500);
    expect(claim.remainingCents, 7500);
    expect(claim.allocations.single.isOffset, isTrue);
  });
}
