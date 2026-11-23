// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 (B) -- moving goods and taking them out, as two small forms: where the
// goods are taken from, where they go (or that they are used or lost), which
// item and how much. Two places of one site move the goods at once; places of
// different sites load them onto the way, to be received on the other side. A
// refusal says why under the sheet and moves nothing; one request id per form
// makes a retry answer once. The quantity is read exactly, as it was typed.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/decimal_input.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import '../domain/stock_operations.dart';
import '../domain/stock_page.dart';
import '../domain/stock_scan_session.dart';
import '../domain/stock_sites.dart';
import '../providers/stock_providers.dart';
import 'stock_config_text.dart';
import 'stock_place_text.dart';
import 'stock_scan_bar.dart';
import 'stock_scan_feed.dart';
import 'stock_scan_hint.dart';


/// Moves goods ([takeOut] false) or takes them out ([takeOut] true); true when
/// done.
Future<bool> showStockMoveSheet(
  BuildContext context,
  StockOperations operations, {
  required String workspaceId,
  required List<StockItem> items,
  required List<StockPlaceConfig> places,
  bool takeOut = false,
}) {
  final l10n = context.l10n;
  final container = ProviderScope.containerOf(context);
  final draft = _MoveDraft(
    items,
    places,
    takeOut: takeOut,
    locale: Localizations.localeOf(context).toString(),
    separator: container.read(stockAddressSeparatorProvider),
  );
  if (container.read(stockScanningProvider)) {
    draft.scanner = StockScanFeed(
      resolver: LazyStockCodeResolver(() => container.read(stockCodeResolverProvider)),
      workspaceId: workspaceId,
      session: StockScanSession(addsOne: container.read(stockScanAddsOneProvider)),
      onResult: draft.scanned,
      placeAllowed: (p) => draft.places.any((x) => x.id == p.id),
      itemAllowed: (i) => items.any((x) => x.id == i.id),
    );
  }
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: takeOut ? l10n.stockTakeOutOpen : l10n.stockMoveOpen,
      submitLabel: takeOut ? l10n.stockTakeOutSubmit : l10n.stockMoveSubmit,
      submitKey: const ValueKey('stock-move-submit'),
      onDispose: draft.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.submit(l10n, operations, workspaceId),
      builder: draft.build,
    ),
  );
}

class _MoveDraft {
  _MoveDraft(this.items, List<StockPlaceConfig> places, {required this.takeOut, required this.locale, required this.separator})
    : places = stockRealPlaces(places),
      all = places,
      fields = FormControllers({'quantity': ''});

  final List<StockItem> items;
  final List<StockPlaceConfig> places;
  final List<StockPlaceConfig> all;
  final bool takeOut;
  final String locale;
  final String separator;
  final FormControllers fields;

  /// One per form: a retry of the same submit answers once.
  final String requestId = newRequestId();
  String? item;
  String? from;
  String? to;
  StockTakeOutReason reason = StockTakeOutReason.consumption;

  /// The scanner of this sheet (#4359), when the business uses one.
  StockScanFeed? scanner;
  final FocusNode _quantityFocus = FocusNode();
  VoidCallback? _refresh;

  void dispose() {
    scanner?.dispose();
    _quantityFocus.dispose();
    fields.dispose();
  }

  /// What a scan did: a place is where the goods are taken from (a second one is where they go), an item is the
  /// item with the scanned quantity.
  void scanned(ScanResult result) {
    final place = result.place;
    final line = result.line;
    if (result.outcome == ScanOutcome.place && place != null) {
      if (takeOut || from == null) {
        from = place.id;
      } else {
        to = place.id;
      }
    } else if (result.outcome == ScanOutcome.line && line != null) {
      scanner?.session.lines.removeWhere((l) => l != line);
      item = line.itemId;
      // A quantity with no six-decimal value is asked of the person (#4393).
      final text = line.quantityText;
      if (result.asksQuantity || text == null) {
        _quantityFocus.requestFocus();
      } else {
        fields['quantity'].text = text;
      }
    }
    _refresh?.call();
  }

  StockItem? get chosen => items.where((i) => i.id == item).firstOrNull;

  bool get betweenSites => from != null && to != null && stockSiteOf(from!, all) != stockSiteOf(to!, all);

  ExactQuantity? get quantity => exactQuantityFromInput(fields.text('quantity'), locale: locale).value;

  FieldErrors validate(AppLocalizations l10n) => {
    if (item == null) 'item': stockReasonText(l10n, 'item_foreign'),
    if (from == null) 'from': stockReasonText(l10n, 'location_foreign'),
    if (!takeOut && (to == null || to == from)) 'to': stockReasonText(l10n, 'location_foreign'),
    if (quantity == null || quantity! <= ExactQuantity.zero) 'quantity': stockReasonText(l10n, 'quantity_invalid'),
  };

  Future<String?> submit(AppLocalizations l10n, StockOperations operations, String workspaceId) async {
    final line = StockLineDraft(
      itemId: item!,
      quantity: quantity!.text,
      fromLocationId: from!,
      toLocationId: takeOut ? null : to,
    );
    try {
      scanner?.pause();
      if (takeOut) {
        await operations.takeOut(workspaceId, reason, [line], requestId);
      } else if (betweenSites) {
        await operations.load(workspaceId, to!, [line], requestId);
      } else {
        await operations.transfer(workspaceId, [line], requestId);
      }
      return null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'goods were not moved: $e', stackTrace: st);
      return stockSaveProblem(l10n, e);
    } finally {
      scanner?.resume();
    }
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    final unit = chosen?.unit ?? '';
    final options = [for (final p in places) (p.id, stockPlaceTitle(p, separator))];
    _refresh = refresh;
    return [
      if (scanner != null) StockScanBar(feed: scanner!, onOpenItems: () => _openItems(context)) else const StockScanHint(insideSheet: true),
      if (takeOut) ...[
        SegmentedButton<StockTakeOutReason>(
          key: const ValueKey('stock-takeout-reason'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: StockTakeOutReason.consumption, label: Text(l10n.stockTakeOutUsed)),
            ButtonSegment(value: StockTakeOutReason.loss, label: Text(l10n.stockTakeOutLoss)),
          ],
          selected: {reason},
          onSelectionChanged: (s) {
            reason = s.first;
            refresh();
          },
        ),
        const FormGap(),
      ],
      StockPickField(
        keyName: 'item',
        label: l10n.expenseSupplyItem,
        value: item,
        options: [for (final i in items) (i.id, i.name)],
        onPicked: (v) {
          item = v;
          refresh();
        },
      ),
      const FormGap(),
      StockPickField(
        keyName: 'from',
        label: l10n.stockMoveFrom,
        value: from,
        options: options,
        onPicked: (v) {
          from = v;
          refresh();
        },
      ),
      if (!takeOut) ...[
        const FormGap(),
        StockPickField(
          keyName: 'to',
          label: l10n.stockTransferReceiveTo,
          value: to,
          options: options,
          onPicked: (v) {
            to = v;
            refresh();
          },
        ),
        if (from != null && to != null && to != from) ...[
          const FormGap(),
          Text(
            key: ValueKey(betweenSites ? 'stock-move-other-site' : 'stock-move-same-site'),
            betweenSites ? l10n.stockMoveOtherSite : l10n.stockMoveSameSite,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
      const FormGap(),
      AppTextField(
        key: const ValueKey('stock-move-quantity'),
        controller: fields['quantity'],
        fieldKey: 'quantity',
        label: l10n.stockMoveQuantity(unit),
        focusNode: _quantityFocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      ),
    ];
  }

  void _openItems(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/stock/items');
  }
}

/// One choice among [options] (id, text); the form's error for [keyName] is
/// read below its scope, where it lives.
class StockPickField extends StatelessWidget {
  const StockPickField({
    super.key,
    required this.keyName,
    required this.label,
    required this.value,
    required this.options,
    required this.onPicked,
  });

  final String keyName;
  final String label;
  final String? value;
  final List<(String, String)> options;
  final ValueChanged<String?> onPicked;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    // a scan sets the value from outside: the field starts again from it
    key: ValueKey('$keyName-$value'),
    child: DropdownButtonFormField<String?>(
      key: ValueKey('stock-move-$keyName'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: FormErrorsScope.maybeOf(context)?.errors[keyName]),
      items: [for (final (id, text) in options) DropdownMenuItem<String?>(value: id, child: Text(text))],
      onChanged: onPicked,
    ),
  );
}
