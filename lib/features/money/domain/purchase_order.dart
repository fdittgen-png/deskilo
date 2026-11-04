// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the space's purchase orders to its suppliers: a document of its
// own, separate from the bill that arrives later. The server numbers it,
// holds its state and decides who may write it
// (`save_purchase_order_v1`, 0674); this layer reads it and checks a draft
// before it is sent.
//
// Pure Dart: no Flutter, no l10n.
library;

import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';

/// Where an order stands. Only a draft is edited; received and cancelled
/// are final.
enum PurchaseOrderState {
  draft('draft'),
  sent('sent'),
  partlyReceived('partly_received'),
  received('received'),
  cancelled('cancelled');

  const PurchaseOrderState(this.wire);
  final String wire;

  static PurchaseOrderState of(String wire) =>
      values.firstWhere((s) => s.wire == wire, orElse: () => draft);

  /// Still open: sent, partly received, or a draft.
  bool get open => this != received && this != cancelled;
}

/// One line: a catalogue item or free text, how many, in what unit, at what
/// unit price (minor units, before VAT) and VAT rate.
class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.lineNo,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    this.serviceId,
    this.unit = '',
    this.vatRatePercent,
    this.receivedQuantity = 0,
  });

  factory PurchaseOrderLine.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase order line');
    return PurchaseOrderLine(
      lineNo: r.integer('line_no'),
      serviceId: r.stringOrNull('service_id'),
      description: r.stringOr('description'),
      quantity: r.doubleOrNull('quantity') ?? 0,
      unit: r.stringOr('unit'),
      unitPriceCents: r.integer('unit_price_cents'),
      vatRatePercent: r.doubleOrNull('vat_rate_percent'),
      receivedQuantity: r.doubleOrNull('received_quantity') ?? 0,
    );
  }

  final int lineNo;
  final String? serviceId;
  final String description;
  final double quantity;
  final String unit;
  final int unitPriceCents;

  /// Null when the order does not state it.
  final double? vatRatePercent;
  final double receivedQuantity;

  /// The line before VAT, rounded to the minor unit.
  int get netCents => (quantity * unitPriceCents).round();

  /// Its VAT at the stated rate; 0 when none is stated.
  int get vatCents => ((netCents * (vatRatePercent ?? 0)) / 100).round();
}

/// One order as the server holds it.
class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.reference,
    required this.supplierId,
    required this.supplierName,
    required this.state,
    required this.currency,
    required this.revision,
    required this.lines,
    this.expectedOn,
    this.note = '',
    this.recipientEmail = '',
    this.sentAt,
    this.sentVia,
    this.cancelledAt,
    this.cancelReason = '',
    this.createdAt,
  });

  /// Reads `purchase_order_json` (0674) and a table row with its lines and
  /// supplier embedded.
  factory PurchaseOrder.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase order');
    final supplier = r.objectOrNull('suppliers');
    final lines = [
      for (final key in const ['lines', 'purchase_order_lines'])
        for (final l in r.listOrAbsent(key)) PurchaseOrderLine.fromJson(l),
    ]..sort((a, b) => a.lineNo.compareTo(b.lineNo));
    return PurchaseOrder(
      id: r.string('id'),
      reference: r.stringOr('reference'),
      supplierId: r.string('supplier_id'),
      supplierName:
          r.stringOrNull('supplier_name') ?? supplier?.stringOr('name') ?? '',
      state: PurchaseOrderState.of(r.stringOr('state', 'draft')),
      currency: r.stringOr('currency'),
      revision: r.integer('revision'),
      lines: lines,
      expectedOn: DateTime.tryParse(r.stringOr('expected_on')),
      note: r.stringOr('note'),
      recipientEmail: r.stringOr('recipient_email'),
      sentAt: DateTime.tryParse(r.stringOr('sent_at')),
      sentVia: r.stringOrNull('sent_via'),
      cancelledAt: DateTime.tryParse(r.stringOr('cancelled_at')),
      cancelReason: r.stringOr('cancel_reason'),
      createdAt: DateTime.tryParse(
        r.stringOrNull('created_at') ?? r.stringOr('created_datetime'),
      ),
    );
  }

  final String id;

  /// The order's number in its series, `YYYY-NNNN`.
  final String reference;
  final String supplierId;
  final String supplierName;
  final PurchaseOrderState state;
  final String currency;
  final int revision;
  final List<PurchaseOrderLine> lines;
  final DateTime? expectedOn;
  final String note;

  /// Where the order is e-mailed; '' when it is only printed.
  final String recipientEmail;
  final DateTime? sentAt;

  /// `print` or `email` once sent.
  final String? sentVia;
  final DateTime? cancelledAt;
  final String cancelReason;
  final DateTime? createdAt;

  int get netCents => lines.fold(0, (s, l) => s + l.netCents);
  int get vatCents => lines.fold(0, (s, l) => s + l.vatCents);
  int get totalCents => netCents + vatCents;

  /// A draft whose recipient is an address it can be e-mailed to.
  bool get emailable =>
      state == PurchaseOrderState.draft && _isOrderEmail(recipientEmail);
}

/// An address an order may be e-mailed to: one address, no line breaks.
bool _isOrderEmail(String value) {
  final v = value.trim();
  return v.length <= 254 &&
      !value.contains(RegExp(r'[\r\n]')) &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
}

/// One line of a draft.
class PurchaseOrderLineDraft {
  const PurchaseOrderLineDraft({
    required this.quantity,
    required this.unitPriceCents,
    this.serviceId,
    this.description = '',
    this.unit = '',
    this.vatRatePercent,
  });

  final String? serviceId;
  final String description;
  final double quantity;
  final String unit;
  final int unitPriceCents;
  final double? vatRatePercent;

  Map<String, Object?> toJson() => {
    'service_id': ?serviceId,
    'description': description.trim(),
    'quantity': quantity,
    'unit': unit.trim(),
    'unit_price_cents': unitPriceCents,
    'vat_rate_percent': ?vatRatePercent,
  };
}

/// Why a draft cannot be saved; the form shows each under its field.
enum PurchaseOrderProblem {
  noSupplier,
  noLines,
  lineDescription,
  lineQuantity,
  linePrice,
  lineVatRate,
  recipientEmail,
}

/// What the order form collects; saved by `save_purchase_order_v1`.
class PurchaseOrderDraft {
  const PurchaseOrderDraft({
    required this.supplierId,
    required this.lines,
    this.orderId,
    this.expectedRevision = 0,
    this.expectedOn,
    this.note = '',
    this.recipientEmail = '',
  });

  final String? orderId;
  final int expectedRevision;
  final String? supplierId;
  final List<PurchaseOrderLineDraft> lines;
  final DateTime? expectedOn;
  final String note;
  final String recipientEmail;

  /// What the server would refuse, checked first so the form can say it
  /// under the field.
  Set<PurchaseOrderProblem> get problems => {
    if (supplierId == null || supplierId!.isEmpty)
      PurchaseOrderProblem.noSupplier,
    if (lines.isEmpty || lines.length > 200) PurchaseOrderProblem.noLines,
    for (final l in lines) ...{
      if (l.serviceId == null && l.description.trim().isEmpty)
        PurchaseOrderProblem.lineDescription,
      if (l.quantity <= 0 || l.quantity > 1000000)
        PurchaseOrderProblem.lineQuantity,
      if (l.unitPriceCents < 0) PurchaseOrderProblem.linePrice,
      if (l.vatRatePercent case final r? when r < 0 || r >= 100)
        PurchaseOrderProblem.lineVatRate,
    },
    if (recipientEmail.trim().isNotEmpty && !_isOrderEmail(recipientEmail))
      PurchaseOrderProblem.recipientEmail,
  };

  Map<String, Object?> toPayload() => {
    'order_id': ?orderId,
    'supplier_id': supplierId,
    'expected_on': switch (expectedOn) {
      final d? => isoDay(d),
      null => null,
    },
    'note': note.trim(),
    'recipient_email': recipientEmail.trim(),
    'lines': [for (final l in lines) l.toJson()],
  };
}

/// Reads and writes the space's purchase orders. Every call is authorized
/// on the server.
abstract interface class PurchaseOrderRepository {
  /// The space's orders, the latest first.
  Future<List<PurchaseOrder>> fetchOrders(String workspaceId);

  /// Creates or edits a draft; the same [requestId] replays its answer.
  Future<PurchaseOrder> save(
    String workspaceId,
    String requestId,
    PurchaseOrderDraft draft,
  );

  /// A printed draft handed to its supplier is sent.
  Future<PurchaseOrder> markSent(
    String workspaceId,
    String orderId,
    int revision,
    String requestId,
  );

  /// Cancels an order that is not received, with [reason].
  Future<PurchaseOrder> cancel(
    String workspaceId,
    String orderId,
    int revision,
    String reason,
    String requestId,
  );
}
