// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/vat_catalogue.dart';
import '../../domain/vat_rate.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';

/// The workspace's VAT RATES (0072) — owner-only.
///
/// The screen exists because a rate is a fact about the business, not
/// something an app may guess: which supply falls under which rate is a
/// question for an accountant, and rates move. So it offers the country's
/// usual rates as a STARTING POINT and then gets out of the way.
///
/// What it deliberately does not offer is a way to change what members
/// pay: prices stay VAT-inclusive, and the tax is extracted from them.
class VatScreen extends ConsumerStatefulWidget {
  const VatScreen({super.key});

  @override
  ConsumerState<VatScreen> createState() => _VatScreenState();
}

/// One editable row. The controllers live here so a rename never rebuilds
/// into a lost cursor.
class _RateDraft {
  _RateDraft(this.rate)
      : label = TextEditingController(text: rate.label),
        percent = TextEditingController(
          text: rate.percent == 0 ? '' : _percentText(rate.percent),
        );

  final VatRate rate;
  final TextEditingController label;
  final TextEditingController percent;

  void dispose() {
    label.dispose();
    percent.dispose();
  }
}

/// '20', '5.5' — what the owner typed, not '20.0'.
String _percentText(double percent) => percent == percent.roundToDouble()
    ? percent.toStringAsFixed(0)
    : percent.toString();

class _VatScreenState extends ConsumerState<VatScreen> {
  List<_RateDraft> _drafts = [];

  /// Index of the default rate, -1 while there is none.
  int _default = -1;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _load(List<VatRate> rates) {
    _drafts = [for (final rate in rates) _RateDraft(rate)];
    _default = rates.indexWhere((rate) => rate.isDefault);
  }

  void _add(VatRate rate) {
    setState(() {
      _drafts = [..._drafts, _RateDraft(rate)];
      // The first rate ever added is the default — there is nothing else
      // it could be.
      if (_default < 0) _default = _drafts.length - 1;
    });
  }

  void _remove(int index) {
    setState(() {
      _drafts.removeAt(index).dispose();
      if (_default == index) {
        _default = _drafts.isEmpty ? -1 : 0;
      } else if (_default > index) {
        _default--;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;

    final rates = <VatRate>[];
    for (final (index, draft) in _drafts.indexed) {
      final label = draft.label.text.trim();
      // Both separators: a French keyboard types a comma.
      final percent =
          double.tryParse(draft.percent.text.trim().replaceAll(',', '.'));
      if (label.isEmpty ||
          percent == null ||
          percent < 0 ||
          percent > 99.99) {
        AppSnack.error(
          context,
          l10n?.vatRateIncomplete ??
              'Every rate needs a name and a percentage between 0 and 99.99.',
        );
        return;
      }
      rates.add(draft.rate.copyWith(
        label: label,
        percent: percent,
        // A zero-percent rate is not category S; which zero category it is
        // follows the workspace's regime, which the server already knows.
        category: percent > 0 ? 'S' : draft.rate.category,
        isDefault: index == _default,
        active: true,
      ));
    }
    if (rates.isNotEmpty && _default < 0) {
      AppSnack.error(
        context,
        l10n?.vatNeedsDefault ?? 'Mark exactly one rate as the default.',
      );
      return;
    }

    setState(() => _saving = true);
    final saved = await runGuarded(
      context,
      domain: 'money',
      message: 'vat rates save failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () =>
          ref.read(moneyRepositoryProvider).setVatRates(workspace.id, rates),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) return;
    ref.invalidate(vatRatesProvider);
    if (!mounted) return;
    AppSnack.success(context, l10n?.vatSaved ?? 'VAT rates saved.');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final ratesAsync = ref.watch(vatRatesProvider);
    final title = Text(l10n?.vatTitle ?? 'VAT');
    if (workspace == null || ratesAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const LoadingView(),
      );
    }
    if (!_loaded) {
      _loaded = true;
      _load(ratesAsync.value ?? const []);
    }
    final regime = vatRegimeFromWire(workspace.vatRegime);
    final catalogue = vatCatalogueFor(workspace.countryCode);
    final catalogueNote = vatCatalogueNote(workspace.countryCode);

    return Scaffold(
      appBar: AppBar(title: title),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n?.vatIntro ??
                'Prices in DesKilo include VAT. Adding rates changes '
                    'nothing about what members pay — the tax is extracted '
                    'from the price you already charge and shown on the '
                    'invoice.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (regime != VatRegime.vatRegistered)
            InlineBanner(
              key: const ValueKey('vat-regime-hint'),
              icon: Icons.info_outline,
              text: l10n?.vatRegimeHint ??
                  'This workspace is not declared VAT-registered, so '
                      'invoices show no VAT. Change that under Legal '
                      'identity.',
            ),
          const SizedBox(height: AppSpacing.md),
          if (_drafts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                l10n?.vatEmpty ?? 'No rate yet — invoices show no VAT.',
                key: const ValueKey('vat-empty'),
              ),
            ),
          for (final (index, draft) in _drafts.indexed)
            Padding(
              key: ValueKey('vat-rate-$index'),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      key: ValueKey('vat-rate-label-$index'),
                      controller: draft.label,
                      maxLength: 60,
                      decoration: InputDecoration(
                        labelText: l10n?.vatRateLabelField ?? 'Name',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 84,
                    child: TextField(
                      key: ValueKey('vat-rate-percent-$index'),
                      controller: draft.percent,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n?.vatRatePercentField ?? 'Rate %',
                      ),
                    ),
                  ),
                  // A star rather than a radio: it reads as "this is the
                  // one" at a glance and stays one tap either way.
                  IconButton(
                    key: ValueKey('vat-rate-default-$index'),
                    tooltip: l10n?.vatRateDefaultTooltip ??
                        'Default rate — used by subscriptions and by '
                            'anything without its own rate',
                    icon: Icon(
                      index == _default ? Icons.star : Icons.star_border,
                      color: index == _default
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onPressed: () => setState(() => _default = index),
                  ),
                  IconButton(
                    key: ValueKey('vat-rate-remove-$index'),
                    tooltip: l10n?.vatRateRemoveTooltip ?? 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(index),
                  ),
                ],
              ),
            ),
          Text(
            l10n?.vatKeptRate ??
                'A rate still used by an invoice or a service is kept, '
                    'deactivated.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            TextButton.icon(
              key: const ValueKey('vat-add-rate'),
              onPressed: () => _add(const VatRate(label: '', percent: 0)),
              icon: const Icon(Icons.add),
              label: Text(l10n?.vatAddRate ?? 'Add a rate'),
            ),
            // Only where the app actually knows the country's rates, and
            // only as a first draft the owner then edits.
            if (catalogue.isNotEmpty && _drafts.isEmpty)
              TextButton(
                key: const ValueKey('vat-seed'),
                onPressed: () {
                  for (final rate in catalogue) {
                    _add(rate);
                  }
                },
                child: Text(
                  '${l10n?.vatSeed ?? 'Use the usual rates'} '
                  '(${catalogue.map((r) => '${_percentText(r.percent)} %').join(', ')})',
                ),
              ),
            // #534 — country caveats (US sales tax, Canadian provinces,
            // the Swiss accommodation rate).
            if (catalogueNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  catalogueNote,
                  key: const ValueKey('vat-catalogue-note'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ]),
          // #534 — the periodic return, one tap from where VAT lives.
          if (regime == VatRegime.vatRegistered &&
              ref
                  .watch(enabledFeaturesSyncProvider)
                  .contains(WorkspaceFeature.vatDeclarations))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: OutlinedButton.icon(
                key: const ValueKey('vat-declarations-button'),
                onPressed: () => context.go('/vat-declarations'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(
                    l10n?.vatDeclTitle ?? 'VAT declaration'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('vat-save'),
            onPressed: _saving ? null : _save,
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
  }
}
