// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (A2) -- a standalone customer invoice as the composer holds it: the
// facts a person enters (a customer, explicit dates and itemised lines) and
// what the server answers (a saved revision, a preview, an issued invoice).
// Nothing here computes an amount or a rate: the server does, and the
// preview is its own answer.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'previewed_document.dart';

/// One itemised line as entered. Quantities and prices stay decimal TEXT:
/// the server reads them exactly and refuses what it cannot keep.
class StandaloneLine {
  const StandaloneLine({
    required this.description,
    required this.quantity,
    required this.unitCode,
    required this.unitLabel,
    required this.unitPrice,
    this.lineId,
    this.unEceCode = '',
    this.grossPrice = false,
    this.baseQuantity = '1',
    this.supply = 'general',
    this.vatRateId,
    this.itemId,
    this.pieceTags = const [],
    this.serviceId,
  });

  /// The line's own identity, kept across saves; null until the server gave it.
  final String? lineId;
  final String description;
  final String quantity;
  final String unitCode;
  final String unitLabel;
  final String unEceCode;
  final String unitPrice;

  /// Whether [unitPrice] includes the tax.
  final bool grossPrice;
  final String baseQuantity;

  /// `general` or `property`: what the line supplies, for the place of supply; `goods` for a line that sells a
  /// stock item ([itemId], #4433).
  final String supply;

  /// One of the business's own VAT rates; null takes its default (for goods, the item's own rate first).
  final String? vatRateId;

  /// #4433 -- the stock item a goods line sells; null for a service or property line.
  final String? itemId;

  /// #4433 -- the tags of the pieces a goods line sells, for an item tracked piece by piece; empty otherwise.
  final List<String> pieceTags;

  /// #4510 -- the catalogue service the line was picked from; null for an ad-hoc line. The line's price, rate and supply are
  /// what was agreed and stay as saved: the catalogue only fills the line in.
  final String? serviceId;

  /// Whether the line sells goods from the stock.
  bool get isGoods => itemId != null;

  /// The same line with only [description], [quantity], [unit] (code, label and UN/ECE code together), [unitPrice],
  /// [grossPrice] or [vatRateId] changed: the base quantity it was read with, the supply kind and the goods it sells are
  /// kept ([withGoods] changes those).
  StandaloneLine copyWith({
    String? description,
    String? quantity,
    ({String code, String label, String un})? unit,
    String? unitPrice,
    bool? grossPrice,
    String? Function()? vatRateId,
  }) => StandaloneLine(
    lineId: lineId,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unitCode: unit?.code ?? unitCode,
    unitLabel: unit?.label ?? unitLabel,
    unEceCode: unit?.un ?? unEceCode,
    unitPrice: unitPrice ?? this.unitPrice,
    grossPrice: grossPrice ?? this.grossPrice,
    baseQuantity: baseQuantity,
    supply: supply,
    vatRateId: vatRateId == null ? this.vatRateId : vatRateId(),
    itemId: itemId,
    pieceTags: pieceTags,
    serviceId: serviceId,
  );

  /// The same line selling [goods] (the item, or none, and the piece tags): the supply kind follows the item, and a line
  /// given back to the free text drops its pieces.
  StandaloneLine withGoods(({String? itemId, List<String> tags}) goods) => StandaloneLine(
    lineId: lineId,
    description: description,
    quantity: quantity,
    unitCode: unitCode,
    unitLabel: unitLabel,
    unEceCode: unEceCode,
    unitPrice: unitPrice,
    grossPrice: grossPrice,
    baseQuantity: baseQuantity,
    supply: goods.itemId != null ? 'goods' : (supply == 'goods' ? 'general' : supply),
    vatRateId: vatRateId,
    itemId: goods.itemId,
    pieceTags: goods.itemId == null ? const [] : goods.tags,
    serviceId: goods.itemId == null ? serviceId : null,
  );

  Map<String, Object?> toWire() => {
    if (lineId != null) 'line_id': lineId,
    'description': description,
    'quantity': quantity,
    'unit': {'code': unitCode, 'label': unitLabel, 'un_ece_code': unEceCode},
    'unit_price': unitPrice,
    'basis': grossPrice ? 'gross' : 'net',
    'base_quantity': baseQuantity,
    'supply': supply,
    if (vatRateId != null) 'vat_rate_id': vatRateId,
    if (itemId != null) 'item_id': itemId,
    if (serviceId != null) 'service_id': serviceId,
    if (pieceTags.isNotEmpty) 'units': [for (final t in pieceTags) {'tag': t}],
  };

  /// The same line picked from the catalogue service [id] (or from none): a service line supplies [supply], `property` or `general`.
  StandaloneLine withService(String? id, {String? supply}) => StandaloneLine(
    lineId: lineId,
    description: description,
    quantity: quantity,
    unitCode: unitCode,
    unitLabel: unitLabel,
    unEceCode: unEceCode,
    unitPrice: unitPrice,
    grossPrice: grossPrice,
    baseQuantity: baseQuantity,
    supply: id == null || isGoods ? this.supply : (supply ?? this.supply),
    vatRateId: vatRateId,
    itemId: itemId,
    pieceTags: pieceTags,
    serviceId: isGoods ? null : id,
  );

  StandaloneLine withLineId(String? id) => StandaloneLine(
    lineId: id,
    description: description,
    quantity: quantity,
    unitCode: unitCode,
    unitLabel: unitLabel,
    unEceCode: unEceCode,
    unitPrice: unitPrice,
    grossPrice: grossPrice,
    baseQuantity: baseQuantity,
    supply: supply,
    vatRateId: vatRateId,
    itemId: itemId,
    pieceTags: pieceTags,
    serviceId: serviceId,
  );

  factory StandaloneLine.fromJson(JsonReader r) {
    final u = r.objectOrNull('unit');
    return StandaloneLine(
      lineId: r.stringOrNull('line_id'),
      description: r.stringOr('description'),
      quantity: r.stringOr('quantity'),
      unitCode: u?.stringOr('code') ?? '',
      unitLabel: u?.stringOr('label') ?? '',
      unEceCode: u?.stringOr('un_ece_code') ?? '',
      unitPrice: r.stringOr('unit_price'),
      grossPrice: r.stringOr('basis') == 'gross',
      baseQuantity: r.stringOr('base_quantity', '1'),
      supply: r.stringOr('supply', 'general'),
      vatRateId: r.stringOrNull('vat_rate_id'),
      itemId: r.stringOrNull('item_id'),
      serviceId: r.stringOrNull('service_id'),
      pieceTags: [
        for (final u in r.objects('units', (u) => u.stringOr('tag')))
          if (u.isNotEmpty) u,
      ],
    );
  }
}

/// The draft as the composer edits it.
class StandaloneDraft {
  const StandaloneDraft({
    required this.subjectMemberId,
    required this.serviceDate,
    required this.dueOn,
    required this.lines,
    this.draftId,
    this.revision,
    this.buyerReference = '',
    this.purchaseOrder = '',
  });

  /// Null until the first save; with [revision], the saved state this edits.
  final String? draftId;
  final int? revision;

  /// The customer: a member of the business, the financial subject.
  final String subjectMemberId;
  final DateTime serviceDate;
  final DateTime dueOn;
  final String buyerReference;
  final String purchaseOrder;
  final List<StandaloneLine> lines;

  List<Map<String, Object?>> linesWire() => [for (final l in lines) l.toWire()];

  String get serviceDay => isoDay(serviceDate);
  String get dueDay => isoDay(dueOn);
}

/// A draft the server saved: its identity, its revision and its lines, each
/// with its stable identity.
class StandaloneSaved {
  const StandaloneSaved({
    required this.draftId,
    required this.revision,
    required this.lines,
  });

  factory StandaloneSaved.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'save_standalone_invoice_draft_v1');
    return StandaloneSaved(
      draftId: r.string('draft_id'),
      revision: r.integer('revision'),
      lines: r.objects('lines', StandaloneLine.fromJson),
    );
  }

  final String draftId;
  final int revision;
  final List<StandaloneLine> lines;
}

/// The invoice an issue made.
class StandaloneIssued {
  const StandaloneIssued({
    required this.invoiceId,
    required this.number,
    required this.replayed,
  });

  factory StandaloneIssued.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'issue_standalone_invoice_v1');
    return StandaloneIssued(
      invoiceId: r.string('invoice_id'),
      number: r.string('number'),
      replayed: r.isTrue('replayed'),
    );
  }

  final String invoiceId;

  /// The number the invoice froze; null when the invoice was found by its
  /// receipt, which does not carry it.
  final String? number;

  /// True when the server recognised the request and answered the invoice an
  /// earlier attempt made.
  final bool replayed;
}

/// What a person does to a standalone draft: each call is the server's own
/// decision; a lost answer to [issue] is never retried by the port.
abstract interface class StandaloneInvoiceCommands {
  Future<StandaloneSaved> saveDraft({
    required String workspaceId,
    required StandaloneDraft draft,
  });

  Future<PreviewedDocument> preview({
    required String workspaceId,
    required String draftId,
    required int revision,
  });

  /// Issues the CONFIRMED revision under [requestId]; the same id never acts twice.
  Future<StandaloneIssued> issue({
    required String workspaceId,
    required String draftId,
    required int revision,
    required String requestId,
  });
}
