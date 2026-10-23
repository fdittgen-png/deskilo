// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "VAT": the rates in force as the VAT screen stores them,
// the default one starred. A workspace without rates is offered its
// country's usual ones only where the tax reference data knows them
// (`vatCatalogueFor`), as a starting point saved through the VAT screen's
// own write ([SaveVatRates]); every other change is made on that screen,
// one tap away. The preview splits a sample line into net, VAT and total
// with the app's own arithmetic (`vatSplit`), at the rate an issued
// invoice would charge.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/text/number_text.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/save_vat_rates.dart';
import '../../domain/report_data_sample.dart';
import '../../domain/vat_catalogue.dart';
import '../../domain/vat_rate.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';

class SetupVatStep extends ConsumerWidget {
  const SetupVatStep({
    super.key,
    required this.workspaceId,
    required this.countryCode,
    required this.currencyCode,
    required this.vatRegime,
  });

  final String workspaceId;
  final String countryCode;
  final String currencyCode;

  /// The wire value of the workspace's [VatRegime].
  final String vatRegime;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(vatRatesProvider)) {
        AsyncValue(hasValue: true, :final value) => SetupStepLayout(
          form: _VatForm(step: this, rates: value ?? const []),
          preview: _VatPreview(
            percent: sampleVatPercentOf(vatRegime, value ?? const []),
            currencyCode: currencyCode,
          ),
        ),
        AsyncError() => Padding(
          padding: AppSpacing.lgAll,
          child: InlineBanner(
            key: const ValueKey('setup-vat-failed'),
            icon: Icons.error_outline,
            text: context.l10n.setupStepLoadFailed,
          ),
        ),
        _ => const LoadingView(),
      };
}

/// A rate as the reader's locale writes it: 19, 5,5, 9.975.
String _rate(BuildContext context, double percent) => percentText(
  percent,
  decimalSeparator: NumberFormat.decimalPattern(
    Localizations.localeOf(context).toString(),
  ).symbols.DECIMAL_SEP,
);

class _VatForm extends ConsumerStatefulWidget {
  const _VatForm({required this.step, required this.rates});
  final SetupVatStep step;
  final List<VatRate> rates;

  @override
  ConsumerState<_VatForm> createState() => _VatFormState();
}

class _VatFormState extends ConsumerState<_VatForm> {
  final _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  Future<void> _useUsual(List<VatRate> usual) async {
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'setup vat rates failed',
      errorText: l10n.setupGrowSaveFailed,
      action: () =>
          ref.read(saveVatRatesProvider).save(widget.step.workspaceId, usual),
    );
    ref.invalidate(vatRatesProvider);
    if (!mounted) return;
    _busy.value = false;
    if (ok) AppSnack.success(context, l10n.vatSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rates = widget.rates;
    final now = ref.watch(clockProvider).now();
    final country = widget.step.countryCode;
    final usual = rates.isEmpty
        ? vatCatalogueFor(country, on: now)
        : const <VatRate>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('vat')),
        if (vatRegimeFromWire(widget.step.vatRegime) !=
            VatRegime.vatRegistered) ...[
          const FormGap(),
          InlineBanner(
            key: const ValueKey('setup-vat-regime-hint'),
            icon: Icons.info_outline,
            severity: InlineBannerSeverity.info,
            text: l10n.vatRegimeHint,
          ),
        ],
        const FormGap.large(),
        Semantics(
          header: true,
          child: Text(
            l10n.setupGrowVatInForce,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (rates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(l10n.vatEmpty, key: const ValueKey('setup-vat-empty')),
          ),
        for (final (index, rate) in rates.indexed)
          ListTile(
            key: ValueKey('setup-vat-rate-$index'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: rate.isDefault
                ? Icon(Icons.star, semanticLabel: l10n.vatRateDefaultTooltip)
                : const Icon(Icons.star_border),
            title: Text(rate.label),
            trailing: Text(l10n.setupGrowVatRate(_rate(context, rate.percent))),
          ),
        if (usual.isNotEmpty)
          ValueListenableBuilder<bool>(
            valueListenable: _busy,
            builder: (context, busy, _) => _UsualRates(
              usual: usual,
              note: vatCatalogueNote(country, on: now),
              onUse: busy ? null : () => _useUsual(usual),
            ),
          )
        else if (rates.isEmpty)
          Text(
            l10n.setupGrowVatNoCatalogue,
            key: const ValueKey('setup-vat-no-catalogue'),
          ),
        const FormGap.small(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('setup-vat-open'),
            onPressed: () => context.push('/vat'),
            child: Text(l10n.setupGrowVatOpen),
          ),
        ),
      ],
    );
  }
}

/// The country's usual rates from the tax reference data, offered once.
class _UsualRates extends StatelessWidget {
  const _UsualRates({required this.usual, required this.note, this.onUse});

  final List<VatRate> usual;

  /// The reference data's caveat for the country, if it has one.
  final String? note;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('setup-vat-usual'),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.setupGrowVatUsualTitle,
              style: theme.textTheme.titleSmall,
            ),
            for (final rate in usual)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(rate.label),
                trailing: Text(
                  l10n.setupGrowVatRate(_rate(context, rate.percent)),
                ),
              ),
            Text(l10n.setupGrowVatUsualNote, style: theme.textTheme.bodySmall),
            if (note case final note?) ...[
              const FormGap.small(),
              Text(
                note,
                key: const ValueKey('setup-vat-usual-note'),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const FormGap(),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                key: const ValueKey('setup-vat-use-usual'),
                onPressed: onUse,
                child: Text(l10n.vatSeed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sample line split the way an invoice splits it.
class _VatPreview extends StatelessWidget {
  const _VatPreview({required this.percent, required this.currencyCode});

  final double percent;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = moneyFormat(
      currencyCode,
      locale: Localizations.localeOf(context).toString(),
    );
    final gross = money.formatMinor(SampleInvoice.grossCents);
    final split = vatSplit(SampleInvoice.grossCents, percent);
    if (split.vatCents == 0) {
      return Text(
        l10n.setupGrowVatPreviewNoVat(gross),
        key: const ValueKey('setup-vat-preview-none'),
      );
    }
    Widget row(String id, String label, String amount, {bool total = false}) {
      final style = total
          ? Theme.of(context).textTheme.titleSmall
          : Theme.of(context).textTheme.bodyMedium;
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(amount, key: ValueKey('setup-vat-preview-$id'), style: style),
          ],
        ),
      );
    }

    return Column(
      key: const ValueKey('setup-vat-preview-split'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupGrowVatPreviewNote(gross)),
        const FormGap.small(),
        row('net', l10n.vatPdfNet, money.formatMinor(split.netCents)),
        row(
          'vat',
          l10n.setupGrowVatPreviewRate(_rate(context, percent)),
          money.formatMinor(split.vatCents),
        ),
        row('gross', l10n.purchasesGross, gross, total: true),
      ],
    );
  }
}
