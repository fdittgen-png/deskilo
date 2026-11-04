// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the Demo's purchase orders, in memory, by the server's rules
// (0674): numbered per year, only a draft is edited, a request id replays
// its answer, a stale revision and an unknown supplier are refused, a
// received or cancelled order is final. Nothing leaves the device.
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../features/money/domain/purchase_order.dart';
import '../../../features/money/domain/service_item.dart';
import '../../../features/money/domain/supplier.dart';

class FakePurchaseOrderRepository implements PurchaseOrderRepository {
  FakePurchaseOrderRepository({
    required this.suppliers,
    required this.services,
    required this.now,
    this.currency = 'EUR',
  });

  /// The space's suppliers and catalogue, read at each call.
  final List<Supplier> Function() suppliers;
  final List<ServiceItem> Function() services;
  final DateTime Function() now;
  final String currency;

  final List<PurchaseOrder> orders = [];
  final Map<String, PurchaseOrder> _requests = {};

  static PostgrestException _refused(String message, [String code = '22023']) =>
      PostgrestException(message: message, code: code);

  @override
  Future<List<PurchaseOrder>> fetchOrders(String workspaceId) async =>
      [...orders]..sort((a, b) => b.reference.compareTo(a.reference));

  int _index(String id) => orders.indexWhere((o) => o.id == id);

  PurchaseOrder _with(
    PurchaseOrder o, {
    PurchaseOrderState? state,
    DateTime? sentAt,
    String? sentVia,
    DateTime? cancelledAt,
    String? cancelReason,
  }) => PurchaseOrder(
    id: o.id,
    reference: o.reference,
    supplierId: o.supplierId,
    supplierName: o.supplierName,
    state: state ?? o.state,
    currency: o.currency,
    revision: o.revision + 1,
    lines: o.lines,
    expectedOn: o.expectedOn,
    note: o.note,
    recipientEmail: o.recipientEmail,
    sentAt: sentAt ?? o.sentAt,
    sentVia: sentVia ?? o.sentVia,
    cancelledAt: cancelledAt ?? o.cancelledAt,
    cancelReason: cancelReason ?? o.cancelReason,
    createdAt: o.createdAt,
  );

  @override
  Future<PurchaseOrder> save(
    String workspaceId,
    String requestId,
    PurchaseOrderDraft draft,
  ) async {
    if (_requests[requestId] case final done?) return done;
    if (draft.problems.isNotEmpty) throw _refused('invalid purchase order');
    final supplier = suppliers()
        .where((s) => s.id == draft.supplierId && s.isActive)
        .firstOrNull;
    if (supplier == null) {
      throw _refused('an order goes to an active supplier of the space');
    }
    final names = {for (final s in services()) s.id: s.name};
    final lines = [
      for (final (i, l) in draft.lines.indexed)
        PurchaseOrderLine(
          lineNo: i + 1,
          serviceId: l.serviceId,
          description: l.description.trim().isEmpty
              ? (names[l.serviceId] ?? '')
              : l.description.trim(),
          quantity: l.quantity,
          unit: l.unit.trim(),
          unitPriceCents: l.unitPriceCents,
          vatRatePercent: l.vatRatePercent,
        ),
    ];
    final PurchaseOrder saved;
    if (draft.orderId case final id?) {
      final i = _index(id);
      if (i < 0) throw _refused('unknown purchase order');
      final was = orders[i];
      if (was.state != PurchaseOrderState.draft) {
        throw _refused('only a draft purchase order is edited');
      }
      if (was.revision != draft.expectedRevision) {
        throw _refused('stale revision', '40001');
      }
      saved = PurchaseOrder(
        id: was.id,
        reference: was.reference,
        supplierId: supplier.id,
        supplierName: supplier.name,
        state: was.state,
        currency: was.currency,
        revision: was.revision + 1,
        lines: lines,
        expectedOn: draft.expectedOn,
        note: draft.note.trim(),
        recipientEmail: draft.recipientEmail.trim(),
        createdAt: was.createdAt,
      );
      orders[i] = saved;
    } else {
      final year = now().year;
      final number =
          orders.where((o) => o.reference.startsWith('$year-')).length + 1;
      saved = PurchaseOrder(
        id: 'demo-order-${orders.length + 1}',
        reference: '$year-${number.toString().padLeft(4, '0')}',
        supplierId: supplier.id,
        supplierName: supplier.name,
        state: PurchaseOrderState.draft,
        currency: currency,
        revision: 1,
        lines: lines,
        expectedOn: draft.expectedOn,
        note: draft.note.trim(),
        recipientEmail: draft.recipientEmail.trim(),
        createdAt: now(),
      );
      orders.add(saved);
    }
    return _requests[requestId] = saved;
  }

  @override
  Future<PurchaseOrder> markSent(
    String workspaceId,
    String orderId,
    int revision,
    String requestId,
  ) async {
    if (_requests[requestId] case final done?) return done;
    final i = _index(orderId);
    if (i < 0) throw _refused('unknown purchase order');
    final o = orders[i];
    if (o.state != PurchaseOrderState.draft) {
      throw _refused('only a draft purchase order is sent');
    }
    if (o.revision != revision) throw _refused('stale revision', '40001');
    return _requests[requestId] = orders[i] = _with(
      o,
      state: PurchaseOrderState.sent,
      sentAt: now(),
      sentVia: 'print',
    );
  }

  @override
  Future<PurchaseOrder> cancel(
    String workspaceId,
    String orderId,
    int revision,
    String reason,
    String requestId,
  ) async {
    if (_requests[requestId] case final done?) return done;
    if (reason.trim().isEmpty) throw _refused('a cancelled order says why');
    final i = _index(orderId);
    if (i < 0) throw _refused('unknown purchase order');
    final o = orders[i];
    if (!o.state.open || o.state == PurchaseOrderState.received) {
      throw _refused('a ${o.state.wire} purchase order is not cancelled');
    }
    if (o.revision != revision) throw _refused('stale revision', '40001');
    return _requests[requestId] = orders[i] = _with(
      o,
      state: PurchaseOrderState.cancelled,
      cancelledAt: now(),
      cancelReason: reason.trim(),
    );
  }
}
