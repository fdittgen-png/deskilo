// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/save_vat_rates.dart';
import '../../domain/vat_catalogue.dart';
import '../../domain/vat_rate.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';
import '../widgets/vat_rate_editor.dart';

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

class _VatScreenState extends ConsumerState<VatScreen> {
  List<VatRateDraft> _drafts = [];

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
    _drafts = [for (final rate in rates) VatRateDraft(rate)];
    _default = rates.indexWhere((rate) => rate.isDefault);
  }

  void _add(VatRate rate) {
    setState(() {
      _drafts = [..._drafts, VatRateDraft(rate)];
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

  /// #985 — a change by law: the new value from a date. The old version
  /// closes on that date, the successor opens on it, the family link
  /// carries the items along, and the star moves with the family.
  Future<void> _changeByLaw(int index) async {
    final l10n = context.l10n;
    final draft = _drafts[index];
    if (draft.rate.id.isEmpty) {
      AppSnack.error(
        context,
        l10n.vatChangeNeedsSave,
      );
      return;
    }
    final now = ref.read(clockProvider).now();
    // #2360 — a decided change of rate comes prefilled.
    final planned = vatPlannedChangeFor(
        ref.read(currentWorkspaceProvider).value?.countryCode ?? '',
        double.tryParse(draft.percent.text.trim().replaceAll(',', '.')) ?? -1,
        on: now);
    final percent = TextEditingController(
        text: planned == null ? '' : vatPercentText(planned.toPercent));
    final date = TextEditingController(
        text: planned?.from ?? DateTime(now.year, now.month + 1).toIso8601String().substring(0, 10));
    final ok = await showVatChangeByLawDialog(context,
        index: index, percent: percent, date: date);
    if (ok != true || !mounted) return;
    final pct = double.tryParse(percent.text.trim().replaceAll(',', '.'));
    final day = date.text.trim();
    final parsed = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)
        ? DateTime.tryParse(day)
        : null;
    if (pct == null ||
        pct < 0 ||
        pct > 99.99 ||
        parsed == null ||
        day.compareTo(draft.validFrom) <= 0) {
      AppSnack.error(
        context,
        l10n.vatChangeInvalid,
      );
      return;
    }
    final pctText = vatPercentText(pct);
    final relabelled = draft.label.text
        .replaceFirst(RegExp(r'\d+([.,]\d+)?\s*%'), '$pctText %');
    final label = relabelled == draft.label.text
        ? '${draft.label.text} $pctText %'
        : relabelled;
    setState(() {
      draft.validTo = day;
      final successor = VatRateDraft(VatRate(
        label: label,
        percent: pct,
        category: draft.group.category,
        groupKey: draft.group.wire,
        outsideBase: draft.group.outsideBase,
        exemptionReason: draft.exemption.text.trim(),
        validFrom: day,
        supersedesId: draft.rate.id,
      ));
      _drafts = [..._drafts, successor];
      if (_default == index) _default = _drafts.length - 1;
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
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
          l10n.vatRateIncomplete,
        );
        return;
      }
      rates.add(draft.rate.copyWith(
        label: label,
        percent: percent,
        // A zero-percent rate is not category S; which zero category it is
        // follows the workspace's regime, which the server already knows.
        // #947 — the group decides the category and the base rule.
        category: draft.group.category,
        groupKey: draft.group.wire,
        outsideBase: draft.group.outsideBase,
        exemptionReason: draft.exemption.text.trim(),
        validFrom: draft.validFrom,
        validTo: draft.validTo,
        clearValidTo: draft.validTo == null,
        supersedesId: draft.supersedesId,
        isDefault: index == _default,
        active: true,
      ));
    }
    if (rates.isNotEmpty && _default < 0) {
      AppSnack.error(
        context,
        l10n.vatNeedsDefault,
      );
      return;
    }

    setState(() => _saving = true);
    final saved = await runGuarded(
      context,
      domain: 'money',
      message: 'vat rates save failed',
      errorText: l10n.workspaceGenericError,
      action: () => ref.read(saveVatRatesProvider).save(workspace.id, rates),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) return;
    ref.invalidate(vatRatesProvider);
    if (!mounted) return;
    AppSnack.success(context, l10n.vatSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final groupsOn = ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.vatGroups);
    final historyOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.vatRateHistory);
    final ratesAsync = ref.watch(vatRatesProvider);
    final title = Text(l10n.vatTitle);
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
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Scaffold(
      appBar: AppBar(title: title),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          Text(
            l10n.vatIntro,
            style: muted,
          ),
          if (regime != VatRegime.vatRegistered)
            InlineBanner(
              key: const ValueKey('vat-regime-hint'),
              icon: Icons.info_outline,
              text: l10n.vatRegimeHint,
            ),
          const SizedBox(height: AppSpacing.md),
          if (_drafts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                l10n.vatEmpty,
                key: const ValueKey('vat-empty'),
              ),
            ),
          for (final (index, draft) in _drafts.indexed)
            VatRateRow(
              key: ValueKey('vat-rate-$index'),
              index: index,
              draft: draft,
              isDefault: index == _default,
              options: (groupsOn: groupsOn, historyOn: historyOn),
              actions: _rowActions(index, draft),
            ),
          // The version windows, only where a rate has one.
          if (historyOn) VatRateValidityLines(drafts: _drafts),
          Text(
            l10n.vatKeptRate,
            style: muted,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (groupsOn)
            VatGroupSection(drafts: _drafts, countryCode: workspace.countryCode),
          _addRow(workspace.countryCode),
          // The periodic return, one tap from where VAT lives.
          if (regime == VatRegime.vatRegistered &&
              ref
                  .watch(enabledFeaturesSyncProvider)
                  .contains(WorkspaceFeature.vatDeclarations))
            _declarationsButton(),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('vat-save'),
            onPressed: _saving ? null : _save,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  VatRateRowActions _rowActions(int index, VatRateDraft draft) =>
      VatRateRowActions(
        onGroup: (g) => setState(() => draft.group = g ?? draft.group),
        onChangeByLaw: () => _changeByLaw(index),
        onDefault: () => setState(() => _default = index),
        onRemove: () => _remove(index),
      );

  /// A blank rate; the country's usual rates while there is none yet; the
  /// country's caveats.
  Widget _addRow(String countryCode) {
    final l10n = context.l10n;
    final catalogue = vatCatalogueFor(countryCode, on: ref.read(clockProvider).now());
    final catalogueNote = vatCatalogueNote(countryCode, on: ref.read(clockProvider).now());
    return Row(children: [
      TextButton.icon(
        key: const ValueKey('vat-add-rate'),
        onPressed: () => _add(const VatRate(label: '', percent: 0)),
        icon: const Icon(Icons.add),
        label: Text(l10n.vatAddRate),
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
            '${l10n.vatSeed} '
            '(${catalogue.map((r) => '${vatPercentText(r.percent)} %').join(', ')})',
          ),
        ),
      // Country caveats (US sales tax, Canadian provinces, the Swiss
      // accommodation rate).
      if (catalogueNote != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            catalogueNote,
            key: const ValueKey('vat-catalogue-note'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ]);
  }

  Widget _declarationsButton() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: OutlinedButton.icon(
        key: const ValueKey('vat-declarations-button'),
        onPressed: () => context.go('/vat-declarations'),
        icon: const Icon(Icons.receipt_long_outlined),
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.vatDeclTitle),
          HelpDot(l10n.helpTopicVat,
              anchor: HelpAnchor.moneyVatDeclaration),
        ]),
      ),
    );
  }
}
