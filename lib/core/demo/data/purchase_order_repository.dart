// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the Demo's purchase orders, in memory, by the server's rules
// (0681): numbered per year, only a draft is edited, a request id replays
// its answer, a stale revision and an unknown supplier are refused, a
// received or cancelled order is final. Nothing leaves the device: an
// e-mail is simulated (0683's rules — the mail configured, a draft naming
// its recipient, one attempt that may have left, the same attempt id
// replayed) and recorded as accepted, the order sent by e-mail; an order
// whose e-mail may be on its way is frozen. A delivery
// follows 0684: only a sent or partly received order at its revision, no
// line beyond what was ordered, never dated after today.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../features/money/domain/purchase_order.dart';
import '../../../features/money/domain/purchase_order_receipt.dart';
import '../../../features/money/domain/service_item.dart';

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
  final List<PurchaseOrderSend> sends = [];
  final List<PurchaseOrderReceipt> receipts = [];

  /// The order each draft bill names (#3307), by the bill's id.
  final Map<String, String> billOrders = {};

  /// How the Demo space e-mails its orders; null until configured. The
  /// Demo keeps no key: it only knows one was given.
  PurchaseOrderMailSettings? mail;
  final Map<String, PurchaseOrder> _requests = {};

  static PostgrestException _refused(String message, [String code = '22023']) =>
      PostgrestException(message: message, code: code);

  @override
  Future<List<PurchaseOrder>> fetchOrders(String workspaceId) async =>
      [...orders]..sort((a, b) => b.reference.compareTo(a.reference));

  int _index(String id) => orders.indexWhere((o) => o.id == id);

  /// 0681: an order whose e-mail may be on its way is not edited, marked
  /// sent or cancelled.
  void _noSendInFlight(String orderId) {
    if (sends.any(
      (s) =>
          s.orderId == orderId &&
          (s.state == PurchaseOrderSendState.pending ||
              s.state == PurchaseOrderSendState.unconfirmed),
    )) {
      throw _refused('an e-mail of this order may be on its way', '55000');
    }
  }

  PurchaseOrder _with(
    PurchaseOrder o, {
    PurchaseOrderState? state,
    ({DateTime at, String via})? sent,
    DateTime? cancelledAt,
    String? cancelReason,
    List<PurchaseOrderLine>? lines,
  }) => PurchaseOrder(
    id: o.id,
    reference: o.reference,
    supplierId: o.supplierId,
    supplierName: o.supplierName,
    state: state ?? o.state,
    currency: o.currency,
    revision: o.revision + 1,
    lines: lines ?? o.lines,
    expectedOn: o.expectedOn,
    note: o.note,
    recipientEmail: o.recipientEmail,
    sentAt: sent?.at ?? o.sentAt,
    sentVia: sent?.via ?? o.sentVia,
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
      _noSendInFlight(was.id);
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
    _noSendInFlight(o.id);
    return _requests[requestId] = orders[i] = _with(
      o,
      state: PurchaseOrderState.sent,
      sent: (at: now(), via: 'print'),
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
    _noSendInFlight(o.id);
    return _requests[requestId] = orders[i] = _with(
      o,
      state: PurchaseOrderState.cancelled,
      cancelledAt: now(),
      cancelReason: reason.trim(),
    );
  }

  @override
  Future<List<PurchaseOrderSend>> fetchSends(String workspaceId) async =>
      sends.reversed.toList();

  @override
  Future<PurchaseOrderMailSettings?> fetchMailSettings(
    String workspaceId,
  ) async => mail;

  @override
  Future<PurchaseOrderMailSettings> saveMailSettings(
    String workspaceId,
    PurchaseOrderMailDraft draft,
  ) async {
    if (!draft.validFor(mail)) throw _refused('invalid mail settings');
    if (mail != null && mail!.revision != draft.revision) {
      throw _refused('stale revision', '40001');
    }
    return mail = PurchaseOrderMailSettings(
      senderEmail: draft.senderEmail.trim(),
      senderName: draft.senderName.trim(),
      hasApiKey: true,
      revision: (mail?.revision ?? 0) + 1,
    );
  }

  @override
  Future<PurchaseOrderSend> sendByEmail(
    String workspaceId,
    PurchaseOrder order,
    String attemptId,
    PurchaseOrderMail mail,
  ) async {
    if (sends.where((s) => s.id == attemptId).firstOrNull case final done?) {
      return done;
    }
    final i = _index(order.id);
    if (i < 0) throw _refused('unknown purchase order');
    final o = orders[i];
    if (o.state != PurchaseOrderState.draft) {
      throw _refused('only a draft purchase order is sent');
    }
    if (o.revision != order.revision) throw _refused('stale revision', '40001');
    if (!o.emailable) {
      throw _refused('the order names no address to e-mail it to');
    }
    if (this.mail?.hasApiKey != true) {
      throw _refused('this space has not configured how it e-mails its orders');
    }
    if (sends.any(
      (s) =>
          s.orderId == o.id &&
          (s.awaitsDecision || s.state == PurchaseOrderSendState.pending),
    )) {
      throw _refused(
        'an earlier send of this order has no confirmed outcome',
        '55000',
      );
    }
    final send = PurchaseOrderSend(
      id: attemptId,
      orderId: o.id,
      state: PurchaseOrderSendState.accepted,
      recipient: o.recipientEmail.trim(),
      providerId: 'demo-$attemptId',
      createdAt: now(),
    );
    sends.add(send);
    orders[i] = _with(
      o,
      state: PurchaseOrderState.sent,
      sent: (at: now(), via: 'email'),
    );
    return send;
  }

  @override
  Future<PurchaseOrderSend> resolveSend(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) async {
    final i = sends.indexWhere((s) => s.id == attemptId);
    if (i < 0) throw _refused('unknown send attempt');
    final s = sends[i];
    if (!s.awaitsDecision) {
      throw _refused('only an unconfirmed send is decided by hand');
    }
    final resolved = PurchaseOrderSend(
      id: s.id,
      orderId: s.orderId,
      state: delivered
          ? PurchaseOrderSendState.delivered
          : PurchaseOrderSendState.notDelivered,
      recipient: s.recipient,
      createdAt: s.createdAt,
    );
    sends[i] = resolved;
    final o = _index(s.orderId);
    if (delivered && o >= 0 && orders[o].state == PurchaseOrderState.draft) {
      orders[o] = _with(
        orders[o],
        state: PurchaseOrderState.sent,
        sent: (at: now(), via: 'email'),
      );
    }
    return resolved;
  }

  @override
  Future<List<PurchaseOrderReceipt>> fetchReceipts(String workspaceId) async =>
      [...receipts]..sort((a, b) => b.receivedOn.compareTo(a.receivedOn));

  @override
  Future<PurchaseOrder> recordReceipt(
    String workspaceId,
    String requestId,
    PurchaseOrderReceiptDraft draft,
  ) async {
    if (_requests[requestId] case final done?) return done;
    final i = _index(draft.order.id);
    if (i < 0) throw _refused('unknown purchase order');
    final o = orders[i];
    final problems = PurchaseOrderReceiptDraft(
      order: o,
      receivedOn: draft.receivedOn,
      quantities: draft.quantities,
      note: draft.note,
    ).problemsOn(now());
    if (problems.contains(PurchaseOrderReceiptProblem.notReceivable)) {
      throw _refused('only a sent order receives its goods');
    }
    if (o.revision != draft.order.revision) {
      throw _refused('stale revision', '40001');
    }
    if (problems.isNotEmpty) throw _refused('invalid delivery');
    final lines = [
      for (final l in o.lines)
        PurchaseOrderLine(
          lineNo: l.lineNo,
          serviceId: l.serviceId,
          description: l.description,
          quantity: l.quantity,
          unit: l.unit,
          unitPriceCents: l.unitPriceCents,
          vatRatePercent: l.vatRatePercent,
          receivedQuantity:
              l.receivedQuantity +
              (draft.quantities[l.lineNo] ?? 0).clamp(0, l.remaining),
        ),
    ];
    receipts.add(
      PurchaseOrderReceipt(
        id: 'demo-receipt-${receipts.length + 1}',
        orderId: o.id,
        receivedOn: DateTime.parse(isoDay(draft.receivedOn)),
        note: draft.note.trim(),
        lines: {
          for (final e in draft.toLines())
            e['line_no']! as int: e['quantity']! as double,
        },
      ),
    );
    final complete = lines.every((l) => l.receivedQuantity >= l.quantity);
    return _requests[requestId] = orders[i] = _with(
      o,
      lines: lines,
      state: complete
          ? PurchaseOrderState.received
          : PurchaseOrderState.partlyReceived,
    );
  }

  @override
  Future<void> linkBill(
    String workspaceId,
    String purchaseId,
    String? orderId,
  ) async {
    if (orderId == null) {
      billOrders.remove(purchaseId);
      return;
    }
    final i = _index(orderId);
    if (i < 0) throw _refused('unknown purchase order');
    final state = orders[i].state;
    if (state == PurchaseOrderState.draft ||
        state == PurchaseOrderState.cancelled) {
      throw _refused('a bill charges an order that was sent');
    }
    billOrders[purchaseId] = orderId;
  }
}
