// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase orders: the server's order read exactly, its totals
// from its lines, a draft checked before it is sent (an unsafe recipient
// refused), the Demo's in-memory rules (series, replay, stale revision,
// only a draft edited, final states), the document's data, and the screen:
// a buyer drafts, prints, marks sent and cancels; a finance reader only
// reads and prints.
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/purchase_order_report.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/supplier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const _alpha = Supplier(
  id: 'sup-1',
  number: '1',
  name: 'Alpha Supplies',
  street: '1 rue du Port',
  postalCode: '34120',
  city: 'Pézenas',
  countryCode: 'FR',
);

const _coffee = ServiceItem(
  id: 'svc-1',
  workspaceId: 'ws',
  name: 'Coffee capsules',
  priceCents: 200,
  active: true,
);

PurchaseOrderDraft _draft({
  String email = 'orders@alpha.test',
  double quantity = 100,
  String? orderId,
  int revision = 0,
}) => PurchaseOrderDraft(
  orderId: orderId,
  expectedRevision: revision,
  supplierId: 'sup-1',
  expectedOn: DateTime(2026, 12),
  recipientEmail: email,
  lines: [
    PurchaseOrderLineDraft(
      serviceId: 'svc-1',
      quantity: quantity,
      unit: 'capsule',
      unitPriceCents: 25,
      vatRatePercent: 20,
    ),
    const PurchaseOrderLineDraft(
      description: 'Paper towels',
      quantity: 12,
      unit: 'roll',
      unitPriceCents: 150,
    ),
  ],
);

FakePurchaseOrderRepository _repo() => FakePurchaseOrderRepository(
  suppliers: () => const [_alpha],
  services: () => const [_coffee],
  now: () => DateTime(2026, 11, 4),
);

void main() {
  group('the order', () {
    test('reads the server\'s order, its lines and supplier', () {
      final o = PurchaseOrder.fromJson({
        'id': 'po-1',
        'reference': '2026-0007',
        'supplier_id': 'sup-1',
        'suppliers': {'name': 'Alpha Supplies'},
        'state': 'partly_received',
        'currency': 'EUR',
        'revision': 3,
        'expected_on': '2026-12-01',
        'purchase_order_lines': [
          {
            'line_no': 2,
            'description': 'Towels',
            'quantity': 12,
            'unit_price_cents': 150,
          },
          {
            'line_no': 1,
            'service_id': 'svc-1',
            'description': 'Coffee',
            'quantity': 100,
            'unit': 'capsule',
            'unit_price_cents': 25,
            'vat_rate_percent': 20,
            'received_quantity': 40,
          },
        ],
      });
      expect(
        (o.reference, o.supplierName, o.state),
        ('2026-0007', 'Alpha Supplies', PurchaseOrderState.partlyReceived),
      );
      expect(o.lines.map((l) => l.lineNo), [1, 2]);
      expect(o.lines.first.receivedQuantity, 40);
      expect((o.netCents, o.vatCents, o.totalCents), (4300, 500, 4800));
    });

    test(
      'a draft is checked before it is sent; an unsafe recipient is refused',
      () {
        expect(_draft().problems, isEmpty);
        expect(_draft(quantity: 0).problems, {
          PurchaseOrderProblem.lineQuantity,
        });
        expect(_draft(email: 'orders@alpha.test\nBcc: x@y.z').problems, {
          PurchaseOrderProblem.recipientEmail,
        });
        expect(
          _draft(email: '').problems,
          isEmpty,
          reason: 'a printed order needs no recipient',
        );
        expect(const PurchaseOrderDraft(supplierId: null, lines: []).problems, {
          PurchaseOrderProblem.noSupplier,
          PurchaseOrderProblem.noLines,
        });
        expect(isOrderEmail('a@b.co'), isTrue);
        expect(isOrderEmail('a b@c.d'), isFalse);
      },
    );

    test('the payload is what save_purchase_order_v1 reads', () {
      final p = _draft().toPayload();
      expect(p['supplier_id'], 'sup-1');
      expect(p['expected_on'], '2026-12-01');
      expect((p['lines']! as List).first, {
        'service_id': 'svc-1',
        'description': '',
        'quantity': 100.0,
        'unit': 'capsule',
        'unit_price_cents': 25,
        'vat_rate_percent': 20.0,
      });
    });
  });

  group('the Demo keeps the server\'s rules', () {
    test(
      'numbered per year, a request replays, an item names its line',
      () async {
        final repo = _repo();
        final first = await repo.save('ws', 'r1', _draft());
        expect(first.reference, '2026-0001');
        expect(first.lines.first.description, 'Coffee capsules');
        expect((await repo.save('ws', 'r1', _draft())).id, first.id);
        expect((await repo.save('ws', 'r2', _draft())).reference, '2026-0002');
      },
    );

    test(
      'only a draft at its revision is edited; sent, then cancelled, is final',
      () async {
        final repo = _repo();
        final o = await repo.save('ws', 'r1', _draft());
        await expectLater(
          repo.save('ws', 'r2', _draft(orderId: o.id, revision: 9)),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '40001'),
          ),
        );
        final sent = await repo.markSent('ws', o.id, o.revision, 'r3');
        expect((sent.state, sent.sentVia), (PurchaseOrderState.sent, 'print'));
        await expectLater(
          repo.save('ws', 'r4', _draft(orderId: o.id, revision: sent.revision)),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          repo.cancel('ws', o.id, sent.revision, ' ', 'r5'),
          throwsA(isA<PostgrestException>()),
        );
        final cancelled = await repo.cancel(
          'ws',
          o.id,
          sent.revision,
          'ordered twice',
          'r6',
        );
        expect(cancelled.state, PurchaseOrderState.cancelled);
        await expectLater(
          repo.markSent('ws', o.id, cancelled.revision, 'r7'),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    test('an unknown supplier is refused', () async {
      await expectLater(
        _repo().save(
          'ws',
          'r1',
          const PurchaseOrderDraft(
            supplierId: 'nobody',
            lines: [
              PurchaseOrderLineDraft(
                description: 'x',
                quantity: 1,
                unitPriceCents: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  test(
    'the document prints the supplier in the window, the lines and totals',
    () async {
      final o = await _repo().save('ws', 'r1', _draft());
      final data = purchaseOrderReportData(
        o,
        supplier: _alpha,
        money: (minor) => '€${(minor / 100).toStringAsFixed(2)}',
        date: (d) => '${d.day}/${d.month}/${d.year}',
        quantity: (q) => q.toStringAsFixed(0),
        issued: DateTime(2026, 11, 4),
        issuedBy: 'Atelier',
        letterhead: const {'workspace': 'Atelier'},
      );
      expect(data['workspace'], 'Atelier');
      expect(data['number'], '2026-0001');
      expect(data['client_name'], 'Alpha Supplies');
      expect(data['client_address'], '1 rue du Port\n34120 Pézenas\nFR');
      expect(data['expected_on'], '1/12/2026');
      expect((data['lines']! as List).first, {
        'label': 'Coffee capsules (capsule)',
        'qty': '100',
        'unit_price': '€0.25',
        'amount': '€25.00',
      });
      expect(
        (data['net_total'], data['vat_total'], data['has_vat'], data['total']),
        ('€43.00', '€5.00', true, '€48.00'),
      );
    },
  );
}
