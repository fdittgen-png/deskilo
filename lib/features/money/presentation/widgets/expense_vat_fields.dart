// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — the VAT an expense carried, asked the same way of a one-off
// expense and of a scheduled one: the rate, the share the space may
// deduct (with the deductible amount it makes, as the server rounds it)
// and whether it bought a fixed asset (CA3 line 19, the Swiss 405, the
// Spanish 30/31). Only a VAT-registered space with input VAT on is asked.
// Where the return has a box for it (the Swiss 383), also whether it was
// bought from a supplier abroad: its amount is then the base, and the space
// owes the acquisition tax on it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/submit_expense.dart';
import '../../domain/vat_form_catalogue.dart';
import '../../domain/vat_input.dart';
import '../../domain/vat_rate.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';
import '../vat_tax_point_labels.dart';

/// What the person chose; [share] is the deductible share as typed.
class ExpenseVatChoice {
  ExpenseVatChoice(this.share, {this.acquisitionOffered = false});

  /// #2360 — the choice for an expense of [workspace]: an acquisition from
  /// abroad is offered only where today's return has a box for the tax it
  /// then owes (the Swiss 383).
  factory ExpenseVatChoice.of(
    WidgetRef ref,
    Workspace workspace,
    TextEditingController share,
  ) => ExpenseVatChoice(
    share,
    acquisitionOffered: vatFormTaxesAcquisitions(
      workspace.countryCode,
      ref.read(clockProvider).now(),
    ),
  );

  final TextEditingController share;

  /// Whether the space may say the expense was bought from abroad.
  final bool acquisitionOffered;
  double? percent;
  bool asset = false;

  /// Bought from a supplier abroad: the amount carries no VAT and is the
  /// base of the acquisition tax the space owes.
  bool acquisition = false;

  /// The share typed, or null when it is not a number.
  double? get sharePct =>
      double.tryParse(share.text.trim().replaceAll(',', '.'));

  /// Whether a rate is chosen and the share lies in 0..100.
  bool get shareValid {
    final pct = sharePct;
    return percent == null || (pct != null && pct >= 0 && pct <= 100);
  }

  /// What the VAT says beyond its rate and share.
  ExpenseVatFlags get flags => (asset: asset, acquisition: acquisition);

  /// The payload the RPCs take, or null without VAT.
  Map<String, Object?>? get payload => (percent ?? 0) <= 0
      ? null
      : {
          'percent': percent,
          'deductible_pct': sharePct,
          if (asset) 'asset': true,
          if (acquisition) 'acquisition': true,
        };
}

/// The rates an expense may carry here, highest first; empty when the
/// space is not VAT-registered or input VAT is off.
Future<List<double>> expenseVatPercents(WidgetRef ref, String vatRegime) async {
  if (!ref
          .read(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.inputVat) ||
      vatRegimeFromWire(vatRegime) != VatRegime.vatRegistered) {
    return const [];
  }
  var rates = const <VatRate>[];
  try {
    rates = await ref.read(vatRatesProvider.future);
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'expense VAT rates failed',
      error: e,
      stackTrace: st,
    );
  }
  return {
    for (final r in rates)
      if (r.active && r.percent > 0) r.percent,
  }.toList()..sort((a, b) => b.compareTo(a));
}

/// #2573 — the rates a receipt line may carry in the current space, and its
/// currency; null while no space is open.
Future<({List<double> percents, MoneyFormat currency})?> receiptVatContext(
  WidgetRef ref,
) async {
  final workspace = await ref.read(currentWorkspaceProvider.future);
  if (workspace == null) return null;
  return (
    percents: await expenseVatPercents(ref, workspace.vatRegime),
    currency: moneyFormat(workspace.currencyCode),
  );
}

/// « 20 % », in the reader's number format.
String expenseVatPercentLabel(AppLocalizations l10n, double percent) =>
    _percentLabel(l10n, percent);

/// The fields, keyed `<keyPrefix>-vat-rate`, `-vat-deductible`,
/// `-vat-asset` and, where the choice offers it, `-vat-acquisition`;
/// [amount] is the amount as typed (gross, or the base of an acquisition).
List<Widget> expenseVatFields({
  required AppLocalizations l10n,
  required MoneyFormat currency,
  required List<double> percents,
  required ExpenseVatChoice choice,
  required String amount,
  required VoidCallback refresh,
  required String keyPrefix,
}) {
  if (percents.isEmpty) return const [];
  final words = vatWords(l10n);
  return [
    const FormGap(),
    DropdownButtonFormField<double?>(
      key: ValueKey('$keyPrefix-vat-rate'),
      initialValue: choice.percent,
      decoration: InputDecoration(labelText: words.expenseVatRate),
      items: [
        DropdownMenuItem<double?>(child: Text(words.expenseVatNone)),
        for (final p in percents)
          DropdownMenuItem<double?>(
            value: p,
            child: Text(_percentLabel(l10n, p)),
          ),
      ],
      onChanged: (v) {
        choice.percent = v;
        refresh();
      },
    ),
    if (choice.percent != null) ...[
      const FormGap(),
      AppTextField(
        key: ValueKey('$keyPrefix-vat-deductible'),
        controller: choice.share,
        fieldKey: 'deductible',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        label: words.expenseVatDeductible,
        helper: _deductibleHelper(l10n, currency, amount, choice),
        onChanged: (_) => refresh(),
      ),
      ..._flagSwitches(words, choice, refresh, keyPrefix),
    ],
  ];
}

/// What the VAT says beyond its rate: a fixed asset and, where the choice
/// offers it, a purchase from a supplier abroad.
List<Widget> _flagSwitches(
  AppLocalizations words,
  ExpenseVatChoice choice,
  VoidCallback refresh,
  String keyPrefix,
) => [
  SwitchListTile(
    key: ValueKey('$keyPrefix-vat-asset'),
    contentPadding: EdgeInsets.zero,
    title: Text(words.expenseVatAsset),
    subtitle: Text(words.expenseVatAssetHint),
    value: choice.asset,
    onChanged: (v) {
      choice.asset = v;
      refresh();
    },
  ),
  if (choice.acquisitionOffered)
    SwitchListTile(
      key: ValueKey('$keyPrefix-vat-acquisition'),
      contentPadding: EdgeInsets.zero,
      title: Text(words.expenseVatAcquisition),
      subtitle: Text(words.expenseVatAcquisitionHint),
      value: choice.acquisition,
      onChanged: (v) {
        choice.acquisition = v;
        refresh();
      },
    ),
];

/// « 20 % », in the reader's number format.
String _percentLabel(AppLocalizations l10n, double percent) =>
    '${NumberFormat.decimalPattern(l10n.localeName).format(percent)} %';

/// The hint, and once amount and share are typed, the deductible VAT
/// they make (`vatInputSplit`, the server's rounding); for an acquisition
/// the tax owed on the amount and its deductible share
/// (`vatAcquisitionSplit`).
String _deductibleHelper(
  AppLocalizations l10n,
  MoneyFormat currency,
  String amount,
  ExpenseVatChoice choice,
) {
  final words = vatWords(l10n);
  final gross = parseCentsInput(amount);
  final pct = choice.sharePct;
  final percent = choice.percent;
  if (gross == null ||
      gross <= 0 ||
      percent == null ||
      pct == null ||
      pct < 0 ||
      pct > 100) {
    return words.expenseVatDeductibleHint;
  }
  if (choice.acquisition) {
    final owed = vatAcquisitionSplit(gross, percent, pct);
    return words.expenseVatAcquisitionAmount(
      currency.formatMinor(owed.taxCents),
      currency.formatMinor(owed.deductibleCents),
    );
  }
  final split = vatInputSplit(gross, percent, pct);
  return words.expenseVatDeductibleAmount(
    currency.formatMinor(split.deductibleCents),
  );
}
