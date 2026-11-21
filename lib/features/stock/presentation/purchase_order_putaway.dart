// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (B) -- putting a delivery away into stock, on the order's own pane:
// for each delivered line that is a stock item, how much goes into which
// place (as which variant, in which lot, with which expiry), and what the
// goods cost: not known, a total entered, or the order price asserted on
// purpose. A line that is not a stock item is named, not dropped. The same
// form serves "put away what remains" and "also put away" while recording a
// delivery; the server decides, and its refusal is said in the sheet.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show isoDay;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/decimal_input.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../money/domain/purchase_order.dart';
import '../../money/domain/purchase_order_receipt.dart';
import '../domain/put_away_progress.dart';
import '../domain/stock_config.dart';
import '../domain/stock_config_commands.dart';
import '../domain/stock_page.dart';
import '../domain/stock_queries.dart';
import '../domain/stock_receiving.dart';
import '../domain/stock_variants.dart';
import 'stock_config_text.dart';

/// What the put-away asks of the stock and of the business, read from the
/// providers by the pane and handed over whole.
class PutAwayServices {
  const PutAwayServices({
    required this.commands,
    required this.config,
    required this.queries,
    required this.currency,
  });

  final StockReceivingCommands commands;
  final StockConfigCommands config;
  final StockQueries queries;

  /// The business's currency, for the rate of an order in another one.
  final String currency;
}

/// What the form needs of the stock side, read before it opens.
class PutAwayContext {
  const PutAwayContext({required this.places, required this.items, required this.variants, required this.currency});

  final List<StockPlace> places;

  /// The stock configuration of the item each line names (by line number),
  /// when it is a stock item the business keeps.
  final Map<int, StockItemConfig> items;
  final Map<int, List<StockVariant>> variants;

  /// The business's currency, for the rate of an order in another one.
  final String currency;
}

/// Reads what the form needs for [lines]; null when the stock side could not
/// be read (the caller says so).
Future<PutAwayContext?> loadPutAwayContext(
  BuildContext context,
  PutAwayServices services, {
  required String workspaceId,
  required List<DeliveredLineProgress> lines,
}) async {
  final config = services.config;
  try {
    final places = await services.queries.places(workspaceId);
    final items = <int, StockItemConfig>{};
    final variants = <int, List<StockVariant>>{};
    for (final l in lines) {
      final id = l.serviceId;
      if (id == null) continue;
      final item = await config.item(workspaceId, id);
      if (item == null || !item.stockable) continue;
      items[l.lineNo] = item;
      variants[l.lineNo] = [for (final v in await config.variants(workspaceId, id)) if (v.active) v];
    }
    return PutAwayContext(places: places, items: items, variants: variants, currency: services.currency);
  } on Object catch (e, st) {
    TraceLogger.instance.error('stock', 'the put-away could not read the stock side', error: e, stackTrace: st);
    if (context.mounted) AppSnack.error(context, context.l10n.stockReadFailed);
    return null;
  }
}

/// A typed quantity, read as the person typed it (no grouping).
double? _number(String text) => parseDecimalInput(text.trim(), grouping: false)?.toDouble();

class _Part {
  _Part(this.line, String quantity)
    : qty = TextEditingController(text: quantity),
      lot = TextEditingController(),
      total = TextEditingController(),
      rate = TextEditingController();

  final DeliveredLineProgress line;
  final TextEditingController qty;
  final TextEditingController lot;
  final TextEditingController total;
  final TextEditingController rate;
  String? place;
  String? variant;
  DateRead expiry = (date: null, problem: null);

  /// `unknown`, `entered` or `order`.
  String cost = 'unknown';

  void dispose() {
    qty.dispose();
    lot.dispose();
    total.dispose();
    rate.dispose();
  }
}

/// The put-away of the lines of one delivery: its fields and what it sends.
class PutAwayDraft {
  /// [followsDelivery]: the quantities start empty, meaning everything the
  /// delivery being recorded brings of the line.
  PutAwayDraft(this.context, this.order, List<DeliveredLineProgress> lines, {this.followsDelivery = false})
    : _lines = lines,
      _parts = [
        for (final l in lines)
          if (context.items.containsKey(l.lineNo) && l.remaining > 0) _Part(l, followsDelivery ? '' : _text(l.remaining)),
      ] {
    for (final p in _parts) {
      p.place = context.places.isEmpty ? null : context.places.first.id;
    }
  }

  final PutAwayContext context;
  final PurchaseOrder order;
  final bool followsDelivery;
  final List<DeliveredLineProgress> _lines;
  final List<_Part> _parts;

  /// One per form: a retry of the same put-away answers once.
  final String requestId = newRequestId();

  static String _text(double q) => q == q.truncateToDouble() ? q.truncate().toString() : '$q';

  bool get isEmpty => _parts.isEmpty;

  /// Whether the put-away travels with the delivery being recorded.
  bool also = false;

  /// The switch "also put away into stock" and, when it is on, the parts.
  List<Widget> buildAlso(BuildContext context, VoidCallback refresh) => [
    if (!isEmpty)
      SwitchListTile(
        key: const ValueKey('purchase-order-receive-also'),
        contentPadding: EdgeInsets.zero,
        title: Text(context.l10n.stockPutAwayAlso),
        value: also,
        onChanged: (v) {
          also = v;
          refresh();
        },
      ),
    if (also) ...build(context, refresh),
  ];

  /// The put-away may not exceed what the delivery being recorded brings.
  FieldErrors validateAgainst(AppLocalizations l10n, Map<int, double> delivered) => {
    for (final p in _parts)
      if ((_number(_quantityOf(p, delivered)) ?? 0) > (delivered[p.line.lineNo] ?? 0))
        'putaway-${p.line.lineNo}-qty': stockReasonText(l10n, 'over_allocated'),
  };

  void dispose() {
    for (final p in _parts) {
      p.dispose();
    }
  }

  /// The quantity of a part: what was typed, or (empty, while recording a
  /// delivery) everything that delivery brings of the line.
  String _quantityOf(_Part p, Map<int, double>? delivered) {
    final typed = p.qty.text.trim();
    return typed.isEmpty && followsDelivery ? _text(delivered?[p.line.lineNo] ?? 0) : typed;
  }

  /// [delivered]: the delivery being recorded, by line number.
  List<PutAwayAllocation> toAllocations({Map<int, double>? delivered}) => [
    for (final p in _parts)
      if ((_number(_quantityOf(p, delivered)) ?? 0) > 0)
        PutAwayAllocation(
          lineNo: p.line.lineNo,
          quantity: _quantityOf(p, delivered),
          locationId: p.place ?? '',
          variantId: p.variant,
          lotCode: p.lot.text.trim().isEmpty ? null : p.lot.text.trim(),
          expiresOn: p.expiry.date == null ? null : isoDay(p.expiry.date!),
          cost: switch (p.cost) {
            'entered' => PutAwayCost.known(totalMinor: int.tryParse(p.total.text.trim()) ?? -1),
            'order' => PutAwayCost.orderPrice(
              sourceRate: order.currency != context.currency && p.rate.text.trim().isNotEmpty ? p.rate.text.trim() : null,
            ),
            _ => const PutAwayCost.unknown(),
          },
        ),
  ];

  FieldErrors validate(AppLocalizations l10n) {
    final errors = <String, String>{};
    for (final p in _parts) {
      if (followsDelivery && p.qty.text.trim().isEmpty) continue;
      final q = _number(p.qty.text);
      if (q == null || q < 0 || q > p.line.remaining) {
        errors['putaway-${p.line.lineNo}-qty'] = stockReasonText(l10n, q == null || q < 0 ? 'quantity_invalid' : 'over_allocated');
      }
      if (p.place == null && (q ?? 0) > 0) errors['putaway-${p.line.lineNo}-place'] = stockReasonText(l10n, 'location_foreign');
    }
    return errors;
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    return [
      for (final l in _lines)
        if (!this.context.items.containsKey(l.lineNo))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.stockPutAwayNotStock(l.description),
              key: ValueKey('putaway-${l.lineNo}-not-stock'),
            ),
          ),
      for (final p in _parts) ..._part(context, l10n, p, refresh),
    ];
  }

  List<Widget> _part(BuildContext context, AppLocalizations l10n, _Part p, VoidCallback refresh) {
    final n = p.line.lineNo;
    final item = this.context.items[n]!;
    final variants = this.context.variants[n] ?? const [];
    final foreign = order.currency != this.context.currency;
    return [
      Text(p.line.description, style: Theme.of(context).textTheme.titleSmall),
      AppTextField(
        key: ValueKey('putaway-$n-qty'),
        controller: p.qty,
        fieldKey: 'putaway-$n-qty',
        label: l10n.stockPutAwayQuantity(p.line.unit.isEmpty ? item.inventoryUnit : p.line.unit),
        helper: followsDelivery ? l10n.stockPutAwayAll : null,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      ),
      DropdownButtonFormField<String?>(
        key: ValueKey('putaway-$n-place'),
        initialValue: p.place,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.stockPutAwayPlace),
        items: [
          for (final pl in this.context.places) DropdownMenuItem<String?>(value: pl.id, child: Text(pl.label)),
        ],
        onChanged: (v) {
          p.place = v;
          refresh();
        },
      ),
      if (variants.isNotEmpty)
        DropdownButtonFormField<String?>(
          key: ValueKey('putaway-$n-variant'),
          initialValue: p.variant,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.stockPutAwayVariant),
          items: [
            for (final v in variants) DropdownMenuItem<String?>(value: v.id, child: Text(v.label)),
          ],
          onChanged: (v) {
            p.variant = v;
            refresh();
          },
        ),
      if (item.tracking != 'none')
        AppTextField(
          key: ValueKey('putaway-$n-lot'),
          controller: p.lot,
          fieldKey: 'putaway-$n-lot',
          label: l10n.stockPutAwayLot,
          maxLength: 64,
        ),
      if (item.tracking == 'expiry')
        AppDateField(
          key: ValueKey('putaway-$n-expiry'),
          fieldKey: 'putaway-$n-expiry',
          label: l10n.stockPutAwayExpiry,
          value: p.expiry.date,
          first: DateTime(2000),
          last: DateTime(2100),
          onChanged: (read) => p.expiry = read,
        ),
      SegmentedButton<String>(
        key: ValueKey('putaway-$n-cost'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: 'unknown', label: Text(l10n.stockPutAwayCostUnknown)),
          ButtonSegment(value: 'entered', label: Text(l10n.stockPutAwayCostEntered)),
          ButtonSegment(value: 'order', label: Text(l10n.stockPutAwayCostOrder)),
        ],
        selected: {p.cost},
        onSelectionChanged: (s) {
          p.cost = s.first;
          refresh();
        },
      ),
      if (p.cost == 'entered')
        AppTextField(
          key: ValueKey('putaway-$n-total'),
          controller: p.total,
          fieldKey: 'putaway-$n-total',
          label: l10n.stockPutAwayCostTotal,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      if (p.cost == 'order' && foreign)
        AppTextField(
          key: ValueKey('putaway-$n-rate'),
          controller: p.rate,
          fieldKey: 'putaway-$n-rate',
          label: l10n.stockPutAwayCostRate(this.context.currency),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        ),
      const FormGap(),
    ];
  }
}

/// "Put away what remains" of one delivery, in its own sheet; [onDone] is
/// called after a put-away that was recorded.
Future<bool> showPutAwaySheet(
  BuildContext context,
  PutAwayServices services, {
  required String workspaceId,
  required PurchaseOrder order,
  required PurchaseOrderReceipt receipt,
  required List<DeliveredLineProgress> lines,
  required VoidCallback onDone,
}) async {
  final l10n = context.l10n;
  final loaded = await loadPutAwayContext(context, services, workspaceId: workspaceId, lines: lines);
  if (loaded == null || !context.mounted) return false;
  final draft = PutAwayDraft(loaded, order, lines);
  if (draft.isEmpty) {
    AppSnack.info(context, l10n.stockPutAwayNothing);
    return false;
  }
  final saved = await showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockPutAwayTitle(order.reference),
      submitLabel: l10n.stockPutAwayAction,
      submitKey: const ValueKey('putaway-confirm'),
      onDispose: draft.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () async {
        try {
          await services.commands.putAway(workspaceId, receipt.id, draft.toAllocations(), draft.requestId);
          return null;
        } on Object catch (e, st) {
          TraceLogger.instance.warn('stock', 'a put-away was not recorded: $e', stackTrace: st);
          return stockSaveProblem(l10n, e);
        }
      },
      builder: draft.build,
    ),
  );
  if (saved) onDone();
  return saved;
}
