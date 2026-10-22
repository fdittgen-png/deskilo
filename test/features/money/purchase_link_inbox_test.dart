// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2573 — a received supplier invoice becomes the evidence of a purchase:
// the inbox offers what is neither rejected nor already linked, and the pick
// is sent once with the document's revision.
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/features/money/domain/einvoice_inbox.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/widgets/purchase_link_inbox.dart';
import 'package:deskilo/features/money/providers/einvoice_inbox_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _Purchases extends FakePurchaseRepository {
  final linked = <(String, int, String)>[];

  @override
  Future<void> linkInboxDocument(
    String workspaceId,
    String purchaseId, {
    required int revision,
    required String documentId,
    required String requestId,
  }) async => linked.add((purchaseId, revision, documentId));
}

InboxDocument _doc(String id, InboxStatus status) => InboxDocument(
  id: id,
  number: 'F-$id',
  issueDate: '2026-03-10',
  currency: 'EUR',
  supplierName: 'Nettoyage SA',
  grossCents: 120,
  status: status,
);

const _detail = PurchaseDetail(
  summary: PurchaseSummary(
    id: 'p-1',
    kind: PurchaseKind.bill,
    state: PurchaseState.draft,
    category: '',
    reference: 'F-1',
    currency: 'EUR',
  ),
  revision: 3,
  lines: [],
  sources: [PurchaseSource(kind: 'inbox', id: 'linked', role: 'evidence')],
);

void main() {
  testWidgets('offers the received invoices still to link, and links the '
      'one picked with the document\'s revision', (tester) async {
    final purchases = _Purchases();
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          key: const ValueKey('open'),
          onPressed: () => showLinkInboxDialog(context, 'ws-1', _detail),
          child: const Text('open'),
        ),
      ),
      overrides: [
        purchaseRepositoryProvider.overrideWithValue(purchases),
        eInvoiceInboxProvider('ws-1').overrideWith(
          (ref) async => [
            _doc('fresh', InboxStatus.received),
            _doc('linked', InboxStatus.matched),
            _doc('refused', InboxStatus.rejected),
          ],
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-link-inbox-fresh')), findsOne);
    expect(
      find.byKey(const ValueKey('purchase-link-inbox-linked')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('purchase-link-inbox-refused')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('purchase-link-inbox-fresh')));
    await tester.pumpAndSettle();
    expect(purchases.linked, [('p-1', 3, 'fresh')]);
    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'closed once linked',
    );
  });
}
