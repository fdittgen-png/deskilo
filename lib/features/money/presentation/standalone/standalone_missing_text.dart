// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (A2) -- the words for what the server names as missing from a
// standalone draft (stable keys, 0820): a line's own facts, the draft's, and
// every essential the existing invoice refusals already name.
import '../../../../l10n/app_localizations.dart';
import '../../domain/previewed_document.dart';
import '../widgets/invoice_missing_sales_tax.dart';

String _text(AppLocalizations l, String key) {
  final line = RegExp(r'^line_(\d+)_(.+)$').firstMatch(key);
  if (line != null) {
    final fact = switch (line.group(2)) {
      'description' => l.standaloneFieldDescription,
      'quantity' => l.standaloneFieldQuantity,
      'unit' => l.standaloneFieldUnit,
      'unit_price' => l.standaloneFieldPrice,
      'base_quantity' => l.standaloneFieldBase,
      'basis' => l.standaloneFieldBasis,
      'supply' => l.standaloneFieldSupply,
      'vat_rate' => l.standaloneFieldVatRate,
      'amount' => l.standaloneFieldAmount,
      'line_id' => l.standaloneFieldLineId,
      final other => _goodsFact(l, other) ?? other ?? key,
    };
    return l.standaloneInvoiceMissingLine(line.group(1)!, fact);
  }
  return _draftText(l, key);
}

/// #4433 -- a goods line: what it sells, and what the stock says when it would leave.
String? _goodsFact(AppLocalizations l, String? fact) => switch (fact) {
  'item' => l.standaloneFieldItem,
  'variant' => l.standaloneFieldVariant,
  'lot' => l.standaloneFieldLot,
  'units' => l.standaloneFieldPieces,
  'goods_off' => l.standaloneFieldGoodsOff,
  'goods_cross_border' => l.standaloneFieldGoodsAbroad,
  'stock_not_enough' => l.standaloneFieldStockShort,
  'stock_pieces' => l.standaloneFieldStockPieces,
  'stock_lot' => l.standaloneFieldStockLot,
  'stock_lot_expired' => l.standaloneFieldStockExpired,
  'stock' => l.standaloneFieldStock,
  _ => null,
};

String _draftText(AppLocalizations l, String key) => switch (key) {
    'service_date' => l.standaloneFactServiceDate,
    'due_on' => l.standaloneFactDueDate,
    'due_on_before_issue' => l.standaloneFactDueDatePast,
    'due_on_too_far' => l.standaloneFactDueDateFar,
    'lines' => l.standaloneFactLines,
    'lines_too_many' => l.standaloneFactTooManyLines,
    'total_amount' => l.standaloneFactAmount,
    'total_not_positive' => l.standaloneFactTotal,
    totalMismatchKey => l.standaloneFactTotalMismatch,
    'currency' => l.standaloneFactCurrency,
    'unknown_subject' => l.standaloneFactUnknownSubject,
    'stock_sale_place' => l.standaloneFactSalePlace,
    'goods_off' => l.standaloneFieldGoodsOff,
    _ => _stateText(l, key),
  };

String _stateText(AppLocalizations l, String key) => switch (key) {
    'draft_stale' || 'draft_unknown' => l.standaloneFactStale,
    'draft_closed' => l.standaloneFactClosed,
    'approval_required' => l.standaloneFactApproval,
    'sales_tax_unsupported' => l.standaloneFactSalesTax,
    _ => invoiceMissingLabel(l, key),
  };

/// The missing facts of a preview or a refusal, worded and joined: what a sentence of any surface names.
String standaloneMissingList(AppLocalizations l, List<String> keys) => [for (final k in keys) _text(l, k)].join('; ');

/// The missing facts of a preview or a refusal, as one sentence.
String standaloneMissingSentence(AppLocalizations l, List<String> keys) =>
    l.standaloneInvoiceMissing(standaloneMissingList(l, keys));
