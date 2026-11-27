// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4433 -- the goods an invoice line may sell: the business's own items kept in stock, as the composer offers them. A
// goods line names one; the server reads it, takes its tax rate and moves the stock when the invoice is issued.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// One item kept in stock, as a line of an invoice offers it.
class InvoiceGoodsItem {
  const InvoiceGoodsItem({
    required this.id,
    required this.name,
    required this.unit,
    this.byPiece = false,
  });

  factory InvoiceGoodsItem.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'services');
    return InvoiceGoodsItem(
      id: r.string('id'),
      name: r.stringOr('name'),
      unit: r.stringOr('inventory_unit'),
      byPiece: r.stringOr('tracking') == 'serial',
    );
  }

  final String id;
  final String name;

  /// The unit the item is counted in (its inventory unit): a goods line is sold in it.
  final String unit;

  /// Whether each piece is tracked by its own tag: a line then names the pieces it sells.
  final bool byPiece;
}

/// Reads the items a business keeps in stock and has on sale.
abstract interface class InvoiceGoodsCatalogue {
  Future<List<InvoiceGoodsItem>> items(String workspaceId);
}

/// The piece tags a person typed (separated by commas, spaces or new lines), each once, in order.
List<String> pieceTagsOf(String text) {
  final seen = <String>{};
  return [
    for (final t in text.split(RegExp(r'[\s,;]+')))
      if (t.isNotEmpty && seen.add(t)) t,
  ];
}
