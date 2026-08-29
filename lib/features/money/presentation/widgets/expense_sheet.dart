// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../../core/format/cents.dart';
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

  final amount = TextEditingController();
  final description = TextEditingController();
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
  final supplyName = TextEditingController();
  final supplyQty = TextEditingController(text: '1');
  final supplyUnit = TextEditingController();
  void prefillUnit() {
    final cents = parseCentsInput(amount.text) ?? 0;
    final qty = int.tryParse(supplyQty.text) ?? 0;
    if (cents > 0 && qty > 0) {
      supplyUnit.text = ((cents + qty - 1) ~/ qty / 100).toStringAsFixed(2);
    }
  }
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SheetShell(
        title: l10n?.moneySubmitExpense ?? 'Submit an expense',
        children: [
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
            if (suppliesOn) ...[
              SwitchListTile(
                key: const ValueKey('expense-supply-toggle'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n?.expenseSupplyToggle ??
                    'This is a supply for the space'),
                subtitle: Text(l10n?.expenseSupplyHint ??
                    'Coffee capsules, vacuum bags… Once validated, the '
                        'item goes on the shelf as a consumable service: '
                        'members who use it pay for it.'),
                value: isSupply,
                onChanged: (v) => setSheetState(() {
                  isSupply = v;
                  if (v) prefillUnit();
                }),
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
                  onChanged: (v) => setSheetState(() => supplyItem = v),
                ),
                if (supplyItem == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('expense-supply-name'),
                    controller: supplyName,
                    decoration: InputDecoration(
                      labelText: l10n?.expenseSupplyNewItem ?? 'New item',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('expense-supply-quantity'),
                      controller: supplyQty,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n?.expenseSupplyQuantity ?? 'Quantity',
                      ),
                      onChanged: (_) => setSheetState(prefillUnit),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('expense-supply-unit'),
                      controller: supplyUnit,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n?.expenseSupplyUnitPrice ??
                            'Unit price (what a consumption costs)',
                        suffixText: currency.currencyName,
                        helperText: l10n?.expenseSupplyUnitPriceHint ??
                            'Prefilled from amount ÷ quantity; round up '
                                'if you like.',
                        helperMaxLines: 2,
                      ),
                    ),
                  ),
                ]),
              ],
            ],
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
  if (submitted != true || !context.mounted) return;

  final cents = parseCentsInput(amount.text);
  if (cents == null || cents <= 0) return;
  final qty = int.tryParse(supplyQty.text) ?? 0;
  final supply = !isSupply
      ? null
      : <String, Object?>{
          if (supplyItem != null) 'service_id': supplyItem!.id,
          'name': supplyItem?.name ?? supplyName.text.trim(),
          'quantity': qty,
          'unit_price_cents': parseCentsInput(supplyUnit.text),
        };
  if (supply != null &&
      (qty < 1 || (supply['name'] as String).isEmpty)) {
    return;
  }
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'submit expense failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref.read(moneyRepositoryProvider).submitExpense(
          workspaceId: workspace.id,
          amountCents: cents,
          category: category,
          description: description.text.trim(),
          supply: supply,
        ),
  )) {
    return;
  }
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n?.moneyExpensePending ??
        'Expense submitted — waiting for approval.',
  );
  ref.invalidate(eventsProvider);
}

