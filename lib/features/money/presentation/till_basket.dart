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
import '../domain/till_offline.dart';
import 'till_card_panel.dart';
import 'till_offline_mode.dart';
import 'till_offline_panel.dart';
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
    required this.onConfirm,
    this.offline = const TillOfflineStatus(),
    this.onSendOffline,
    this.onDiscardOffline,
    this.onReceipt,
    this.onCard,
    this.onCardAnswer,
  });

  final TillState state;
  final void Function(int index) onQuantity;
  final void Function(int index) onRemove;
  final VoidCallback onPay;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onConfirm;

  /// #4373 -- what the till says of selling offline, and what its two actions do.
  final TillOfflineStatus offline;
  final VoidCallback? onSendOffline;
  final VoidCallback? onDiscardOffline;
  /// #4184 -- opens the frozen document of the sale just made.
  final void Function(String receiptId)? onReceipt;

  /// #4185 -- asks the terminal for the total by card; null where the till takes no card.
  final VoidCallback? onCard;

  /// #4185 -- records the terminal's answer to the card asked: `accepted`, `refused` or `unknown`.
  final void Function(String outcome)? onCardAnswer;

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
        // the banner and the title scroll with the lines: only the footer is fixed, so a short phone basket never overflows
        Expanded(
          child: ListView(
            children: [
              TillOfflinePanel(status: offline, onSend: onSendOffline, onDiscard: onDiscardOffline),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                child: Text(l10n.tillBasketTitle, style: theme.textTheme.titleMedium),
              ),
              if (state.empty)
                Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(l10n.tillBasketEmpty, textAlign: TextAlign.center))
              else
                for (var i = 0; i < state.lines.length; i++)
                  _Line(
                    line: state.lines[i],
                    priced: draft != null && i < draft.lines.length ? draft.lines[i] : null,
                    tracks: sold?.tracksOf(i + 1) ?? const [],
                    money: money,
                    onQuantity: sold == null && !state.unconfirmed ? () => onQuantity(i) : null,
                    onRemove: sold == null && !state.unconfirmed ? () => onRemove(i) : null,
                  ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _bottom(sold, money),
        ),
      ],
    );
  }

  /// What the fixed bottom of the basket shows: the sale made, its answer awaited, the card asked, or the footer to pay.
  Widget _bottom(TillSold? sold, MoneyFormat money) => sold != null
                ? _Sold(
                    sold: sold,
                    change: state.change,
                    money: money,
                    offlineSale: offline.sale,
                    onNext: state.busy ? null : onNext,
                    // a sale recorded offline has no frozen document until the server has received it
                    onReceipt: onReceipt == null || offline.sale != null ? null : () => onReceipt!(sold.receiptId),
                  )
                : state.unconfirmed
                ? _Unconfirmed(state: state, onConfirm: onConfirm)
                : state.card != null
                ? TillCardPanel(state: state, money: money, onAnswer: onCardAnswer, onNext: onNext)
                : _Footer(state: state, money: money, offline: offline.active, onPay: onPay, onRetry: onRetry, onCard: offline.active ? null : onCard);
}

class _Line extends StatelessWidget {
  const _Line({required this.line, required this.priced, required this.money, required this.onQuantity, required this.onRemove, this.tracks = const []});

  final TillLine line;
  final TillPricedLine? priced;

  /// #4436 -- the track IDs the line took, once sold: the lots with their quantities, the pieces by their tags.
  final List<TillTrack> tracks;
  final MoneyFormat money;
  final VoidCallback? onQuantity;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      key: ValueKey('till-line-${line.itemId}'),
      title: Text(line.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: tracks.isEmpty
          ? Text('${line.quantity} ${line.unit}'.trim())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${line.quantity} ${line.unit}'.trim()),
                Text(tillTracksText(l10n, tracks), key: ValueKey('till-tracks-${line.itemId}')),
              ],
            ),
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

/// The sale was sent and its answer did not come: only confirming it is offered, so it is never made twice.
class _Unconfirmed extends StatelessWidget {
  const _Unconfirmed({required this.state, required this.onConfirm});

  final TillState state;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final problem = state.problem;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (problem != null) Text(tillProblemText(l10n, problem), key: const ValueKey('till-problem'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const FormGap(),
        FilledButton(
          key: const ValueKey('till-confirm'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: state.busy ? null : onConfirm,
          child: Text(l10n.tillConfirmSale),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.money, required this.offline, required this.onPay, required this.onRetry, required this.onCard});

  final TillState state;
  final MoneyFormat money;

  /// Selling offline: the tax is not split on the device, so it is not shown.
  final bool offline;
  final VoidCallback onPay;
  final VoidCallback onRetry;
  final VoidCallback? onCard;

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
          if (!offline) Text(l10n.tillTaxIncluded(money.formatMinor(draft.totals.taxMinor))),
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
        if (onCard != null) ...[
          const FormGap.small(),
          OutlinedButton(
            key: const ValueKey('till-pay-card'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: draft == null || state.busy ? null : onCard,
            child: Text(l10n.counterSalePayCard),
          ),
        ],
      ],
    );
  }
}

class _Sold extends StatelessWidget {
  const _Sold({required this.sold, required this.change, required this.money, required this.offlineSale, required this.onNext, this.onReceipt});

  final TillSold sold;

  /// The sale as the device recorded it, when it was made offline: it has no receipt number yet.
  final OfflineSale? offlineSale;
  final int? change;
  final MoneyFormat money;
  final VoidCallback? onNext;
  final VoidCallback? onReceipt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.tillSoldTitle, style: theme.textTheme.titleLarge),
        if (offlineSale case final sale?) ...[
          Text(l10n.tillOfflineRecorded(sale.seq), key: const ValueKey('till-offline-receipt')),
          Text(l10n.tillOfflineNotSigned, key: const ValueKey('till-offline-not-signed')),
        ] else
          Text(l10n.tillReceiptNumber(sold.number), key: const ValueKey('till-receipt')),
        Text(l10n.tillTotalDue(money.formatMinor(sold.totals.grossMinor))),
        if (change != null && change! > 0)
          Text(l10n.tillChangeDue(money.formatMinor(change!)), key: const ValueKey('till-change'), style: theme.textTheme.titleMedium),
        if (onReceipt != null)
          TextButton.icon(
            key: const ValueKey('till-show-receipt'),
            icon: const Icon(Icons.receipt_long),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: onReceipt,
            label: Text(l10n.tillReceiptShow),
          ),
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
