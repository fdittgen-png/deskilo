// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's basket: the lines with their exact quantity and the price the server gave them, the total, the
// refusal of the last act in words, and the one way on (pay, or the next customer once it is paid).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/i18n/money_format.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/form_kit.dart';
import '../domain/counter_till.dart';
import 'till_session.dart';
import 'till_text.dart';

class TillBasket extends StatelessWidget {
  const TillBasket({
    super.key,
    required this.state,
    required this.onQuantity,
    required this.onRemove,
    required this.onPay,
    required this.onNext,
    required this.onRetry,
  });

  final TillState state;
  final void Function(int index) onQuantity;
  final void Function(int index) onRemove;
  final VoidCallback onPay;
  final VoidCallback onNext;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sold = state.sold;
    final draft = state.draft;
    final theme = Theme.of(context);
    final money = appFormatOf(context).moneyIn(sold?.totals.currency ?? draft?.totals.currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          child: Text(l10n.tillBasketTitle, style: theme.textTheme.titleMedium),
        ),
        Expanded(
          child: state.empty
              ? Center(child: Text(l10n.tillBasketEmpty, textAlign: TextAlign.center))
              : ListView.builder(
                  itemCount: state.lines.length,
                  itemBuilder: (context, i) => _Line(
                    line: state.lines[i],
                    priced: draft != null && i < draft.lines.length ? draft.lines[i] : null,
                    money: money,
                    onQuantity: sold == null ? () => onQuantity(i) : null,
                    onRemove: sold == null ? () => onRemove(i) : null,
                  ),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: sold != null
              ? _Sold(sold: sold, change: state.change, money: money, onNext: onNext)
              : _Footer(state: state, money: money, onPay: onPay, onRetry: onRetry),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line, required this.priced, required this.money, required this.onQuantity, required this.onRemove});

  final TillLine line;
  final TillPricedLine? priced;
  final MoneyFormat money;
  final VoidCallback? onQuantity;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      key: ValueKey('till-line-${line.itemId}'),
      title: Text(line.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${line.quantity} ${line.unit}'.trim()),
      onTap: onQuantity,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (priced != null) Text(money.formatMinor(priced!.grossMinor)),
          IconButton(
            key: ValueKey('till-remove-${line.itemId}'),
            tooltip: l10n.tillRemoveLine(line.name),
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.money, required this.onPay, required this.onRetry});

  final TillState state;
  final MoneyFormat money;
  final VoidCallback onPay;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = state.draft;
    final problem = state.problem;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (draft != null) ...[
          Text(
            l10n.tillTotalDue(money.formatMinor(draft.totals.grossMinor)),
            key: const ValueKey('till-total'),
            style: theme.textTheme.titleLarge,
          ),
          Text(l10n.tillTaxIncluded(money.formatMinor(draft.totals.taxMinor))),
        ] else if (state.busy)
          Text(l10n.tillPricing),
        if (problem != null) ...[
          const FormGap.small(),
          Text(tillProblemText(l10n, problem), key: const ValueKey('till-problem'), style: TextStyle(color: theme.colorScheme.error)),
        ],
        if (draft == null && problem != null && !state.busy && !state.empty) ...[
          const FormGap.small(),
          OutlinedButton(key: const ValueKey('till-reprice'), onPressed: onRetry, child: Text(l10n.tillRetry)),
        ],
        const FormGap(),
        FilledButton(
          key: const ValueKey('till-pay'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: draft == null || state.busy ? null : onPay,
          child: Text(l10n.tillPayCash),
        ),
      ],
    );
  }
}

class _Sold extends StatelessWidget {
  const _Sold({required this.sold, required this.change, required this.money, required this.onNext});

  final TillSold sold;
  final int? change;
  final MoneyFormat money;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.tillSoldTitle, style: theme.textTheme.titleLarge),
        Text(l10n.tillReceiptNumber(sold.number), key: const ValueKey('till-receipt')),
        Text(l10n.tillTotalDue(money.formatMinor(sold.totals.grossMinor))),
        if (change != null && change! > 0)
          Text(l10n.tillChangeDue(money.formatMinor(change!)), key: const ValueKey('till-change'), style: theme.textTheme.titleMedium),
        const FormGap(),
        FilledButton(
          key: const ValueKey('till-next'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: onNext,
          child: Text(l10n.tillNextCustomer),
        ),
      ],
    );
  }
}

/// Asks the quantity of [current]'s line as an exact decimal; answers what was typed, or null when cancelled.
Future<String?> showTillQuantityDialog(BuildContext context, {required TillLine current}) =>
    showDialog<String>(context: context, builder: (_) => _QuantityDialog(current: current));

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.current});

  final TillLine current;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _text = TextEditingController(text: widget.current.quantity);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.current.name),
      content: AppTextField(
        key: const ValueKey('till-quantity'),
        controller: _text,
        label: l10n.tillQuantityTitle,
        helper: l10n.tillQuantityHint,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(key: const ValueKey('till-quantity-cancel'), onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton(
          key: const ValueKey('till-quantity-confirm'),
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
