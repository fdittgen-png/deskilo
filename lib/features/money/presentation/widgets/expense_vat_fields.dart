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
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/read_failure.dart';
import '../../../../core/format/cents.dart';
import '../../../../core/format/decimal_input.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/submit_expense.dart';
import '../../domain/vat_input.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart' show watchWorkspaceTaxReference;
import '../vat_tax_point_labels.dart';

/// What the person chose; [share] is the deductible share as typed.
class ExpenseVatChoice {
  ExpenseVatChoice(this.share, {this.countryCode = ''});

  /// #2360 — the choice for an expense of a space in [countryCode]: an
  /// acquisition from
  /// abroad is offered only where today's return has a box for the tax it
  /// then owes (the Swiss 383).
  factory ExpenseVatChoice.of(
    WidgetRef ref,
    String countryCode,
    TextEditingController share,
  ) => ExpenseVatChoice(share, countryCode: countryCode);

  final TextEditingController share;

  /// The country of the space the expense is for; whether the acquisition is
  /// offered is asked of the workspace's tax reference WHEN DRAWN, so a sheet
  /// opened before the context was ready shows it once it is.
  final String countryCode;
  double? percent;
  bool asset = false;

  /// Bought from a supplier abroad: the amount carries no VAT and is the
  /// base of the acquisition tax the space owes.
  bool acquisition = false;

  /// The share typed, or null when it is not a number.
  double? get sharePct =>
      parseDecimalInput(share.text, grouping: false)?.toDouble();

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
/// space is not VAT-registered, input VAT is off, or the space has no rate.
///
/// A read of the rates that failed is thrown, never answered as empty: an
/// empty answer says "no VAT here", and the form would then file an expense
/// without the VAT its space deducts. A form reads them before it opens
/// ([whenExpenseVatRead]) or shows the failure with a way to try again.
Future<List<double>> expenseVatPercents(WidgetRef ref, String vatRegime) async {
  if (!ref
          .read(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.inputVat) ||
      vatRegimeFromWire(vatRegime) != VatRegime.vatRegistered) {
    return const [];
  }
  final List<VatRate> rates;
  try {
    rates = await ref.read(vatRatesProvider.future);
  } on Object {
    // The caller's guarded read traces it; the failed read is dropped here so
    // the next try asks the server again. A screen that was left has no read
    // to drop: its providers went with it.
    if (ref.context.mounted) ref.invalidate(vatRatesProvider);
    rethrow;
  }
  return {
    for (final r in rates)
      if (r.active && r.percent > 0) r.percent,
  }.toList()..sort((a, b) => b.compareTo(a));
}

/// Runs [open], a form that asks an expense for its VAT, once the rates it
/// will offer have been read. When they could not be read, says why on
/// [context] and answers [unopened]: the form stays closed rather than open as
/// if the space had no VAT, and opening it again reads the rates again.
Future<T> whenExpenseVatRead<T>(
  BuildContext context,
  WidgetRef ref,
  Future<T> Function() open, {
  required T unopened,
}) async {
  final workspace = ref.read(currentWorkspaceProvider).value;
  Object? unread;
  if (workspace != null) {
    await guardRead<List<double>?>(
      domain: 'money',
      message: 'expense VAT rates failed',
      read: () => expenseVatPercents(ref, workspace.vatRegime),
      fallback: (e) {
        unread = e;
        return null;
      },
    );
  }
  final failed = unread;
  // The screen that asked may be gone by the time the rates are read: then
  // nothing opens and nothing is said on it.
  if (!context.mounted) return unopened;
  if (failed == null) return open();
  final l10n = context.l10n;
  AppSnack.error(context, switch (classifyReadFailure(failed)) {
    ReadFailure.transient => l10n.readStateOffline,
    ReadFailure.denied => l10n.readStateDenied,
    ReadFailure.other => l10n.readStateFailed,
  });
  return unopened;
}

/// #2573 — the rates a receipt line may carry in the current space, and its
/// currency; null while no space is open. Throws what the read of the rates
/// threw (see [expenseVatPercents]).
Future<({List<double> percents, MoneyFormat currency})?> receiptVatContext(
  WidgetRef ref,
) async {
  final workspace = await ref.read(currentWorkspaceProvider.future);
  if (workspace == null) return null;
  return (
    percents: await expenseVatPercents(ref, workspace.vatRegime),
    currency: ref.read(appFormatProvider).moneyIn(workspace.currencyCode),
  );
}

/// « 20 % », in the reader's number format.
String expenseVatPercentLabel(AppFormat format, double percent) =>
    format.ratePercent(percent);

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
    _rateField(l10n, currency, percents, choice, refresh, keyPrefix),
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
  Consumer(
    builder: (context, ref, _) {
      // Offered only once the workspace's own tax reference is ready, and
      // where today's return has a box for the tax it then owes.
      final reference = watchWorkspaceTaxReference(ref);
      if (reference == null ||
          !vatFormTaxesAcquisitions(
            choice.countryCode,
            ref.read(clockProvider).now(),
            reference: reference,
          )) {
        return const SizedBox.shrink();
      }
      return SwitchListTile(
        key: ValueKey('$keyPrefix-vat-acquisition'),
        contentPadding: EdgeInsets.zero,
        title: Text(words.expenseVatAcquisition),
        subtitle: Text(words.expenseVatAcquisitionHint),
        value: choice.acquisition,
        onChanged: (v) {
          choice.acquisition = v;
          refresh();
        },
      );
    },
  ),
];

/// « 20 % », in the reader's number format.
String _percentLabel(MoneyFormat currency, double percent) =>
    AppFormat(locale: currency.locale, currencyCode: currency.code).ratePercent(percent);

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
  final gross = parseMinorInput(amount, locale: currency.locale);
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

/// The rate picker, with the help symbol of the expense's VAT (#3527).
Widget _rateField(
  AppLocalizations l10n,
  MoneyFormat currency,
  List<double> percents,
  ExpenseVatChoice choice,
  VoidCallback refresh,
  String keyPrefix,
) {
  final words = vatWords(l10n);
  return DropdownButtonFormField<double?>(
    key: ValueKey('$keyPrefix-vat-rate'),
    initialValue: choice.percent,
    decoration: InputDecoration(
      labelText: words.expenseVatRate,
      suffixIcon: HelpDot(
        words.expenseVatRate,
        anchor: HelpAnchor.moneyExpenseVat,
      ),
    ),
    items: [
      DropdownMenuItem<double?>(child: Text(words.expenseVatNone)),
      for (final p in percents)
        DropdownMenuItem<double?>(value: p, child: Text(_percentLabel(currency, p))),
    ],
    onChanged: (v) {
      choice.percent = v;
      refresh();
    },
  );
}
