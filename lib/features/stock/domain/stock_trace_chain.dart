// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4432 (G18) -- the whole chain of a lot or a piece, as `stock_trace_chain_v1` (0923) answers it: every movement in
// order, each with its places, its quantity, the pieces it carried and the document that caused it. A document the
// reader may not see is named by its kind alone (`unavailable`), never left out, so a gap in the chain is never
// mistaken for "nothing happened".
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// What a step's document is.
enum TraceDocumentKind { delivery, counterReceipt, invoice, event, other }

/// The document that caused a step.
class TraceDocument {
  const TraceDocument({required this.kind, this.id, this.label, this.supplier, this.available = true});

  final TraceDocumentKind kind;
  final String? id;

  /// The order reference, the receipt number or the invoice number.
  final String? label;
  final String? supplier;

  /// False when the reader may not see the document: only its kind is known.
  final bool available;

  static TraceDocument? fromJson(Object? json) {
    if (json is! Map) return null;
    final r = JsonReader.of(json, context: 'stock_trace_chain.document');
    return TraceDocument(
      kind: switch (r.stringOr('kind')) {
        'delivery' => TraceDocumentKind.delivery,
        'counter_receipt' => TraceDocumentKind.counterReceipt,
        'invoice' => TraceDocumentKind.invoice,
        'event' => TraceDocumentKind.event,
        _ => TraceDocumentKind.other,
      },
      id: r.stringOrNull('id'),
      label: r.textOrAbsent('label') ?? r.intOrNull('label')?.toString(),
      supplier: r.stringOrNull('supplier'),
      available: r.stringOr('state') != 'unavailable',
    );
  }
}

/// One movement of the chain.
class TraceStep {
  const TraceStep({
    required this.movementId,
    required this.at,
    required this.reason,
    required this.quantity,
    required this.fromCode,
    required this.toCode,
    this.pieces,
    this.document,
  });

  final String movementId;
  final DateTime at;
  final String reason;
  final ExactQuantity quantity;
  final String fromCode;
  final String toCode;

  /// How many pieces it carried, where the business uses tags.
  final int? pieces;
  final TraceDocument? document;

  factory TraceStep.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_trace_chain.step');
    String code(String k) => r.objectOrNull(k)?.stringOr('code') ?? '';
    return TraceStep(
      movementId: r.string('movement_id'),
      at: DateTime.parse(r.string('at')),
      reason: r.string('reason'),
      quantity: ExactQuantity.parse('${r.numeric('quantity')}'),
      fromCode: code('from'),
      toCode: code('to'),
      pieces: r.intOrNull('pieces'),
      document: TraceDocument.fromJson(r.objectOrNull('document')?.json),
    );
  }
}

/// The chain of one subject.
class TraceChain {
  const TraceChain({required this.subject, required this.steps, this.lotCode, this.pieceTag, this.piecePlace, this.truncated = false});

  /// `lot`, `piece`, `movement` or `sale_line`.
  final String subject;
  final String? lotCode;
  final String? pieceTag;

  /// Where the piece is now (its place code).
  final String? piecePlace;
  final List<TraceStep> steps;

  /// More steps exist than were answered.
  final bool truncated;

  factory TraceChain.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_trace_chain');
    final piece = r.objectOrNull('piece');
    return TraceChain(
      subject: r.string('subject'),
      lotCode: r.objectOrNull('lot')?.stringOrNull('code'),
      pieceTag: piece?.stringOrNull('tag'),
      piecePlace: piece?.objectOrNull('place')?.stringOrNull('code'),
      steps: [for (final s in r.list('steps')) TraceStep.fromJson(s)],
      truncated: r.boolOr('truncated', fallback: false),
    );
  }
}

abstract interface class StockTraceChainReader {
  /// The chain of exactly one of [lotId], [pieceId] or [movementId].
  Future<TraceChain> chain(String workspaceId, {String? lotId, String? pieceId, String? movementId});
}
