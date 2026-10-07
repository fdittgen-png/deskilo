// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../../core/format/cents.dart';
import '../../application/submit_expense.dart';
import '../../domain/service_item.dart';
import '../../providers/money_providers.dart';

Future<void> showExpenseSheet(
  BuildContext context,
  WidgetRef ref,
  MoneyFormat currency,
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

  // The form's text, created on demand and disposed with the sheet.
  final fields = FormControllers({'supplyQuantity': '1'});
  var category = categories.first;
  // #731 — a supply for the space: name (or an existing item), how
  // many, what a consumption will cost.
  final suppliesOn = ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.supplyExpenses);
  final existing = suppliesOn
      ? (ref.read(servicesProvider).value ?? const <ServiceItem>[])
      : const <ServiceItem>[];
  var isSupply = false;
  ServiceItem? supplyItem;
  void prefillUnit() {
    final cents = parseCentsInput(fields['amount'].text) ?? 0;
    final qty = int.tryParse(fields['supplyQuantity'].text) ?? 0;
    if (cents > 0 && qty > 0) {
      fields['supplyUnit'].text = centsToMajor((cents + qty - 1) ~/ qty); // #1140
    }
  }

  ExpenseDraft draft() => ExpenseDraft(
    amount: fields['amount'].text,
    category: category,
    description: fields['description'].text,
    isSupply: isSupply,
    supplyItemId: supplyItem?.id,
    supplyItemName: supplyItem?.name,
    supplyName: fields['supplyName'].text,
    supplyQuantity: fields['supplyQuantity'].text,
    supplyUnitPrice: fields['supplyUnit'].text,
  );
  // #1449 — the reason the typed expense cannot be filed, shown in the
  // sheet; the sheet only closes on a draft the rules accept.
  String? reason(ExpenseOutcome outcome) => switch (outcome) {
    ExpenseOutcome.submitted => null,
    ExpenseOutcome.invalidAmount =>
      l10n?.expenseInvalidAmount ?? 'Enter an amount above zero.',
    ExpenseOutcome.missingSupplyName =>
      l10n?.expenseMissingSupplyName ?? 'Name the new item.',
    ExpenseOutcome.invalidSupplyQuantity =>
      l10n?.expenseInvalidSupplyQuantity ?? 'Enter at least one unit.',
    ExpenseOutcome.invalidUnitPrice =>
      l10n?.expenseInvalidUnitPrice ??
          'Enter a valid unit price, or leave it empty.',
  };
  final failed =
      l10n?.workspaceGenericError ??
      'Something went wrong. Please try again.';

  final submitted = await showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n?.moneySubmitExpense ?? 'Submit an expense',
      submitLabel: l10n?.moneySubmitPayment ?? 'Submit for confirmation',
      submitKey: const ValueKey('expense-submit'),
      errorKey: const ValueKey('expense-problem'),
      onDispose: fields.dispose,
      onSubmit: () async {
        final why = reason(expenseOutcome(draft()));
        if (why != null) return why;
        try {
          final outcome = await ref
              .read(expensesProvider)
              .submit(workspace.id, draft());
          return reason(outcome);
        } catch (e, st) {
          TraceLogger.instance.warn(
            'money',
            'submit expense failed',
            error: e,
            stackTrace: st,
          );
          return failed;
        }
      },
      builder: (context, refresh) => [
        AppTextField(
          controller: fields['amount'],
          label: l10n?.moneyAmountLabel ?? 'Amount',
          suffixText: currency.currencyName,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        const FormGap(),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: InputDecoration(
            labelText: l10n?.moneyExpenseCategoryLabel ?? 'Category',
          ),
          items: [
            for (final key in categories)
              DropdownMenuItem(value: key, child: Text(categoryLabel(key))),
          ],
          onChanged: (v) {
            category = v ?? category;
            refresh();
          },
        ),
        const FormGap(),
        AppTextField(
          controller: fields['description'],
          label: l10n?.moneyDescriptionLabel ?? 'Description',
        ),
        if (suppliesOn) ...[
          SwitchListTile(
            key: const ValueKey('expense-supply-toggle'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n?.expenseSupplyToggle ?? 'This is a supply for the space',
            ),
            subtitle: Text(
              l10n?.expenseSupplyHint ??
                  'Coffee capsules, vacuum bags… Once validated, the '
                      'item goes on the shelf as a consumable service: '
                      'members who use it pay for it.',
            ),
            value: isSupply,
            onChanged: (v) {
              isSupply = v;
              if (v) prefillUnit();
              refresh();
            },
          ),
          if (isSupply) ...[
            DropdownButtonFormField<ServiceItem?>(
              key: const ValueKey('expense-supply-item'),
              initialValue: supplyItem,
              decoration: InputDecoration(
                labelText: l10n?.expenseSupplyItem ?? 'Item',
              ),
              items: [
                DropdownMenuItem<ServiceItem?>(
                  value: null,
                  child: Text(l10n?.expenseSupplyNewItem ?? 'New item'),
                ),
                for (final item in existing)
                  DropdownMenuItem<ServiceItem?>(
                    value: item,
                    child: Text(item.name),
                  ),
              ],
              onChanged: (v) {
                supplyItem = v;
                refresh();
              },
            ),
            if (supplyItem == null) ...[
              const FormGap(),
              AppTextField(
                key: const ValueKey('expense-supply-name'),
                controller: fields['supplyName'],
                label: l10n?.expenseSupplyNewItem ?? 'New item',
              ),
            ],
            const FormGap(),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    key: const ValueKey('expense-supply-quantity'),
                    controller: fields['supplyQuantity'],
                    keyboardType: TextInputType.number,
                    label: l10n?.expenseSupplyQuantity ?? 'Quantity',
                    onChanged: (_) {
                      prefillUnit();
                      refresh();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    key: const ValueKey('expense-supply-unit'),
                    controller: fields['supplyUnit'],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    label:
                        l10n?.expenseSupplyUnitPrice ??
                        'Unit price (what a consumption costs)',
                    suffixText: currency.currencyName,
                    helper:
                        l10n?.expenseSupplyUnitPriceHint ??
                        'Prefilled from amount ÷ quantity; round up '
                            'if you like.',
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    ),
  );
  if (!submitted || !context.mounted) return;
  AppSnack.success(
    context,
    l10n?.moneyExpensePending ?? 'Expense submitted — waiting for approval.',
  );
  ref.invalidate(eventsProvider);
}
