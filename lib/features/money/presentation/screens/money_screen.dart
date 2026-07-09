// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/ledger_entry.dart';
import '../../providers/money_providers.dart';
import '../widgets/bill_view.dart';
import '../widgets/consumption_sheet.dart';

/// Money tab (spec §7.3, #132): a structured monthly bill per period —
/// subscription, consumed services, open positions awaiting validation,
/// payments & credits, balance — plus payment/expense/consumption actions.
/// Amounts render in the workspace currency.
class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  /// First day of the visible month; the bill shows this period.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  String get _period => DateFormat('yyyy-MM').format(_month);

  bool get _isCurrentPeriod => _period == currentPeriod();

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  Future<void> _recordPaymentSheet(NumberFormat currency) async {
    final context = this.context;
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

  Future<void> _submitExpenseSheet(NumberFormat currency) async {
    final context = this.context;
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final member = ref.watch(myMemberProvider).value;
    final statementAsync = ref.watch(myStatementProvider(_period));
    final ledger = ref.watch(myLedgerProvider).value ?? const <LedgerEntry>[];
    final pendingEvents = ref.watch(eventsProvider).value ?? const [];
    final currencyCode = workspace?.currencyCode ?? 'EUR';
    final currency = NumberFormat.simpleCurrency(name: currencyCode);
    final monthLabel = DateFormat.yMMMM(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format(_month);

    final periodHeader = Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _shiftMonth(-1),
        ),
        Expanded(
          child: Text(
            monthLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _isCurrentPeriod ? null : () => _shiftMonth(1),
        ),
      ],
    );

    return switch (statementAsync) {
      AsyncData(value: final statement) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            periodHeader,
            if (statement != null)
              BillView(
                statement: statement,
                ledger: ledger,
                pendingMoneyEvents: pendingEvents,
                currencyCode: currencyCode,
                memberId: member?.id ?? '',
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _recordPaymentSheet(currency),
              icon: const Icon(Icons.payments_outlined),
              label: Text(l10n?.moneyRecordPayment ?? 'Record a payment'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _submitExpenseSheet(currency),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(l10n?.moneySubmitExpense ?? 'Submit an expense'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                final me = ref.read(myMemberProvider).value;
                if (me == null) return;
                showConsumptionSheet(
                  context,
                  ref,
                  subjectMemberId: me.id,
                );
              },
              icon: const Icon(Icons.room_service_outlined),
              label: Text(l10n?.consumptionAdd ?? 'Add consumption'),
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
