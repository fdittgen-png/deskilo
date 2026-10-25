// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Where the exchange rate of a purchase in another currency than the
// space's is entered and confirmed: the currency and rate of a bill being
// captured, and on the document itself the rate as recorded, which whoever
// captures or approves it may correct until it is approved. The books read
// the document in the space's currency at this rate; the server refuses a
// bill in another currency without one.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/features/enabled_feature_keys.dart';
import '../../../../core/i18n/currencies.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/purchase.dart';
import '../../providers/credit_providers.dart';
import '../../providers/purchase_providers.dart';

/// Whether bills in another currency are switched on here.
bool _foreignOn(WidgetRef ref) => featureOn(
  ref.watch(enabledFeatureKeysProvider),
  foreignCurrencyPurchasesKey,
  byDefault: false,
);

/// The words of a rate source of the reference list; an unknown code is
/// shown as it is.
String _sourceLabel(AppLocalizations l10n, String code) => switch (code) {
  'tax_authority' => l10n.purchasesFxSourceTaxAuthority,
  'bank' => l10n.purchasesFxSourceBank,
  'manual' => l10n.purchasesFxSourceManual,
  _ => code,
};

/// The currency a bill is captured in and, when it is not the space's, its
/// rate: null currency is the space's.
typedef PurchaseCurrencyChoice = ({String? currency, ExchangeRateEntry? rate});

/// The bill's currency and, for another one than the space's, its rate.
/// Nothing at all while the feature is off: the bill is in the space's
/// currency.
class PurchaseCurrencyFields extends ConsumerStatefulWidget {
  const PurchaseCurrencyFields({required this.onChanged, super.key});

  final ValueChanged<PurchaseCurrencyChoice> onChanged;

  @override
  ConsumerState<PurchaseCurrencyFields> createState() =>
      _PurchaseCurrencyFieldsState();
}

class _PurchaseCurrencyFieldsState
    extends ConsumerState<PurchaseCurrencyFields> {
  String? _currency;
  ExchangeRateEntry? _rate;

  void _emit() => widget.onChanged((
    currency: _currency,
    rate: _currency == null ? null : _rate,
  ));

  @override
  Widget build(BuildContext context) {
    final space = _foreignOn(ref) ? ref.watch(spaceCurrencyProvider) : null;
    if (space == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          key: const ValueKey('purchase-currency'),
          initialValue: _currency,
          decoration: InputDecoration(labelText: l10n.purchasesFxCurrency),
          items: [
            DropdownMenuItem<String?>(
              child: Text(l10n.purchasesFxSpaceCurrency(space)),
            ),
            for (final c in Currencies.selectable)
              if (c != space)
                DropdownMenuItem<String?>(value: c, child: Text(c)),
          ],
          onChanged: (v) {
            setState(() => _currency = v);
            _emit();
          },
        ),
        if (_currency case final currency?)
          _ExchangeRateFields(
            currency: currency,
            spaceCurrency: space,
            // recorder-key-exempt: a data callback; the fields are keyed.
            onChanged: (entry) {
              _rate = entry;
              _emit();
            },
          ),
      ],
    );
  }
}

/// The rate of one unit of [currency] in [spaceCurrency], its day and its
/// source; [onChanged] receives the entry, or null while it is not one.
class _ExchangeRateFields extends ConsumerStatefulWidget {
  const _ExchangeRateFields({
    required this.currency,
    required this.spaceCurrency,
    required this.onChanged,
    this.initial,
  });

  final String currency;
  final String spaceCurrency;
  final ExchangeRateEntry? initial;
  final ValueChanged<ExchangeRateEntry?> onChanged;

  @override
  ConsumerState<_ExchangeRateFields> createState() =>
      _ExchangeRateFieldsState();
}

class _ExchangeRateFieldsState extends ConsumerState<_ExchangeRateFields> {
  late final _rate = TextEditingController(
    text: widget.initial?.rate.toString() ?? '',
  );
  late DateTime? _day = widget.initial?.rateDate;
  late String? _source = widget.initial?.source;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  void _emit() {
    final rate = parseExchangeRate(_rate.text).rate;
    final day = _day;
    final source = _source;
    widget.onChanged(
      rate == null || day == null || source == null
          ? null
          : ExchangeRateEntry(rate: rate, rateDate: day, source: source),
    );
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? ref.read(clockProvider).now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: context.l10n.purchasesFxRateDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _day = picked);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sources = ref.watch(exchangeRateSourcesProvider).value ?? const [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          key: const ValueKey('purchase-fx-rate'),
          controller: _rate,
          label: l10n.purchasesFxRate(widget.currency, widget.spaceCurrency),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _emit(),
        ),
        // Rebuilt when the sources arrive, so a held source is shown.
        KeyedSubtree(
          key: ValueKey(sources.length),
          child: DropdownButtonFormField<String>(
            key: const ValueKey('purchase-fx-source'),
            initialValue: sources.contains(_source) ? _source : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.purchasesFxSource),
            items: [
              for (final s in sources)
                DropdownMenuItem(value: s, child: Text(_sourceLabel(l10n, s))),
            ],
            onChanged: (v) {
              setState(() => _source = v);
              _emit();
            },
          ),
        ),
        const FormGap.small(),
        OutlinedButton(
          key: const ValueKey('purchase-fx-date'),
          onPressed: _pickDay,
          child: Text(
            _day == null
                ? l10n.purchasesFxRateDate
                : '${l10n.purchasesFxRateDate}: '
                      '${MaterialLocalizations.of(context).formatMediumDate(_day!)}',
          ),
        ),
      ],
    );
  }
}

/// With the feature on, on a purchase in another currency: the rate as
/// recorded (or that none
/// is), and for whoever captures or approves it the way to enter or correct
/// it until the purchase is approved (an approved one with no rate may
/// still receive its first).
class PurchaseExchangeRateTile extends ConsumerWidget {
  const PurchaseExchangeRateTile({
    required this.workspaceId,
    required this.summary,
    required this.canEdit,
    super.key,
  });

  final String workspaceId;
  final PurchaseSummary summary;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Off, the entry point goes; the recorded rate stays untouched.
    final space = _foreignOn(ref) ? ref.watch(spaceCurrencyProvider) : null;
    if (space == null ||
        summary.currency.isEmpty ||
        summary.currency == space) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final held = ref
        .watch(
          purchaseExchangeRateProvider((
            workspaceId: workspaceId,
            purchaseId: summary.id,
          )),
        )
        .value;
    final open =
        summary.state == PurchaseState.draft ||
        summary.state == PurchaseState.pending ||
        (summary.state == PurchaseState.approved && held == null);
    return ListTile(
      key: const ValueKey('purchase-fx'),
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.purchasesFxTitle),
      subtitle: Text(
        held == null
            ? l10n.purchasesFxMissing
            : l10n.purchasesFxRecorded(
                held.currency,
                held.entry.rate.toString(),
                held.functionalCurrency,
                MaterialLocalizations.of(context)
                    .formatMediumDate(held.entry.rateDate),
                _sourceLabel(l10n, held.entry.source),
              ),
      ),
      trailing: canEdit && open
          ? IconButton(
              key: const ValueKey('purchase-fx-edit'),
              tooltip: l10n.purchasesFxEnter,
              icon: const Icon(Icons.currency_exchange),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _RateDialog(
                  workspaceId: workspaceId,
                  summary: summary,
                  spaceCurrency: space,
                  held: held?.entry,
                ),
              ),
            )
          : null,
    );
  }
}

class _RateDialog extends ConsumerStatefulWidget {
  const _RateDialog({
    required this.workspaceId,
    required this.summary,
    required this.spaceCurrency,
    required this.held,
  });

  final String workspaceId;
  final PurchaseSummary summary;
  final String spaceCurrency;
  final ExchangeRateEntry? held;

  @override
  ConsumerState<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends ConsumerState<_RateDialog> {
  late ExchangeRateEntry? _entry = widget.held;
  bool _invalid = false;

  Future<void> _save() async {
    final entry = _entry;
    if (entry == null) {
      setState(() => _invalid = true);
      return;
    }
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'exchange rate save failed',
      errorText: context.l10n.purchasesFxRefused,
      action: () async {
        await ref
            .read(purchaseCommandProvider)
            .recordExchangeRate(
              widget.workspaceId,
              widget.summary,
              entry,
              spaceCurrency: widget.spaceCurrency,
            );
      },
    );
    ref.invalidate(purchaseExchangeRateProvider);
    if (!ok || !mounted) return;
    AppSnack.success(context, context.l10n.purchasesFxSaved);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.purchasesFxTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExchangeRateFields(
              currency: widget.summary.currency,
              spaceCurrency: widget.spaceCurrency,
              initial: widget.held,
              // recorder-key-exempt: a data callback; the fields are keyed.
              onChanged: (e) => _entry = e,
            ),
            if (_invalid)
              Text(
                l10n.purchasesFxInvalid,
                key: const ValueKey('purchase-fx-invalid'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('purchase-fx-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('purchase-fx-save'),
          onPressed: _save,
          child: Text(l10n.purchasesSave),
        ),
      ],
    );
  }
}
