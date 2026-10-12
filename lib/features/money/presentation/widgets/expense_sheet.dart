// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/submit_expense.dart';
import '../../domain/service_item.dart';
import '../../domain/vat_input.dart';
import '../../domain/vat_rate.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';
import '../vat_tax_point_labels.dart';

Future<void> showExpenseSheet(
  BuildContext context,
  WidgetRef ref,
  MoneyFormat currency,
) async {
  final l10n = context.l10n;
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;

  const categories = ['coffee', 'supplies', 'equipment', 'other'];
  String categoryLabel(String key) => switch (key) {
    'coffee' => l10n.expenseCategoryCoffee,
    'supplies' => l10n.expenseCategorySupplies,
    'equipment' => l10n.expenseCategoryEquipment,
    _ => l10n.expenseCategoryOther,
  };

  // The form's text, created on demand and disposed with the sheet.
  final fields = FormControllers({'supplyQuantity': '1', 'deductible': '100'});
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
  // #2357 — input VAT: the rate the expense carries and the share the
  // space may deduct, asked only of a VAT-registered space.
  var rates = const <VatRate>[];
  if (ref.read(enabledFeaturesSyncProvider).contains(WorkspaceFeature.inputVat) &&
      vatRegimeFromWire(workspace.vatRegime) == VatRegime.vatRegistered) {
    try {
      rates = await ref.read(vatRatesProvider.future);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'expense VAT rates failed',
          error: e, stackTrace: st);
    }
    if (!context.mounted) return;
  }
  final vatPercents = {
    for (final r in rates)
      if (r.active && r.percent > 0) r.percent,
  }.toList()
    ..sort((a, b) => b.compareTo(a));
  double? vatPercent;
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
    vatPercent: vatPercent,
    deductible: fields['deductible'].text,
  );
  // #1449 — the reason the typed expense cannot be filed, shown in the
  // sheet; the sheet only closes on a draft the rules accept.
  String? reason(ExpenseOutcome outcome) => switch (outcome) {
    ExpenseOutcome.submitted => null,
    ExpenseOutcome.invalidAmount =>
      l10n.expenseInvalidAmount,
    ExpenseOutcome.missingSupplyName =>
      l10n.expenseMissingSupplyName,
    ExpenseOutcome.invalidSupplyQuantity =>
      l10n.expenseInvalidSupplyQuantity,
    ExpenseOutcome.invalidUnitPrice =>
      l10n.expenseInvalidUnitPrice,
    ExpenseOutcome.invalidDeductible =>
      vatWords(l10n).expenseInvalidDeductible,
  };
  // The field each refusal is about, so its words sit under that field.
  String? fieldOf(ExpenseOutcome outcome) => switch (outcome) {
    ExpenseOutcome.submitted => null,
    ExpenseOutcome.invalidAmount => 'amount',
    ExpenseOutcome.missingSupplyName => 'supplyName',
    ExpenseOutcome.invalidSupplyQuantity => 'supplyQuantity',
    ExpenseOutcome.invalidUnitPrice => 'supplyUnit',
    ExpenseOutcome.invalidDeductible => 'deductible',
  };
  final failed =
      l10n.workspaceGenericError;

  final submitted = await showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.moneySubmitExpense,
      submitLabel: l10n.moneySubmitPayment,
      submitKey: const ValueKey('expense-submit'),
      errorKey: const ValueKey('expense-problem'),
      onDispose: fields.dispose,
      validate: () {
        final outcome = expenseOutcome(draft());
        final field = fieldOf(outcome);
        return field == null ? const {} : {field: reason(outcome)!};
      },
      onSubmit: () async {
        try {
          final outcome = await ref
              .read(expensesProvider)
              .submit(workspace.id, draft());
          return reason(outcome);
        } on Object catch (e, st) {
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
          fieldKey: 'amount',
          label: l10n.moneyAmountLabel,
          suffixText: currency.currencyName,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        const FormGap(),
        DropdownButtonFormField<String>(
          key: const ValueKey('expense-sheet-money-expense-category-label'),
          initialValue: category,
          decoration: InputDecoration(
            labelText: l10n.moneyExpenseCategoryLabel,
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
          label: l10n.moneyDescriptionLabel,
        ),
        if (vatPercents.isNotEmpty) ...[
          const FormGap(),
          DropdownButtonFormField<double?>(
            key: const ValueKey('expense-vat-rate'),
            initialValue: vatPercent,
            decoration: InputDecoration(
              labelText: vatWords(l10n).expenseVatRate,
            ),
            items: [
              DropdownMenuItem<double?>(
                child: Text(vatWords(l10n).expenseVatNone),
              ),
              for (final p in vatPercents)
                DropdownMenuItem<double?>(
                  value: p,
                  child: Text(_percentLabel(l10n, p)),
                ),
            ],
            onChanged: (v) {
              vatPercent = v;
              refresh();
            },
          ),
          if (vatPercent != null) ...[
            const FormGap(),
            AppTextField(
              key: const ValueKey('expense-vat-deductible'),
              controller: fields['deductible'],
              fieldKey: 'deductible',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              label: vatWords(l10n).expenseVatDeductible,
              helper: _deductibleHelper(
                l10n,
                currency,
                fields['amount'].text,
                vatPercent!,
                fields['deductible'].text,
              ),
              onChanged: (_) => refresh(),
            ),
          ],
        ],
        if (suppliesOn) ...[
          SwitchListTile(
            key: const ValueKey('expense-supply-toggle'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.expenseSupplyToggle,
            ),
            subtitle: Text(
              l10n.expenseSupplyHint,
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
                labelText: l10n.expenseSupplyItem,
              ),
              items: [
                DropdownMenuItem<ServiceItem?>(
                  child: Text(l10n.expenseSupplyNewItem),
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
                fieldKey: 'supplyName',
                label: l10n.expenseSupplyNewItem,
              ),
            ],
            const FormGap(),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    key: const ValueKey('expense-supply-quantity'),
                    controller: fields['supplyQuantity'],
                    fieldKey: 'supplyQuantity',
                    keyboardType: TextInputType.number,
                    label: l10n.expenseSupplyQuantity,
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
                    fieldKey: 'supplyUnit',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    label:
                        l10n.expenseSupplyUnitPrice,
                    suffixText: currency.currencyName,
                    helper:
                        l10n.expenseSupplyUnitPriceHint,
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
    l10n.moneyExpensePending,
  );
  ref.invalidate(eventsProvider);
}

/// « 20 % », in the reader's number format.
String _percentLabel(AppLocalizations l10n, double percent) =>
    '${NumberFormat.decimalPattern(l10n.localeName).format(percent)} %';

/// #2357 — the hint, and once amount and share are typed, the deductible
/// VAT they make (`vatInputSplit`, the server's rounding).
String _deductibleHelper(
  AppLocalizations l10n,
  MoneyFormat currency,
  String amount,
  double percent,
  String share,
) {
  final words = vatWords(l10n);
  final gross = parseCentsInput(amount);
  final pct = double.tryParse(share.trim().replaceAll(',', '.'));
  if (gross == null || gross <= 0 || pct == null || pct < 0 || pct > 100) {
    return words.expenseVatDeductibleHint;
  }
  final split = vatInputSplit(gross, percent, pct);
  return words.expenseVatDeductibleAmount(
    currency.formatMinor(split.deductibleCents),
  );
}
