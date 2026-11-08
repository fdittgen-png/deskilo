// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the space's purchase orders to its suppliers: a document of its
// own, separate from the bill that arrives later. The server numbers it,
// holds its state and decides who may write it
// (`save_purchase_order_v1`, 0681); this layer reads it and checks a draft
// before it is sent.
//
// Pure Dart: no Flutter, no l10n.
library;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'purchase_order_receipt.dart';

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

  /// Reads `purchase_order_json` (0681) and a table row with its lines and
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

/// An address an order may be e-mailed to: one address, no line breaks,
/// nothing a mail header reads as a name or a list (0681, 0683).
bool _isOrderEmail(String value) {
  final v = value.trim();
  return v.length <= 254 &&
      !value.contains(RegExp(r'[\r\n]')) &&
      RegExp(
        r'^[^\s@<>",;()\[\]\\]+@[^\s@<>",;()\[\]\\]+\.[^\s@<>",;()\[\]\\]+$',
      ).hasMatch(v);
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

/// Where one e-mail attempt of an order stands. `unconfirmed` is nobody
/// knowing whether it left (a timeout): a person decides it, delivered or
/// not delivered; it is never sent again on its own.
enum PurchaseOrderSendState {
  pending('pending'),
  accepted('accepted'),
  refused('refused'),
  unconfirmed('unconfirmed'),
  delivered('delivered'),
  notDelivered('not_delivered');

  const PurchaseOrderSendState(this.wire);
  final String wire;

  static PurchaseOrderSendState of(String wire) =>
      values.firstWhere((s) => s.wire == wire, orElse: () => pending);
}

/// One e-mail attempt of an order (`purchase_order_sends`, 0683).
class PurchaseOrderSend {
  const PurchaseOrderSend({
    required this.id,
    required this.orderId,
    required this.state,
    required this.recipient,
    this.providerId = '',
    this.reason = '',
    this.createdAt,
  });

  factory PurchaseOrderSend.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase order send');
    return PurchaseOrderSend(
      id: r.string('id'),
      orderId: r.string('order_id'),
      state: PurchaseOrderSendState.of(r.stringOr('state', 'pending')),
      recipient: r.stringOr('recipient'),
      providerId: r.stringOr('provider_id'),
      reason: r.stringOr('reason'),
      createdAt: DateTime.tryParse(
        r.stringOrNull('created_at') ?? r.stringOr('created_datetime'),
      ),
    );
  }

  final String id;
  final String orderId;
  final PurchaseOrderSendState state;
  final String recipient;
  final String providerId;
  final String reason;
  final DateTime? createdAt;

  /// Nobody knows whether it left: a person decides.
  bool get awaitsDecision => state == PurchaseOrderSendState.unconfirmed;
}

/// How the space e-mails its orders: the sender, and whether a key is
/// stored. The key itself never reaches the app.
class PurchaseOrderMailSettings {
  const PurchaseOrderMailSettings({
    required this.senderEmail,
    required this.hasApiKey,
    required this.revision,
    this.senderName = '',
  });

  factory PurchaseOrderMailSettings.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase order mail settings');
    return PurchaseOrderMailSettings(
      senderEmail: r.stringOr('sender_email'),
      senderName: r.stringOr('sender_name'),
      hasApiKey: r.isTrue('has_api_key'),
      revision: r.integer('revision'),
    );
  }

  final String senderEmail;
  final String senderName;
  final bool hasApiKey;
  final int revision;
}

/// What the mail settings form sends; an empty [apiKey] keeps the stored
/// one.
class PurchaseOrderMailDraft {
  const PurchaseOrderMailDraft({
    required this.senderEmail,
    this.senderName = '',
    this.apiKey = '',
    this.revision = 0,
  });

  final String senderEmail;
  final String senderName;
  final String apiKey;
  final int revision;

  /// Whether the form may be sent: a sender address, a name a mail header
  /// can carry, and a key on the first configuration.
  bool validFor(PurchaseOrderMailSettings? current) =>
      _isOrderEmail(senderEmail) &&
      !senderName.contains(RegExp(r'[\r\n<>"]')) &&
      ((current?.hasApiKey ?? false) || apiKey.trim().isNotEmpty) &&
      (apiKey.trim().isEmpty ||
          RegExp(r'^[A-Za-z0-9_\-]{8,200}$').hasMatch(apiKey.trim()));
}

/// The order's PDF and its words, for the e-mail.
typedef PurchaseOrderMail = ({
  String subject,
  String text,
  String pdfBase64,
  String fileName,
});

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

  /// The space's e-mail attempts, the latest first.
  Future<List<PurchaseOrderSend>> fetchSends(String workspaceId);

  /// How the space e-mails its orders; null before it is configured.
  Future<PurchaseOrderMailSettings?> fetchMailSettings(String workspaceId);

  Future<PurchaseOrderMailSettings> saveMailSettings(
    String workspaceId,
    PurchaseOrderMailDraft draft,
  );

  /// E-mails [order] under [attemptId]; the same id never sends twice.
  Future<PurchaseOrderSend> sendByEmail(
    String workspaceId,
    PurchaseOrder order,
    String attemptId,
    PurchaseOrderMail mail,
  );

  /// A person decides an unconfirmed attempt.
  Future<PurchaseOrderSend> resolveSend(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  });

  /// The space's deliveries, the latest first.
  Future<List<PurchaseOrderReceipt>> fetchReceipts(String workspaceId);

  /// Records a delivery; the same [requestId] replays its answer.
  Future<PurchaseOrder> recordReceipt(
    String workspaceId,
    String requestId,
    PurchaseOrderReceiptDraft draft,
  );

  /// Names [orderId] as the order a draft supplier bill charges; null
  /// unlinks it.
  Future<void> linkBill(String workspaceId, String purchaseId, String? orderId);
}
