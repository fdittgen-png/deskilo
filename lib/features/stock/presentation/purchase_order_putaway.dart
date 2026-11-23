// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (B) -- putting a delivery away into stock, on the order's own pane:
// for each delivered line that is a stock item, how much goes into which
// place (as which variant, in which lot, with which expiry), and what the
// goods cost: not known, a total entered, or the order price asserted on
// purpose. A line that is not a stock item is named, not dropped. The same
// form serves "put away what remains" and "also put away" while recording a
// delivery; the server decides, and its refusal is said in the sheet.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity, isoDay;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


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
import '../domain/stock_code_resolver.dart';
import '../domain/stock_page.dart';
import '../domain/stock_receiving.dart';
import '../domain/stock_scan_session.dart';
import '../providers/stock_providers.dart';
import 'put_away_context.dart';
import 'put_away_tags.dart';
import 'stock_config_text.dart';
import 'stock_scan_bar.dart';
import 'stock_scan_feed.dart';
import 'stock_scan_hint.dart';

export 'put_away_context.dart' show PutAwayContext, PutAwayServices, loadPutAwayContext;

/// A typed quantity, read exactly as the person typed it (no grouping; `.` or `,`).
ExactQuantity? _exact(String text) => exactQuantityFromInput(text, grouping: false).value;

class _Part {
  _Part(this.line, String quantity)
    : qty = TextEditingController(text: quantity),
      lot = TextEditingController(),
      total = TextEditingController(),
      rate = TextEditingController(),
      focus = FocusNode();

  final DeliveredLineProgress line;
  final TextEditingController qty;
  final TextEditingController lot;

  /// #4379 -- the tags read, for an item tagged piece by piece.
  final PieceTags tags = PieceTags();
  final TextEditingController total;
  final TextEditingController rate;

  /// The quantity field's focus: a repeated scan that asks for the quantity puts the person there.
  final FocusNode focus;

  /// A scan counted this line (the first scan replaces the quantity the form started with).
  bool scanned = false;
  String? place;
  String? variant;
  DateRead expiry = (date: null, problem: null);

  /// `unknown`, `entered` or `order`.
  String cost = 'unknown';

  void dispose() {
    qty.dispose();
    lot.dispose();
    tags.dispose();
    total.dispose();
    rate.dispose();
    focus.dispose();
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
          if (context.items.containsKey(l.lineNo) && l.remaining > ExactQuantity.zero)
            // a line tagged piece by piece counts what was read: it starts at none
            _Part(l, followsDelivery ? '' : (context.perUnit.contains(l.lineNo) ? '0' : l.remaining.text)),
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
      if ((_exact(_quantityOf(p, delivered)) ?? ExactQuantity.zero) > exactOfReceived(delivered[p.line.lineNo] ?? 0))
        'putaway-${p.line.lineNo}-qty': stockReasonText(l10n, 'over_allocated'),
    ..._tagErrors(l10n, delivered),
  };

  /// A line tagged piece by piece needs exactly one tag per piece it puts away.
  FieldErrors _tagErrors(AppLocalizations l10n, Map<int, double>? delivered) => {
    for (final p in _parts)
      if (_neededTags(p, delivered) case final needed? when needed != p.tags.codes.length)
        'putaway-${p.line.lineNo}-tags': l10n.stockPutAwayTagsMissing(needed, p.tags.codes.length),
  };

  /// How many tags the part's quantity needs; null for a line not tagged piece by piece, or a quantity that is no
  /// whole number of pieces (the quantity's own check says so).
  int? _neededTags(_Part p, Map<int, double>? delivered) {
    if (!context.perUnit.contains(p.line.lineNo)) return null;
    final q = _exact(_quantityOf(p, delivered));
    if (q == null || q.isNegative) return null;
    return piecesOf(context.items[p.line.lineNo]!, p.line.unit, q);
  }

  void _readTag(_Part p, String raw, AppLocalizations l10n) {
    final cap = followsDelivery ? null : piecesOf(context.items[p.line.lineNo]!, p.line.unit, p.line.remaining);
    if (p.tags.read(raw, l10n, readElsewhere: (c) => _parts.any((x) => x.tags.codes.contains(c)), cap: cap)) _followTags(p);
    _refresh?.call();
  }

  void _dropTag(_Part p, String code) {
    p.tags.drop(code);
    _followTags(p);
    _refresh?.call();
  }

  /// A line counted in the item's own unit takes the number of tags read as its quantity.
  void _followTags(_Part p) {
    if (countsInPieces(context.items[p.line.lineNo]!, p.line.unit)) p.qty.text = '${p.tags.codes.length}';
  }

  void dispose() {
    scanner?.dispose();
    for (final p in _parts) {
      p.dispose();
    }
  }

  /// The scanner of this sheet (#4359), when the business uses one.
  StockScanFeed? scanner;
  VoidCallback? _refresh;

  /// Records the put-away; scans wait while it is in flight. Null when done, else what to say.
  Future<String?> submit(AppLocalizations l10n, PutAwayServices services, {required String workspaceId, required String receiptId}) async {
    try {
      scanner?.pause();
      await services.commands.putAway(workspaceId, receiptId, toAllocations(), requestId);
      return null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'a put-away was not recorded: $e', stackTrace: st);
      return putAwayProblem(l10n, e);
    } finally {
      scanner?.resume();
    }
  }

  /// Starts listening to a scanner when the business uses one (#4359).
  void listen(ProviderContainer container, {required String workspaceId, required List<StockPlace> places}) {
    if (!container.read(stockScanningProvider)) return;
    scanner = StockScanFeed(
      resolver: LazyStockCodeResolver(() => container.read(stockCodeResolverProvider)),
      workspaceId: workspaceId,
      session: StockScanSession(addsOne: container.read(stockScanAddsOneProvider)),
      onResult: scanned,
      placeAllowed: (p) => places.any((x) => x.id == p.id),
      itemAllowed: carries,
    );
  }

  /// Whether a scanned item is on this delivery.
  bool carries(ScannedItem item) => _parts.any((p) => context.items[p.line.lineNo]?.itemId == item.id);

  /// What a scan did: a place becomes the place of the lines not counted yet, an item counts its line (the
  /// first scan replaces the quantity the form started with) and puts it into the current place, a lot label
  /// sets the lot.
  void scanned(ScanResult result) {
    final place = result.place;
    final line = result.line;
    if (result.outcome == ScanOutcome.place && place != null) {
      for (final p in _parts) {
        if (!p.scanned) p.place = place.id;
      }
    } else if (result.outcome == ScanOutcome.line && line != null) {
      final part = _parts.where((p) => context.items[p.line.lineNo]?.itemId == line.itemId).firstOrNull;
      if (part != null) _countOn(part, line, asksQuantity: result.asksQuantity);
    }
    _refresh?.call();
  }

  /// A scanned item counts on its line: the first scan replaces the quantity the form started with, the current
  /// place is its place, and a lot label or a GS1 lot and expiry set what the item tracks.
  void _countOn(_Part part, ScanLine line, {required bool asksQuantity}) {
    part.scanned = true;
    // A quantity with no six-decimal value (a third of a box) is asked of the person, as a scan that asks does.
    final text = line.quantityText;
    if (asksQuantity || text == null) {
      part.focus.requestFocus();
    } else {
      part.qty.text = text;
    }
    final current = scanner?.session.current;
    if (current != null) part.place = current.id;
    final tracking = context.items[part.line.lineNo]?.tracking ?? 'none';
    final lot = line.lotCode;
    if (tracking != 'none' && lot != null && lot.isNotEmpty) part.lot.text = lot;
    final expiry = tracking == 'expiry' && line.expiresOn != null ? DateTime.tryParse(line.expiresOn!) : null;
    if (expiry != null) part.expiry = (date: expiry, problem: null);
  }

  /// The quantity of a part: what was typed, or (empty, while recording a
  /// delivery) everything that delivery brings of the line.
  String _quantityOf(_Part p, Map<int, double>? delivered) {
    final typed = p.qty.text.trim();
    return typed.isEmpty && followsDelivery ? exactOfReceived(delivered?[p.line.lineNo] ?? 0).text : typed;
  }

  /// [delivered]: the delivery being recorded, by line number.
  List<PutAwayAllocation> toAllocations({Map<int, double>? delivered}) => [
    for (final p in _parts)
      if (_exact(_quantityOf(p, delivered)) case final q? when q > ExactQuantity.zero)
        PutAwayAllocation(
          lineNo: p.line.lineNo,
          quantity: q.text,
          locationId: p.place ?? '',
          variantId: p.variant,
          lotCode: p.lot.text.trim().isEmpty ? null : p.lot.text.trim(),
          expiresOn: p.expiry.date == null ? null : isoDay(p.expiry.date!),
          tags: context.perUnit.contains(p.line.lineNo) ? List.unmodifiable(p.tags.codes) : const [],
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
      final q = _exact(p.qty.text);
      if (q == null || q.isNegative || q > p.line.remaining) {
        errors['putaway-${p.line.lineNo}-qty'] = stockReasonText(l10n, q == null || q.isNegative ? 'quantity_invalid' : 'over_allocated');
      }
      if (p.place == null && q != null && q > ExactQuantity.zero) errors['putaway-${p.line.lineNo}-place'] = stockReasonText(l10n, 'location_foreign');
    }
    if (!followsDelivery) errors.addAll(_tagErrors(l10n, null));
    return errors;
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    _refresh = refresh;
    return [
      if (scanner != null) StockScanBar(feed: scanner!, onOpenItems: () => _openItems(context)) else const StockScanHint(insideSheet: true),
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
        focusNode: p.focus,
        fieldKey: 'putaway-$n-qty',
        label: l10n.stockPutAwayQuantity(p.line.unit.isEmpty ? item.inventoryUnit : p.line.unit),
        helper: followsDelivery ? l10n.stockPutAwayAll : null,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      ),
      KeyedSubtree(
        // a scan sets the place from outside: the field starts again from it
        key: ValueKey('putaway-$n-place-${p.place}'),
        child: DropdownButtonFormField<String?>(
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
      if (this.context.perUnit.contains(n)) ..._tagFields(context, l10n, p),
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
          // the rate is sent as typed and the server reads a dot only (0840): no comma here
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        ),
      const FormGap(),
    ];
  }
}

extension on PutAwayDraft {
  /// A line counted in pieces shows what is read of what remains; otherwise of what its quantity needs.
  List<Widget> _tagFields(BuildContext context, AppLocalizations l10n, _Part p) {
    final item = this.context.items[p.line.lineNo]!;
    return pieceTagFields(
      context,
      lineNo: p.line.lineNo,
      tags: p.tags,
      needed: countsInPieces(item, p.line.unit) ? piecesOf(item, p.line.unit, p.line.remaining) : _neededTags(p, null),
      onRead: (v) => _readTag(p, v, l10n),
      onDrop: (t) => _dropTag(p, t),
    );
  }
}

void _openItems(BuildContext context) {
  final router = GoRouter.of(context);
  Navigator.of(context).pop();
  router.go('/stock/items');
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
  draft.listen(ProviderScope.containerOf(context), workspaceId: workspaceId, places: loaded.places);
  final saved = await showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockPutAwayTitle(order.reference),
      submitLabel: l10n.stockPutAwayAction,
      submitKey: const ValueKey('putaway-confirm'),
      onDispose: draft.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.submit(l10n, services, workspaceId: workspaceId, receiptId: receipt.id),
      builder: draft.build,
    ),
  );
  if (saved) onDone();
  return saved;
}
