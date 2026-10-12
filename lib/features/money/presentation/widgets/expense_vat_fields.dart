// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — the VAT an expense carried, asked the same way of a one-off
// expense and of a scheduled one: the rate, the share the space may
// deduct (with the deductible amount it makes, as the server rounds it)
// and whether it bought a fixed asset (CA3 line 19, the Swiss 405, the
// Spanish 30/31). Only a VAT-registered space with input VAT on is asked.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/vat_input.dart';
import '../../domain/vat_rate.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';
import '../vat_tax_point_labels.dart';

/// What the person chose; [share] is the deductible share as typed.
class ExpenseVatChoice {
  ExpenseVatChoice(this.share);

  final TextEditingController share;
  double? percent;
  bool asset = false;

  /// The share typed, or null when it is not a number.
  double? get sharePct =>
      double.tryParse(share.text.trim().replaceAll(',', '.'));

  /// Whether a rate is chosen and the share lies in 0..100.
  bool get shareValid {
    final pct = sharePct;
    return percent == null || (pct != null && pct >= 0 && pct <= 100);
  }

  /// The payload the RPCs take, or null without VAT.
  Map<String, Object?>? get payload => (percent ?? 0) <= 0
      ? null
      : {
          'percent': percent,
          'deductible_pct': sharePct,
          if (asset) 'asset': true,
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

/// The fields, keyed `<keyPrefix>-vat-rate`, `-vat-deductible` and
/// `-vat-asset`; [amount] is the gross amount as typed.
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
    ],
  ];
}

/// « 20 % », in the reader's number format.
String _percentLabel(AppLocalizations l10n, double percent) =>
    '${NumberFormat.decimalPattern(l10n.localeName).format(percent)} %';

/// The hint, and once amount and share are typed, the deductible VAT
/// they make (`vatInputSplit`, the server's rounding).
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
  final split = vatInputSplit(gross, percent, pct);
  return words.expenseVatDeductibleAmount(
    currency.formatMinor(split.deductibleCents),
  );
}
