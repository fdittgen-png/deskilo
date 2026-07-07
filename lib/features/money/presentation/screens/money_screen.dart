// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/ledger_entry.dart';
import '../../domain/statement.dart';
import '../../providers/money_providers.dart';

/// Money tab (spec §7.3): current-period statement, payment recording,
/// ledger history. Amounts render in the workspace currency.
class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  String _categoryLabel(AppLocalizations? l10n, LedgerCategory category) {
    return switch (category) {
      LedgerCategory.subscription =>
        l10n?.ledgerCategorySubscription ?? 'Subscription',
      LedgerCategory.overage => l10n?.ledgerCategoryOverage ?? 'Overage',
      LedgerCategory.expense =>
        l10n?.ledgerCategoryExpense ?? 'Expense reimbursement',
      LedgerCategory.payment => l10n?.ledgerCategoryPayment ?? 'Payment',
      LedgerCategory.adjustment =>
        l10n?.ledgerCategoryAdjustment ?? 'Adjustment',
    };
  }

  Future<void> _recordPaymentSheet(
    BuildContext context,
    WidgetRef ref,
    NumberFormat currency,
  ) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final member = ref.read(myMemberProvider).value;
    if (workspace == null || member == null) return;

    final amount = TextEditingController();
    final note = TextEditingController();
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.moneyRecordPayment ?? 'Record a payment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              decoration: InputDecoration(
                labelText: l10n?.moneyAmountLabel ?? 'Amount',
                suffixText: currency.currencyName,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: InputDecoration(
                labelText: l10n?.moneyNoteLabel ?? 'Note (optional)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n?.moneySubmitPayment ?? 'Submit for confirmation',
              ),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;

    final parsed =
        double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    try {
      await ref.read(moneyRepositoryProvider).recordPayment(
            workspaceId: workspace.id,
            memberId: member.id,
            amountCents: (parsed * 100).round(),
            note: note.text.trim(),
          );
    } catch (e, st) {
      debugPrint('record payment failed: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.moneyPaymentPending ??
              'Payment submitted — waiting for confirmation.',
        ),
      ),
    );
    ref.invalidate(eventsProvider);
  }

  Future<void> _submitExpenseSheet(
    BuildContext context,
    WidgetRef ref,
    NumberFormat currency,
  ) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;

    const categories = ['coffee', 'supplies', 'equipment', 'other'];
    String categoryLabel(String key) => switch (key) {
          'coffee' => l10n?.expenseCategoryCoffee ?? 'Coffee & kitchen',
          'supplies' => l10n?.expenseCategorySupplies ?? 'Supplies',
          'equipment' => l10n?.expenseCategoryEquipment ?? 'Equipment',
          _ => l10n?.expenseCategoryOther ?? 'Other',
        };

    final amount = TextEditingController();
    final description = TextEditingController();
    var category = categories.first;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.moneySubmitExpense ?? 'Submit an expense',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                decoration: InputDecoration(
                  labelText: l10n?.moneyAmountLabel ?? 'Amount',
                  suffixText: currency.currencyName,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: l10n?.moneyExpenseCategoryLabel ?? 'Category',
                ),
                items: [
                  for (final key in categories)
                    DropdownMenuItem(
                      value: key,
                      child: Text(categoryLabel(key)),
                    ),
                ],
                onChanged: (v) =>
                    setSheetState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                decoration: InputDecoration(
                  labelText: l10n?.moneyDescriptionLabel ?? 'Description',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  l10n?.moneySubmitPayment ?? 'Submit for confirmation',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (submitted != true) return;

    final parsed =
        double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    try {
      await ref.read(moneyRepositoryProvider).submitExpense(
            workspaceId: workspace.id,
            amountCents: (parsed * 100).round(),
            category: category,
            description: description.text.trim(),
          );
    } catch (e, st) {
      debugPrint('submit expense failed: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.moneyExpensePending ??
              'Expense submitted — waiting for approval.',
        ),
      ),
    );
    ref.invalidate(eventsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final statementAsync = ref.watch(myStatementProvider(currentPeriod()));
    final ledger = ref.watch(myLedgerProvider).value ?? const <LedgerEntry>[];
    final currency = NumberFormat.simpleCurrency(
      name: workspace?.currencyCode ?? 'EUR',
    );
    String money(int cents) => currency.format(cents / 100);

    return switch (statementAsync) {
      AsyncData(value: final statement) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (statement != null)
              _StatementCard(
                statement: statement,
                money: money,
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _recordPaymentSheet(context, ref, currency),
              icon: const Icon(Icons.payments_outlined),
              label: Text(l10n?.moneyRecordPayment ?? 'Record a payment'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _submitExpenseSheet(context, ref, currency),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(l10n?.moneySubmitExpense ?? 'Submit an expense'),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.moneyLedgerHeader ?? 'Ledger',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (ledger.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n?.moneyLedgerEmpty ?? 'No ledger entries yet.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final entry in ledger)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    entry.kind == LedgerKind.credit
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                  ),
                  title: Text(_categoryLabel(l10n, entry.category)),
                  subtitle: Text(
                    entry.description.isEmpty
                        ? DateFormat.yMMMd()
                            .format(entry.createdAt.toLocal())
                        : entry.description,
                  ),
                  trailing: Text(
                    entry.kind == LedgerKind.credit
                        ? '+${money(entry.amountCents)}'
                        : '−${money(entry.amountCents)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
          ],
        ),
      AsyncError() => Center(
          child: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({required this.statement, required this.money});

  final Statement statement;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usage = statement.includedHalfDays == null
        ? (l10n?.moneyUsageUnlimited(statement.usedHalfDays) ??
            '${statement.usedHalfDays} half-days used')
        : (l10n?.moneyUsage(
              statement.usedHalfDays,
              statement.includedHalfDays!,
            ) ??
            '${statement.usedHalfDays} of ${statement.includedHalfDays} '
                'half-days used');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${statement.period} · ${statement.planName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(
                    statement.isSettled
                        ? (l10n?.moneyStatementSettled ?? 'Settled')
                        : (l10n?.moneyStatementOpen ?? 'Open'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _line(
              context,
              l10n?.moneyBaseFee ?? 'Base subscription',
              '−${money(statement.baseFeeCents)}',
            ),
            _line(context, usage, ''),
            if (statement.overageCents > 0)
              _line(
                context,
                l10n?.moneyOverage(statement.extraHalfDays) ??
                    'Overage (${statement.extraHalfDays} extra half-days)',
                '−${money(statement.overageCents)}',
              ),
            _line(
              context,
              l10n?.moneyCredits ?? 'Payments & credits',
              '+${money(statement.creditsCents)}',
            ),
            const Divider(),
            _line(
              context,
              l10n?.moneyBalance ?? 'Balance',
              money(statement.balanceCents),
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    bool emphasized = false,
  }) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
