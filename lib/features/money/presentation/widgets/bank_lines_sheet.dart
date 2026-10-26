// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — the movements of one statement, the work list of a person who
// reconciles: each with where it stands and, for money in still open, the
// invoice it most likely settles and why, matched once per load. The
// movements whose structured reference names one invoice for exactly what
// it owes are confirmed in one press; every other one by itself. While a
// decision is sent nothing else can be pressed; a reader who may not match
// or reconcile sees the list and no door.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/bank/bank_match.dart';
import '../../domain/bank/bank_records.dart';
import '../../providers/bank_statement_providers.dart';
import '../../providers/money_providers.dart';
import '../bank_labels.dart';
import 'bank_line_dialogs.dart';

/// The share of the screen's height the work list sheet takes: room for a
/// long list that scrolls within it.
const double _sheetHeightShare = 0.85;

@visibleForTesting
class BankLinesView extends ConsumerStatefulWidget {
  const BankLinesView({
    required this.workspaceId,
    required this.statement,
    required this.canMatch,
    required this.canReconcile,
    super.key,
  });

  final String workspaceId;
  final StoredBankStatement statement;

  /// The person may match money in (issueInvoices).
  final bool canMatch;

  /// The person may reconcile money out (recordOutgoingPayments).
  final bool canReconcile;

  @override
  ConsumerState<BankLinesView> createState() => _BankLinesViewState();
}

class _BankLinesViewState extends ConsumerState<BankLinesView> {
  bool _busy = false;

  String get _statementId => widget.statement.id;

  void _changed() => ref
    ..invalidate(bankStatementLinesProvider(_statementId))
    ..invalidate(bankStatementsProvider(widget.workspaceId))
    ..invalidate(invoiceMatchesProvider)
    ..invalidate(invoicesProvider);

  /// Runs [send] with every control disabled, then reloads the list.
  Future<bool> _guarded(String message, Future<void> Function() send) async {
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: message,
      errorText: context.l10n.bankMatchFailed,
      action: send,
    );
    if (!mounted) return ok;
    _changed();
    if (mounted) setState(() => _busy = false);
    return ok;
  }

  Future<void> _confirmAll(BankWorkList list) async {
    var confirmed = 0;
    final ok = await _guarded(
      'bank reference matches failed',
      () async => confirmed = await ref
          .read(bankImportCommandsProvider)
          .confirmReferenceMatches(list),
    );
    if (!ok || !mounted) return;
    AppSnack.success(context, context.l10n.bankConfirmedReferences(confirmed));
  }

  bool _actionable(StoredBankLine line) => switch (line.status) {
    BankLineStatus.review => widget.canMatch,
    BankLineStatus.open =>
      line.isMoneyIn ? widget.canMatch : widget.canReconcile,
    BankLineStatus.recorded => line.isMoneyIn && widget.canMatch,
    _ => false,
  };

  Future<void> _decide(BankWorkList list, BankWorkItem item) async {
    final line = item.line;
    final commands = ref.read(bankImportCommandsProvider);
    Future<void> Function()? action;
    switch (line.status) {
      case BankLineStatus.review:
        final duplicate = await showBankReviewDialog(context);
        if (duplicate == null) return;
        action = () => commands.review(line, duplicate: duplicate);
      case BankLineStatus.open || BankLineStatus.recorded when line.isMoneyIn:
        final suggested = {for (final s in item.suggestions) s.invoice.id};
        final choice = await showDialog<BankMatchChoice>(
          context: context,
          builder: (_) => BankMatchDialog(
            line: line,
            suggestions: item.suggestions,
            others: [
              for (final i in list.open)
                if (i.currency == line.currency && !suggested.contains(i.id)) i,
            ],
          ),
        );
        if (choice == null) return;
        action = () => commands.confirm(
          line,
          invoiceId: choice.invoice.id,
          dueCents: choice.invoice.dueCents,
          overResolution: choice.overResolution,
          note: choice.note,
        );
      case BankLineStatus.open:
        final paymentId = await showBankOutDialog(context, line);
        if (paymentId == null) return;
        action = () =>
            commands.reconcileOut(line, outgoingPaymentId: paymentId);
      case BankLineStatus.duplicate ||
          BankLineStatus.recorded ||
          BankLineStatus.pending ||
          BankLineStatus.matched ||
          BankLineStatus.reconciled:
        return;
    }
    if (!mounted) return;
    final ok = await _guarded('bank line decision failed', action);
    if (!ok || !mounted) return;
    AppSnack.success(context, context.l10n.bankLineSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final work = ref.watch(bankWorkListProvider(_statementId));
    final height = MediaQuery.sizeOf(context).height * _sheetHeightShare;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.statement.account,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SheetCloseButton(key: ValueKey('sheet-close')),
              ],
            ),
            Expanded(
              child: work.when(
                loading: () => const LoadingView(),
                error: (_, _) => Text(
                  l10n.bankStatementsLoadFailed,
                  key: const ValueKey('bank-lines-failed'),
                ),
                data: _list,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BankWorkList list) {
    final l10n = context.l10n;
    final batch = widget.canMatch
        ? list.referenceBatch
        : const <BankWorkItem>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (batch.isNotEmpty) ...[
          FilledButton.icon(
            key: const ValueKey('bank-confirm-references'),
            onPressed: _busy ? null : () => _confirmAll(list),
            icon: const Icon(Icons.done_all),
            label: Text(l10n.bankConfirmReferences(batch.length)),
          ),
          const FormGap(),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: list.items.length,
            itemBuilder: (_, i) {
              final item = list.items[i];
              final open = !_busy && _actionable(item.line);
              return _LineTile(
                key: ValueKey('bank-line-${item.line.id}'),
                item: item,
                onTap: open ? () => _decide(list, item) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.item, required this.onTap, super.key});

  final BankWorkItem item;

  /// Null when the movement waits for nobody, or for someone else.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final line = item.line;
    final money = moneyFormat(line.currency);
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final what = [
      if (line.counterpartyName.isNotEmpty) line.counterpartyName,
      if (line.reference.isNotEmpty)
        line.reference
      else if (line.remittance.isNotEmpty)
        line.remittance,
    ].join(' · ');
    final best = item.suggestions.firstOrNull;
    final status = best == null || !line.status.isOpen
        ? bankLineStatusLabel(l10n, line)
        : l10n.bankLineSuggested(
            best.invoice.number,
            bankMatchBasisLabel(l10n, best.basis),
          );
    return ListTile(
      key: ValueKey('bank-line-tile-${line.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(line.isMoneyIn ? Icons.south_west : Icons.north_east),
      title: Text(
        '${money.formatMinor(line.amountCents)} · ${day.format(line.valueDate)}',
      ),
      subtitle: Text(what.isEmpty ? status : '$what\n$status'),
      isThreeLine: what.isNotEmpty,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
