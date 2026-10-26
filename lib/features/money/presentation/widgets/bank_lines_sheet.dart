// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — the movements of one statement, the work list of a person who
// reconciles: each with where it stands and, for money in still open, the
// invoice it most likely settles and why. The movements whose structured
// reference names one invoice for exactly what it owes are confirmed in
// one press; every other one by itself.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/bank/bank_match.dart';
import '../../domain/bank/bank_records.dart';
import '../../domain/invoice.dart';
import '../../providers/bank_statement_providers.dart';
import '../../providers/money_providers.dart';
import '../bank_labels.dart';
import 'bank_line_dialogs.dart';

@visibleForTesting
class BankLinesView extends ConsumerWidget {
  const BankLinesView({
    required this.workspaceId,
    required this.statement,
    super.key,
  });

  final String workspaceId;
  final StoredBankStatement statement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lines = ref.watch(bankStatementLinesProvider(statement.id));
    final window = ref.watch(bankImportSettingsProvider).matchWindowDays;
    final open = openInvoices(
      ref.watch(invoicesProvider).value ?? const <Invoice>[],
      ref.watch(invoiceMatchesProvider).value ?? const {},
    );
    return SheetShell(
      title: statement.account,
      children: [
        lines.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(
            l10n.bankStatementsLoadFailed,
            key: const ValueKey('bank-lines-failed'),
          ),
          data: (all) {
            final byReference = [
              for (final l in all)
                if (referenceMatchOf(l, open, windowDays: window) != null) l,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (byReference.isNotEmpty) ...[
                  FilledButton.icon(
                    key: const ValueKey('bank-confirm-references'),
                    onPressed: () => _confirmAll(context, ref, byReference, open, window),
                    icon: const Icon(Icons.done_all),
                    label: Text(l10n.bankConfirmReferences(byReference.length)),
                  ),
                  const FormGap(),
                ],
                for (final line in all)
                  _LineTile(
                    key: ValueKey('bank-line-${line.id}'),
                    line: line,
                    suggestions: suggestMatches(line, open, windowDays: window),
                    onTap: () => _decide(context, ref, line, open, window),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _changed(WidgetRef ref) => ref
    ..invalidate(bankStatementLinesProvider(statement.id))
    ..invalidate(bankStatementsProvider(workspaceId))
    ..invalidate(invoiceMatchesProvider)
    ..invalidate(invoicesProvider);

  Future<void> _confirmAll(
    BuildContext context,
    WidgetRef ref,
    List<StoredBankLine> lines,
    List<OpenInvoice> open,
    int window,
  ) async {
    final l10n = context.l10n;
    var confirmed = 0;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'bank reference matches failed',
      errorText: l10n.bankMatchFailed,
      action: () async => confirmed = await ref
          .read(bankImportCommandsProvider)
          .confirmReferenceMatches(lines, open, windowDays: window),
    );
    _changed(ref);
    if (!ok || !context.mounted) return;
    AppSnack.success(context, l10n.bankConfirmedReferences(confirmed));
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    StoredBankLine line,
    List<OpenInvoice> open,
    int window,
  ) async {
    final l10n = context.l10n;
    final commands = ref.read(bankImportCommandsProvider);
    Future<void> Function()? action;
    switch (line.status) {
      case BankLineStatus.review:
        final duplicate = await showBankReviewDialog(context);
        if (duplicate == null) return;
        action = () => commands.review(line, duplicate: duplicate);
      case BankLineStatus.open || BankLineStatus.recorded when line.isMoneyIn:
        final suggestions = suggestMatches(line, open, windowDays: window);
        final suggested = {for (final s in suggestions) s.invoice.id};
        final choice = await showDialog<BankMatchChoice>(
          context: context,
          builder: (_) => BankMatchDialog(
            line: line,
            suggestions: suggestions,
            others: [
              for (final i in open)
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
        action = () => commands.reconcileOut(line, outgoingPaymentId: paymentId);
      case BankLineStatus.duplicate ||
          BankLineStatus.recorded ||
          BankLineStatus.pending ||
          BankLineStatus.matched ||
          BankLineStatus.reconciled:
        return;
    }
    if (!context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'bank line decision failed',
      errorText: l10n.bankMatchFailed,
      action: action,
    );
    _changed(ref);
    if (!ok || !context.mounted) return;
    AppSnack.success(context, l10n.bankLineSaved);
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.suggestions,
    required this.onTap,
    super.key,
  });

  final StoredBankLine line;
  final List<BankMatchSuggestion> suggestions;
  final VoidCallback onTap;

  bool get _actionable =>
      line.status == BankLineStatus.review ||
      (line.status == BankLineStatus.open) ||
      (line.status == BankLineStatus.recorded && line.isMoneyIn);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = moneyFormat(line.currency);
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final what = [
      if (line.counterpartyName.isNotEmpty) line.counterpartyName,
      if (line.reference.isNotEmpty) line.reference
      else if (line.remittance.isNotEmpty) line.remittance,
    ].join(' · ');
    final best = suggestions.firstOrNull;
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
      title: Text('${money.formatMinor(line.amountCents)} · ${day.format(line.valueDate)}'),
      subtitle: Text(what.isEmpty ? status : '$what\n$status'),
      isThreeLine: what.isNotEmpty,
      trailing: _actionable ? const Icon(Icons.chevron_right) : null,
      onTap: _actionable ? onTap : null,
    );
  }
}
