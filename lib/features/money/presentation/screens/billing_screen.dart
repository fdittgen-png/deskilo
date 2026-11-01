// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/unsaved_changes_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/fee_band.dart';
import '../../domain/package.dart';
import '../../domain/subscription_levels.dart';
import '../../domain/vat_rate.dart';
import '../../providers/money_providers.dart';
import '../widgets/billing_band_row.dart';
import '../widgets/billing_editor_sections.dart';
import '../widgets/carnets_editor.dart';
import '../widgets/vat_rate_field.dart';

/// Owner-only billing editor (#128, ADR 0008): the fee bands pricing the
/// percentage subscriptions, and the subscription levels members may pick
/// from. Replaces the plans editor.
class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bandsAsync = ref.watch(feeBandsProvider);
    final levelsAsync = ref.watch(subscriptionLevelsProvider);
    final packagesAsync = ref.watch(allPackagesProvider);

    final appBar = AppBar(title: Text(l10n.billingTitle));
    return switch ((bandsAsync, levelsAsync, packagesAsync)) {
      (
        AsyncData(value: final bands),
        AsyncData(value: final levels),
        AsyncData(value: final packages)
      ) =>
        _BillingEditor(
          appBar: appBar,
          bands: bands,
          levels: levels,
          packages: packages,
        ),
      (AsyncError(), _, _) || (_, AsyncError(), _) || (_, _, AsyncError()) =>
        Scaffold(
          appBar: appBar,
          body: Center(child: Text(l10n.workspaceGenericError)),
        ),
      _ => Scaffold(appBar: appBar, body: const LoadingView()),
    };
  }
}

class _BillingEditor extends ConsumerStatefulWidget {
  const _BillingEditor({
    required this.bands,
    required this.levels,
    required this.packages,
    required this.appBar,
  });

  final PreferredSizeWidget appBar;

  final List<FeeBand> bands;
  final SubscriptionLevels levels;
  final List<Package> packages;

  @override
  ConsumerState<_BillingEditor> createState() => _BillingEditorState();
}

class _BillingEditorState extends ConsumerState<_BillingEditor> {
  late final List<BillingBandDraft> _bands;
  late final Set<int> _enabledPresets;
  late final List<int> _extraLevels;
  late bool _allowCustom;
  final _newLevel = TextEditingController();
  bool _bandsInvalid = false;

  /// One Save for the page (#3072): what each block looked like when it was
  /// last loaded or saved, so the page knows whether it holds unsaved edits
  /// and a Save only sends the blocks that changed.
  late String _savedBands, _savedLevels, _savedVat;
  bool _saving = false;

  // New-package form (0042).
  final _pkgName = TextEditingController();
  final _pkgDays = TextEditingController();
  final _pkgPrice = TextEditingController();

  /// VAT rate of the package about to be added; '' = the workspace
  /// default. Like the price and the day count, it belongs to the package
  /// as created — a package already sold is deactivated and re-added
  /// rather than re-taxed.
  String _pkgVatRateId = '';

  /// Unsaved tariff-rate pick (#542); null = show the stored one.
  String? _tariffVatRateDraft;

  @override
  void initState() {
    super.initState();
    _bands = widget.bands.isEmpty
        ? [BillingBandDraft(toPct: 100, feeCents: 0, overageCents: 0)]
        : [
            for (final band in widget.bands)
              BillingBandDraft(
                toPct: band.toPct,
                feeCents: band.feeCents,
                overageCents: band.overageFeeCents,
              ),
          ];
    _enabledPresets = {...widget.levels.enabledPresets};
    _extraLevels = [...widget.levels.extraLevels]..sort();
    _allowCustom = widget.levels.allowCustom;
    _savedBands = _bandsSignature;
    _savedLevels = _levelsSignature;
    _savedVat = _tariffVatRateId;
  }

  String get _bandsSignature =>
      [for (final b in _bands) '${b.toPct}/${b.feeCents}/${b.overageCents}']
          .join(';');

  String get _levelsSignature =>
      '${(_enabledPresets.toList()..sort()).join(',')}|'
      '${_extraLevels.join(',')}|$_allowCustom';

  bool get _dirty =>
      _bandsSignature != _savedBands ||
      _levelsSignature != _savedLevels ||
      _tariffVatRateId != _savedVat;

  @override
  void dispose() {
    _newLevel.dispose();
    _pkgName.dispose();
    _pkgDays.dispose();
    _pkgPrice.dispose();
    super.dispose();
  }

  /// Shared guard of every editor save: traced failure + generic error
  /// snackbar; true = proceed to invalidate/confirm.
  Future<bool> _run(String message, Future<void> Function() action) {
    final l10n = context.l10n;
    return runGuarded(
      context,
      domain: 'money',
      message: message,
      errorText: l10n.workspaceGenericError,
      action: action,
    );
  }

  void _showSaved() {
    final l10n = context.l10n;
    AppSnack.success(context, l10n.billingSaved);
  }

  // ---- fee bands ----------------------------------------------------------

  void _addBand() {
    // Split the last band at its midpoint; the owner adjusts the boundary
    // in place afterwards.
    final from = _bands.length < 2 ? 0 : (_bands[_bands.length - 2].toPct ?? 0);
    final newTo = from + (100 - from) ~/ 2;
    if (newTo <= from || newTo >= 100) return;
    final last = _bands.last;
    setState(() {
      _bands.insert(
        _bands.length - 1,
        BillingBandDraft(
          toPct: newTo,
          feeCents: last.feeCents,
          overageCents: last.overageCents,
        ),
      );
    });
  }

  void _removeBand(BillingBandDraft draft) {
    // Deleting a row removes ITS lower boundary (the "from X %" the owner
    // sees on that row): the range merges into the PREVIOUS band, whose
    // upper bound extends. Merging forward instead made the NEXT row's
    // boundary vanish while the deleted row's label survived — reading as
    // "I deleted 25% but it deleted the 50%". The first row has no
    // previous band, so it keeps merging forward (its 0% is fixed).
    if (_bands.length <= 1) return;
    final index = _bands.indexOf(draft);
    setState(() {
      if (index > 0) {
        // Replace (not mutate) the previous draft: the row is keyed by
        // draft identity, so a fresh object rebuilds its boundary field
        // with the new initialValue.
        final previous = _bands[index - 1];
        _bands[index - 1] = BillingBandDraft(
          toPct: draft.toPct,
          feeCents: previous.feeCents,
          overageCents: previous.overageCents,
        );
      }
      _bands.remove(draft);
    });
  }

  /// Validates the drafts and returns the full band list, or null when the
  /// boundaries do not tile (0, 100] with valid fees.
  List<FeeBand>? _validatedBands() {
    final bands = <FeeBand>[];
    var from = 0;
    for (final draft in _bands) {
      final to = identical(draft, _bands.last) ? 100 : draft.toPct;
      final fee = draft.feeCents;
      final overage = draft.overageCents;
      if (to == null || to <= from || to > 100) return null;
      if (fee == null || overage == null) return null;
      bands.add(
        FeeBand(
          id: '',
          workspaceId: '',
          fromPct: from,
          toPct: to,
          feeCents: fee,
          overageFeeCents: overage,
        ),
      );
      from = to;
    }
    if (from != 100) return null;
    return bands;
  }

  /// The page's one Save (#3072): the fee bands, the levels and the
  /// tariff rate, each only when it changed. A refused or failed block stops
  /// the rest and leaves everything typed where it is.
  Future<void> _saveAll() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || _saving) return;
    final bands = _validatedBands();
    setState(() {
      _bandsInvalid = bands == null;
      _saving = bands != null;
    });
    if (bands == null) return;
    final commands = ref.read(commercialTermsProvider);
    try {
      if (_bandsSignature != _savedBands) {
        if (!await _run('fee band save failed',
            () => commands.replaceFeeBands(workspace.id, bands))) {
          return;
        }
        _savedBands = _bandsSignature;
        ref.invalidate(feeBandsProvider);
      }
      if (_levelsSignature != _savedLevels) {
        final levels = SubscriptionLevels(
          enabledPresets: _enabledPresets.toList()..sort(),
          extraLevels: List.of(_extraLevels),
          allowCustom: _allowCustom,
        );
        if (!await _run('subscription levels save failed',
            () => commands.setSubscriptionLevels(workspace.id, levels))) {
          return;
        }
        _savedLevels = _levelsSignature;
        ref.invalidate(subscriptionLevelsProvider);
      }
      if (_tariffVatRateId != _savedVat) {
        final vatRateId = _tariffVatRateId;
        if (!await _run(
            'tariff vat save failed',
            () => ref
                .read(workspaceRepositoryProvider)
                .setSubscriptionVatRate(workspace.id, vatRateId))) {
          return;
        }
        _savedVat = vatRateId;
        ref.invalidate(currentWorkspaceProvider);
      }
      if (mounted) _showSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---- subscription levels ------------------------------------------------

  void _addLevel() {
    final value = int.tryParse(_newLevel.text.trim());
    if (value == null || value < 1 || value > 100) return;
    setState(() {
      if (SubscriptionLevels.presets.contains(value)) {
        _enabledPresets.add(value);
      } else if (!_extraLevels.contains(value)) {
        _extraLevels
          ..add(value)
          ..sort();
      }
      _newLevel.clear();
    });
  }

  // ---- packages (0042) ----------------------------------------------------

  Future<void> _addPackage() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final name = _pkgName.text.trim();
    final days = int.tryParse(_pkgDays.text.trim());
    final price = parseCentsInput(_pkgPrice.text);
    if (name.isEmpty || days == null || days < 1 || price == null) return;
    if (!await _run(
      'package create failed',
      () => ref.read(commercialTermsProvider).createPackage(
            workspace.id,
            name: name,
            days: days,
            priceCents: price,
            vatRateId: _pkgVatRateId,
          ),
    )) {
      return;
    }
    _pkgName.clear();
    _pkgDays.clear();
    _pkgPrice.clear();
    setState(() => _pkgVatRateId = '');
    ref
      ..invalidate(allPackagesProvider)
      ..invalidate(packagesProvider);
    if (!mounted) return;
    _showSaved();
  }

  Future<void> _togglePackage(Package package) async {
    if (!await _run(
      'package toggle failed',
      () => ref
          .read(commercialTermsProvider)
          .updatePackage(package.id, active: !package.active),
    )) {
      return;
    }
    ref
      ..invalidate(allPackagesProvider)
      ..invalidate(packagesProvider);
  }

  // ---- build --------------------------------------------------------------

  /// The rate id the TARIFF (fee bands) taxes at: the unsaved pick, else
  /// the workspace's stored choice; '' = the workspace default (#542).
  String get _tariffVatRateId =>
      _tariffVatRateDraft ??
      ref.read(currentWorkspaceProvider).value?.subscriptionVatRateId ??
      '';

  /// The tariff's VAT percent, or null when the regime charges no VAT —
  /// the per-amount "incl. VAT x" helpers hang off it (#537/#542).
  double? get _tariffVatPercent {
    if (ref.read(currentWorkspaceProvider).value?.vatRegime !=
        'vat_registered') {
      return null;
    }
    final rates = ref.read(vatRatesProvider).value ?? const <VatRate>[];
    final chosen = _tariffVatRateId;
    // An inactive/unknown chosen rate falls back to the default — the
    // services resolution, mirrored server-side (0109).
    final rate = (chosen.isEmpty
            ? null
            : rates.where((r) => r.id == chosen && r.active).firstOrNull) ??
        rates.where((r) => r.isDefault && r.active).firstOrNull;
    return rate == null || rate.percent <= 0 ? null : rate.percent;
  }

  /// "incl. VAT 41.67" for a gross amount at the tariff rate (#537).
  String? _vatShare(AppLocalizations l10n, int? cents) {
    final percent = _tariffVatPercent;
    if (percent == null || cents == null || cents <= 0) return null;
    final share = centsToMajor(vatSplit(cents, percent).vatCents);
    return l10n.vatShareAmount(share);
  }

  Widget _bandRow(AppLocalizations l10n, int index, String currencySymbol) {
    final draft = _bands[index];
    return BillingBandRow(
      key: ObjectKey(draft),
      index: index,
      draft: draft,
      from: index == 0 ? 0 : _bands[index - 1].toPct ?? 0,
      isLast: index == _bands.length - 1,
      currencySymbol: currencySymbol,
      vatShare: (cents) => _vatShare(l10n, cents),
      // setState so the following rows' derived "from X %" labels and the
      // VAT-share helpers track the edit immediately (#194).
      onEdited: () => setState(() {}),
      onRemove: () => _removeBand(draft),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final chargesVat = workspace?.vatRegime == 'vat_registered';
    final rates = ref.watch(vatRatesProvider).value ?? const <VatRate>[];
    final currencySymbol = moneyFormat(workspace?.currencyCode).currencySymbol;
    final fields = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BillingSectionHeader(
          title: l10n.billingFeeBands,
          anchor: HelpAnchor.billingFeeBands,
        ),
        // #537 — the one VAT fact this whole page's prices share: they
        // are GROSS, taxed at the tariff's rate (#542: configurable,
        // default = the workspace default).
        BillingVatHint(
          chargesVat: chargesVat,
          rates: rates,
          tariffRateId: _tariffVatRateId,
        ),
        for (var i = 0; i < _bands.length; i++)
          _bandRow(l10n, i, currencySymbol),
        if (_bandsInvalid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.billingBandsInvalid,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        // #542 — the rate the tariff amounts above tax at; saves on
        // pick, like a toggle (the bands' Save covers the bands only).
        VatRateField(
          dropdownKey: const ValueKey('billing-tariff-vat'),
          rates: rates,
          value: _tariffVatRateId,
          onChanged: (id) => setState(() => _tariffVatRateDraft = id),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('billing-add-band'),
            onPressed: _addBand,
            icon: const Icon(Icons.add),
            label: Text(l10n.billingAddBand),
          ),
        ),
        const Divider(height: 32),
        BillingSectionHeader(
          title: l10n.billingLevels,
          anchor: HelpAnchor.billingLevels,
        ),
        const SizedBox(height: 8),
        BillingLevelChips(
          enabledPresets: _enabledPresets,
          extraLevels: _extraLevels,
          onPresetSelected: (preset, {required selected}) => setState(() {
            if (selected) {
              _enabledPresets.add(preset);
            } else {
              _enabledPresets.remove(preset);
            }
          }),
          onExtraDeleted: (level) =>
              setState(() => _extraLevels.remove(level)),
        ),
        BillingNewLevelRow(controller: _newLevel, onAdd: _addLevel),
        SwitchListTile(
          key: const ValueKey('billing-allow-custom'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.billingAllowCustom),
          value: _allowCustom,
          onChanged: (v) => setState(() => _allowCustom = v),
        ),
        const Divider(height: 32),
        BillingSectionHeader(
          title: l10n.billingPackages,
          anchor: HelpAnchor.billingPackages,
        ),
        Text(
          l10n.billingPackagesHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final package in widget.packages)
          // #537 — currency + the pack's own VAT rate on the row.
          BillingPackageTile(
            package: package,
            currencyCode: workspace?.currencyCode ?? '',
            chargesVat: chargesVat,
            rates: rates,
            onToggle: () => _togglePackage(package),
          ),
        const SizedBox(height: 8),
        BillingSectionHeader(
          title: l10n.billingNewPackage,
          anchor: HelpAnchor.billingPackageNew,
          small: true,
        ),
        BillingNewPackageRow(
          currencySymbol: currencySymbol,
          name: _pkgName,
          days: _pkgDays,
          price: _pkgPrice,
          onAdd: _addPackage,
        ),
        VatRateField(
          key: const ValueKey('billing-vat-rate-field'),
          rates: rates,
          value: _pkgVatRateId,
          onChanged: (id) => setState(() => _pkgVatRateId = id),
        ),
        if (ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.carnets))
          ...const [Divider(height: 32), CarnetsEditor()], // #1279
      ],
    );
    // One Save for the blocks above (#3072), in the scaffold's bottom bar so
    // it never scrolls away and a snackbar rises above it; the add rows
    // below the packs create records of their own and keep their own buttons.
    return UnsavedChangesGuard(
      isDirty: () => _dirty,
      child: Scaffold(
        appBar: widget.appBar,
        body: fields,
        bottomNavigationBar: Material(
          elevation: 3,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                key: const ValueKey('billing-save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _saving ? null : _saveAll,
                icon: Icon(_saving ? Icons.hourglass_top : Icons.save),
                label: Text(l10n.commonSave),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
