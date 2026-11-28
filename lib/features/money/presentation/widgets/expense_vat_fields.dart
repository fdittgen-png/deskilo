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
import '../../../../core/ui/country_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/submit_expense.dart';
import '../../domain/vat_input.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart' show watchWorkspaceTaxReference;
import '../vat_tax_point_labels.dart';

/// #4479 — what kind of VAT the expense carries: none; the VAT of the space's own country, at a rate picked from the space's
/// rates; a service bought from a supplier abroad (the space owes the tax); or VAT a supplier abroad charged, kept as a fact.
enum ExpenseVatKind { none, domestic, acquisition, foreignCharged }

/// What the person chose; [share] is the deductible share as typed.
class ExpenseVatChoice {
  ExpenseVatChoice(this.fields, {this.countryCode = ''});

  /// #2360 — the choice for an expense of a space in [countryCode]: an acquisition from abroad is offered only where today's
  /// return has a box for the tax it then owes (the Swiss 383). The texts live in [fields], disposed with the sheet.
  factory ExpenseVatChoice.of(
    WidgetRef ref,
    String countryCode,
    FormControllers fields,
  ) => ExpenseVatChoice(fields, countryCode: countryCode);

  final FormControllers fields;

  TextEditingController get share => fields['deductible'];

  /// The country of the space the expense is for; whether the acquisition is
  /// offered is asked of the workspace's tax reference WHEN DRAWN, so a sheet
  /// opened before the context was ready shows it once it is.
  final String countryCode;

  ExpenseVatKind kind = ExpenseVatKind.none;

  /// The rate picked from the space's rates (the expense keeps its identity); null until one is.
  VatRate? rate;
  bool asset = false;

  /// The percent of the picked rate, for the VAT of the space's own country and for an acquisition; null otherwise.
  double? get percent => switch (kind) {
    ExpenseVatKind.domestic || ExpenseVatKind.acquisition => rate?.percent,
    _ => null,
  };

  /// Bought from a supplier abroad: the amount carries no VAT and is the
  /// base of the acquisition tax the space owes.
  bool get acquisition => kind == ExpenseVatKind.acquisition;

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

  /// The identity of the rate the expense carries.
  String? get rateId => percent == null || (rate?.id ?? '').isEmpty ? null : rate!.id;

  /// VAT a supplier abroad charged, as typed (the amount in [locale]); null for any other kind.
  ForeignVat? foreign(String locale) {
    if (kind != ExpenseVatKind.foreignCharged) return null;
    final tax = fields['statedTax'].text.trim();
    return ForeignVat(
      percent: parseDecimalInput(fields['statedPercent'].text, grouping: false)?.toDouble(),
      taxCents: tax.isEmpty ? null : parseMinorInput(tax, locale: locale) ?? -1,
    );
  }

  /// The document's own facts: the supplier's country and the number, when given.
  Map<String, Object?> get facts {
    if (kind == ExpenseVatKind.none) return const {};
    final country = fields['vatCountry'].text.trim().toUpperCase();
    final number = fields['vatDocumentNumber'].text.trim();
    return {
      if (country.isNotEmpty) 'supplier_country': country,
      if (number.isNotEmpty) 'document_number': number,
    };
  }

  /// The payload the RPCs take, or null without VAT.
  Map<String, Object?>? payload(String locale) => expenseVatPayload(
    percent: percent,
    deductiblePct: sharePct,
    rateId: rateId,
    flags: flags,
    foreign: foreign(locale),
    facts: facts,
  );
}

/// The rates an expense may carry here, highest first; empty when the
/// space is not VAT-registered, input VAT is off, or the space has no rate.
///
/// A read of the rates that failed is thrown, never answered as empty: an
/// empty answer says "no VAT here", and the form would then file an expense
/// without the VAT its space deducts. A form reads them before it opens
/// ([whenExpenseVatRead]) or shows the failure with a way to try again.
Future<List<double>> expenseVatPercents(WidgetRef ref, String vatRegime) async => {
  for (final r in await expenseVatRates(ref, vatRegime)) r.percent,
}.toList();

/// The rates themselves, highest first, an expense picks by identity (#4479); the same rules as [expenseVatPercents].
Future<List<VatRate>> expenseVatRates(WidgetRef ref, String vatRegime) async {
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
  return [
    for (final r in rates)
      if (r.active && r.percent > 0) r,
  ]..sort((a, b) => b.percent.compareTo(a.percent));
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

/// The fields, keyed `<keyPrefix>-vat-kind`, `-vat-rate`, `-vat-deductible`, `-vat-asset`, and for a supplier abroad
/// `-vat-country`, `-vat-number`, `-vat-stated-percent` and `-vat-stated-tax`; [amount] is the amount as typed (gross, or the
/// base of an acquisition).
List<Widget> expenseVatFields({
  required AppLocalizations l10n,
  required MoneyFormat currency,
  required List<VatRate> rates,
  required ExpenseVatChoice choice,
  required String amount,
  required VoidCallback refresh,
  required String keyPrefix,
}) {
  if (rates.isEmpty) return const [];
  final words = vatWords(l10n);
  final own = choice.kind == ExpenseVatKind.domestic || choice.kind == ExpenseVatKind.acquisition;
  final abroad = choice.kind == ExpenseVatKind.acquisition || choice.kind == ExpenseVatKind.foreignCharged;
  return [
    const FormGap(),
    _kindField(l10n, choice, refresh, keyPrefix),
    if (own) ...[
      const FormGap(),
      _rateField(l10n, currency, rates, choice, refresh, keyPrefix),
    ],
    if (own && choice.rate != null) ...[
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
      _assetSwitch(words, choice, refresh, keyPrefix),
    ],
    if (abroad) ...[
      const FormGap(),
      CountryField(
        textKey: ValueKey('$keyPrefix-vat-country'),
        controller: choice.fields['vatCountry'],
        fieldKey: 'vatCountry',
        label: words.expenseVatSupplierCountry,
        onChanged: (_) => refresh(),
      ),
    ],
    if (choice.kind != ExpenseVatKind.none) ...[
      const FormGap(),
      AppTextField(
        key: ValueKey('$keyPrefix-vat-number'),
        controller: choice.fields['vatDocumentNumber'],
        fieldKey: 'vatDocumentNumber',
        label: words.expenseVatDocumentNumber,
      ),
    ],
    if (choice.kind == ExpenseVatKind.foreignCharged) ...[
      const FormGap(),
      AppTextField(
        key: ValueKey('$keyPrefix-vat-stated-percent'),
        controller: choice.fields['statedPercent'],
        fieldKey: 'statedPercent',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        label: words.expenseVatStatedPercent,
        helper: words.expenseVatForeignNote,
        onChanged: (_) => refresh(),
      ),
      const FormGap(),
      AppTextField(
        key: ValueKey('$keyPrefix-vat-stated-tax'),
        controller: choice.fields['statedTax'],
        fieldKey: 'statedTax',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        label: words.expenseVatStatedTax,
      ),
    ],
  ];
}

/// What the VAT is: none, the space's own country's, a purchase from abroad where the return has a box for it, or the VAT a
/// supplier abroad charged.
Widget _kindField(
  AppLocalizations l10n,
  ExpenseVatChoice choice,
  VoidCallback refresh,
  String keyPrefix,
) => Consumer(
  builder: (context, ref, _) {
    final words = vatWords(l10n);
    final reference = watchWorkspaceTaxReference(ref);
    // The acquisition is offered once the workspace's own tax reference is ready, where today's return has a box for it.
    final acquisitions = reference != null &&
        vatFormTaxesAcquisitions(
          choice.countryCode,
          ref.read(clockProvider).now(),
          reference: reference,
        );
    return DropdownButtonFormField<ExpenseVatKind>(
      key: ValueKey('$keyPrefix-vat-kind'),
      initialValue: choice.kind,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: words.expenseVatTreatment,
        suffixIcon: HelpDot(
          words.expenseVatTreatment,
          anchor: HelpAnchor.moneyExpenseVat,
        ),
      ),
      items: [
        DropdownMenuItem(
          value: ExpenseVatKind.none,
          child: Text(words.expenseVatNone),
        ),
        DropdownMenuItem(
          value: ExpenseVatKind.domestic,
          child: Text(words.expenseVatTreatmentDomestic),
        ),
        if (acquisitions || choice.acquisition)
          DropdownMenuItem(
            value: ExpenseVatKind.acquisition,
            child: Text(words.expenseVatAcquisition),
          ),
        DropdownMenuItem(
          value: ExpenseVatKind.foreignCharged,
          child: Text(words.expenseVatTreatmentForeign),
        ),
      ],
      onChanged: (v) {
        choice.kind = v ?? choice.kind;
        refresh();
      },
    );
  },
);

/// A purchase of a fixed asset (CA3 line 19, the Swiss 405, the Spanish 30/31).
Widget _assetSwitch(
  AppLocalizations words,
  ExpenseVatChoice choice,
  VoidCallback refresh,
  String keyPrefix,
) => SwitchListTile(
  key: ValueKey('$keyPrefix-vat-asset'),
  contentPadding: EdgeInsets.zero,
  title: Text(words.expenseVatAsset),
  subtitle: Text(words.expenseVatAssetHint),
  value: choice.asset,
  onChanged: (v) {
    choice.asset = v;
    refresh();
  },
);

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

/// The rate picker over the space's rates, by identity, with the help symbol of the expense's VAT (#3527).
Widget _rateField(
  AppLocalizations l10n,
  MoneyFormat currency,
  List<VatRate> rates,
  ExpenseVatChoice choice,
  VoidCallback refresh,
  String keyPrefix,
) {
  final words = vatWords(l10n);
  return DropdownButtonFormField<VatRate?>(
    key: ValueKey('$keyPrefix-vat-rate'),
    initialValue: choice.rate,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: words.expenseVatRate,
      suffixIcon: HelpDot(
        words.expenseVatRate,
        anchor: HelpAnchor.moneyExpenseVat,
      ),
    ),
    items: [
      for (final r in rates)
        DropdownMenuItem<VatRate?>(
          value: r,
          child: Text('${r.label} · ${_percentLabel(currency, r.percent)}'),
        ),
    ],
    onChanged: (v) {
      choice.rate = v;
      refresh();
    },
  );
}
