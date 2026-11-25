// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till's keys as its published layout places them. A till without a published layout, or a business
// without till layouts, keeps the generated keys of #4366 unchanged. An item key whose item is no longer sold is shown
// "No longer for sale" and disabled: never a crash, and the rest of the sale goes on. The layout is read once per till
// screen, so a layout published during a sale reaches the till at its next session.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/decimal_input.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../domain/counter_till.dart';
import '../../domain/till_keypad.dart';
import '../../domain/till_layout.dart';
import '../../providers/till_layout_providers.dart';
import '../../providers/till_providers.dart';
import '../counter_receipt_view.dart';
import '../till_keys.dart';
import '../till_session.dart';
import '../till_text.dart';
import 'till_layout_tools.dart';
import 'till_layout_words.dart';
import 'till_price_dialogs.dart';

/// The height of one row of a laid-out till.
const double _rowHeight = 72;

class TillKeysOrLayout extends ConsumerWidget {
  const TillKeysOrLayout({
    super.key,
    required this.workspaceId,
    required this.tillId,
    required this.items,
    required this.session,
    required this.onTap,
    required this.onPayCash,
  });

  final String workspaceId;
  final String? tillId;
  final AsyncValue<List<TillKey>> items;

  /// The till's own commands: the card, the next customer, a line taken out or given a quantity.
  final TillSession session;

  /// An item key: rung up like a generated key, with the quantity typed on the keypad when there is one.
  final void Function(TillKey key, String? typed) onTap;
  final VoidCallback onPayCash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generated = TillKeys(key: const ValueKey('till-keys'), items: items, onTap: (k) => onTap(k, null));
    final till = tillId;
    if (till == null || !ref.watch(tillLayoutsOnProvider)) return generated;
    final layout = ref.watch(tillPublishedLayoutProvider((workspaceId: workspaceId, tillId: till))).value;
    final sold = items.value;
    // no layout, or the items not read yet (or not readable): the generated keys say so in their own way
    if (layout == null || layout.pages.isEmpty || sold == null) return generated;
    return _LaidOut(
      key: const ValueKey('till-layout-laid-out'),
      layout: layout,
      items: sold,
      session: session,
      copies: ref.watch(tillCopyPortProvider),
      onTap: onTap,
      onPayCash: onPayCash,
    );
  }
}

class _LaidOut extends StatefulWidget {
  const _LaidOut({
    super.key,
    required this.layout,
    required this.items,
    required this.session,
    required this.copies,
    required this.onTap,
    required this.onPayCash,
  });

  final TillLayout layout;
  final List<TillKey> items;
  final TillSession session;

  /// #4476 -- where the till prints copies of a receipt; null where it does not.
  final TillCopyPort? copies;
  final void Function(TillKey key, String? typed) onTap;
  final VoidCallback onPayCash;

  @override
  State<_LaidOut> createState() => _LaidOutState();
}

class _LaidOutState extends State<_LaidOut> {
  int _page = 0;

  /// What the keypad has typed: the quantity of the next item key, or of the last line with Quantity ×.
  final _typed = ValueNotifier(const TillKeypadEntry());

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  int get _last => widget.session.state.value.lines.length - 1;

  /// [quantity] onto the basket's last line; nothing when the basket is empty.
  void _onLast(String quantity) {
    if (_last >= 0) unawaited(widget.session.setQuantity(_last, quantity));
  }

  void _item(TillKey item) {
    final typed = _typed.value;
    _typed.value = const TillKeypadEntry();
    widget.onTap(item, typed.isEmpty ? null : typed.text);
  }

  VoidCallback? _function(TillFunction f) => switch (f) {
    TillFunction.payCash => widget.onPayCash,
    TillFunction.payCard => () => unawaited(widget.session.payCard()),
    TillFunction.nextCustomer => widget.session.next,
    TillFunction.voidLine => () {
      if (_last >= 0) unawaited(widget.session.remove(_last));
    },
    TillFunction.quantityTimes => () {
      final typed = _typed.value;
      _typed.value = const TillKeypadEntry();
      if (!typed.isEmpty) _onLast(typed.text);
    },
    TillFunction.priceOverride => () => unawaited(_pricing(discount: false)),
    TillFunction.lineDiscount => () => unawaited(_pricing(discount: true)),
    TillFunction.reprintLast => () => unawaited(_reprint()),
    // a deposit return comes with #4476's next step; the drawer opens with the receipt printer and its pulse (#4368)
    _ => null,
  };

  /// #4476 -- the last sale's receipt again, counted by the server as its next copy and shown marked as that copy.
  Future<void> _reprint() async {
    final l10n = context.l10n;
    final receipt = widget.session.lastSold;
    final copies = widget.copies;
    if (receipt == null || copies == null) {
      AppSnack.info(context, l10n.tillNothingToReprint);
      return;
    }
    try {
      final n = await copies.copy(widget.session.workspaceId, requestId: newRequestId(), receiptId: receipt);
      if (!mounted) return;
      await showCounterReceiptSheet(context, workspaceId: widget.session.workspaceId, receiptId: receipt, copy: n);
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'a receipt copy was not printed', error: e, stackTrace: st);
      if (mounted) AppSnack.error(context, tillProblemText(l10n, e));
    }
  }

  /// #4476 -- the last line at another price with its reason, or with a discount: the keypad's number is the start.
  Future<void> _pricing({required bool discount}) async {
    if (_last < 0) {
      AppSnack.info(context, context.l10n.tillRingUpFirst);
      return;
    }
    final index = _last;
    final line = widget.session.state.value.lines[index];
    final typed = _typed.value.isEmpty ? null : _typed.value.text;
    _typed.value = const TillKeypadEntry();
    if (discount) {
      final percent = await showTillDiscountDialog(context, line, typed: typed);
      if (percent != null) await widget.session.setPricing(index, discount: percent);
    } else {
      final set = await showTillPriceDialog(context, line, typed: typed);
      if (set != null) await widget.session.setPricing(index, price: set.price, reason: set.reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.layout.pages;
    return LayoutBuilder(
      builder: (context, box) {
        final grids = pages[_page].grids;
        // the size the window reaches, or the largest one the page has below it
        final size = TillLayoutSize.values.reversed.firstWhere(
          (s) => s.width <= TillLayoutSize.forWidth(box.maxWidth).width && grids.containsKey(s),
          orElse: () => grids.keys.first,
        );
        final grid = grids[size]!;
        final colWidth = box.maxWidth / grid.cols;
        return SingleChildScrollView(
          key: const ValueKey('till-layout-keys'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pages.length > 1)
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      ChoiceChip(
                        key: ValueKey('till-layout-tab-$i'),
                        label: Text(pages[i].name),
                        selected: i == _page,
                        onSelected: (_) => setState(() => _page = i),
                      ),
                  ],
                ),
              SizedBox(
                height: grid.rows * _rowHeight,
                child: Stack(
                  children: [
                    for (var i = 0; i < grid.cells.length; i++)
                      Positioned(
                        left: grid.cells[i].col * colWidth,
                        top: grid.cells[i].row * _rowHeight,
                        width: grid.cells[i].colSpan * colWidth - AppSpacing.xs,
                        height: grid.cells[i].rowSpan * _rowHeight - AppSpacing.xs,
                        child: _cell(context, grid.cells[i], i),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(BuildContext context, TillCell c, int i) {
    final l10n = context.l10n;
    final key = ValueKey('till-layout-key-$i');
    switch (c.kind) {
      case TillWidgetKind.itemKey:
        final item = widget.items.where((k) => k.id == c.itemId).firstOrNull;
        if (item == null) {
          return OutlinedButton(key: key, onPressed: null, child: Text('${c.label}\n${l10n.tillLayoutGone}', textAlign: TextAlign.center));
        }
        return FilledButton.tonal(key: key, onPressed: () => _item(item), child: Text(item.name, textAlign: TextAlign.center));
      case TillWidgetKind.categoryKey:
        final target = c.targetPage;
        final opens = target != null && target >= 0 && target < widget.layout.pages.length;
        return FilledButton.tonal(
          key: key,
          onPressed: opens ? () => setState(() => _page = target) : null,
          child: Text(c.label.isEmpty ? tillWidgetName(l10n, c.kind) : c.label, textAlign: TextAlign.center),
        );
      case TillWidgetKind.functionKey:
        final f = c.function!;
        return FilledButton(key: key, onPressed: _function(f), child: Text(tillFunctionName(l10n, f), textAlign: TextAlign.center));
      case TillWidgetKind.keypad:
        return TillKeypadTool(key: key, typed: _typed, separator: decimalSeparatorOf(appFormatOf(context).locale));
      case TillWidgetKind.calculator:
        return TillCalculatorTool(key: key, onQuantity: _onLast);
      default:
        // the basket, its total and the scan field have their place beside the keys
        return Card(key: key, child: Center(child: Text(tillWidgetName(l10n, c.kind), textAlign: TextAlign.center)));
    }
  }
}
