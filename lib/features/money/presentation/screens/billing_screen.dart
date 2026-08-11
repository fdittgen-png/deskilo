// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/fee_band.dart';
import '../../domain/package.dart';
import '../../domain/subscription_levels.dart';
import '../../providers/money_providers.dart';
import '../../domain/vat_rate.dart';
import '../vat_price_label.dart';
import '../widgets/vat_rate_field.dart';

/// Owner-only billing editor (#128, ADR 0008): the fee bands pricing the
/// percentage subscriptions, and the subscription levels members may pick
/// from. Replaces the plans editor.
class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bandsAsync = ref.watch(feeBandsProvider);
    final levelsAsync = ref.watch(subscriptionLevelsProvider);
    final packagesAsync = ref.watch(allPackagesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.billingTitle ?? 'Billing')),
      body: switch ((bandsAsync, levelsAsync, packagesAsync)) {
        (
          AsyncData(value: final bands),
          AsyncData(value: final levels),
          AsyncData(value: final packages)
        ) =>
          _BillingEditor(bands: bands, levels: levels, packages: packages),
        (AsyncError(), _, _) || (_, AsyncError(), _) || (_, _, AsyncError()) =>
          Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }
}

/// One editable band row: the upper boundary plus its two prices. The lower
/// boundary is derived from the previous row, so the set always tiles
/// (0, 100] once every `toPct` is valid.
class _BandDraft {
  _BandDraft({required this.toPct, required this.feeCents, required this.overageCents});

  int? toPct;
  int? feeCents;
  int? overageCents;
}

class _BillingEditor extends ConsumerStatefulWidget {
  const _BillingEditor({
    required this.bands,
    required this.levels,
    required this.packages,
  });

  final List<FeeBand> bands;
  final SubscriptionLevels levels;
  final List<Package> packages;

  @override
  ConsumerState<_BillingEditor> createState() => _BillingEditorState();
}

class _BillingEditorState extends ConsumerState<_BillingEditor> {
  late final List<_BandDraft> _bands;
  late final Set<int> _enabledPresets;
  late final List<int> _extraLevels;
  late bool _allowCustom;
  final _newLevel = TextEditingController();
  bool _bandsInvalid = false;

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
        ? [_BandDraft(toPct: 100, feeCents: 0, overageCents: 0)]
        : [
            for (final band in widget.bands)
              _BandDraft(
                toPct: band.toPct,
                feeCents: band.feeCents,
                overageCents: band.overageFeeCents,
              ),
          ];
    _enabledPresets = {...widget.levels.enabledPresets};
    _extraLevels = [...widget.levels.extraLevels]..sort();
    _allowCustom = widget.levels.allowCustom;
  }

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
    final l10n = AppLocalizations.of(context);
    return runGuarded(
      context,
      domain: 'money',
      message: message,
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: action,
    );
  }

  void _showSaved() {
    final l10n = AppLocalizations.of(context);
    AppSnack.success(context, l10n?.billingSaved ?? 'Saved.');
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
        _BandDraft(
          toPct: newTo,
          feeCents: last.feeCents,
          overageCents: last.overageCents,
        ),
      );
    });
  }

  void _removeBand(_BandDraft draft) {
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
        _bands[index - 1] = _BandDraft(
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

  Future<void> _saveBands() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final bands = _validatedBands();
    if (bands == null) {
      setState(() => _bandsInvalid = true);
      return;
    }
    setState(() => _bandsInvalid = false);
    if (!await _run(
      'fee band save failed',
      () => ref
          .read(moneyRepositoryProvider)
          .replaceFeeBands(workspace.id, bands),
    )) {
      return;
    }
    ref.invalidate(feeBandsProvider);
    if (!mounted) return;
    _showSaved();
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

  Future<void> _saveLevels() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final levels = SubscriptionLevels(
      enabledPresets: _enabledPresets.toList()..sort(),
      extraLevels: List.of(_extraLevels),
      allowCustom: _allowCustom,
    );
    if (!await _run(
      'subscription levels save failed',
      () => ref
          .read(moneyRepositoryProvider)
          .setSubscriptionLevels(workspace.id, levels),
    )) {
      return;
    }
    ref.invalidate(subscriptionLevelsProvider);
    if (!mounted) return;
    _showSaved();
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
      () => ref.read(moneyRepositoryProvider).createPackage(
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
    ref.invalidate(allPackagesProvider);
    ref.invalidate(packagesProvider);
    if (!mounted) return;
    _showSaved();
  }

  Future<void> _togglePackage(Package package) async {
    if (!await _run(
      'package toggle failed',
      () => ref
          .read(moneyRepositoryProvider)
          .updatePackage(package.id, active: !package.active),
    )) {
      return;
    }
    ref.invalidate(allPackagesProvider);
    ref.invalidate(packagesProvider);
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

  /// Owner picked a tariff rate: persist immediately, like a toggle.
  Future<void> _saveTariffVat(String vatRateId) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _tariffVatRateDraft = vatRateId);
    if (!await _run(
      'tariff vat save failed',
      () => ref
          .read(workspaceRepositoryProvider)
          .setSubscriptionVatRate(workspace.id, vatRateId),
    )) {
      return;
    }
    ref.invalidate(currentWorkspaceProvider);
    _showSaved();
  }

  /// "incl. VAT 41.67" for a gross amount at the tariff rate (#537).
  String? _vatShare(AppLocalizations? l10n, int? cents) {
    final percent = _tariffVatPercent;
    if (percent == null || cents == null || cents <= 0) return null;
    final share = centsToMajor(vatSplit(cents, percent).vatCents);
    return l10n?.vatShareAmount(share) ?? 'incl. VAT $share';
  }

  Widget _bandRow(AppLocalizations? l10n, int index) {
    final draft = _bands[index];
    final isLast = index == _bands.length - 1;
    final from = index == 0 ? 0 : _bands[index - 1].toPct;
    return Padding(
      key: ObjectKey(draft),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              l10n?.billingBandFrom(from ?? 0) ?? 'from ${from ?? 0}%',
            ),
          ),
          Expanded(
            child: TextFormField(
              enabled: !isLast,
              initialValue: '${draft.toPct ?? ''}',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n?.billingBandTo ?? 'To %',
              ),
              // setState so the following rows' derived "from X %" labels
              // track the boundary immediately (#194). The keyed rows keep
              // their field edit state: initialValue is only read on the
              // element's first build.
              onChanged: (raw) =>
                  setState(() => draft.toPct = int.tryParse(raw.trim())),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: centsToMajor(draft.feeCents ?? 0),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n?.billingBandFee ?? 'Monthly fee',
                helperText: _vatShare(l10n, draft.feeCents),
              ),
              // setState so the VAT-share helper tracks the amount live.
              onChanged: (raw) => setState(
                  () => draft.feeCents = parseCentsInput(raw)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: centsToMajor(draft.overageCents ?? 0),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n?.billingBandOverage ?? 'Overage',
                helperText: _vatShare(l10n, draft.overageCents),
              ),
              onChanged: (raw) => setState(
                  () => draft.overageCents = parseCentsInput(raw)),
            ),
          ),
          if (isLast)
            // The last band always ends at 100% and cannot be removed; hide
            // the button instead of disabling it (#194) but keep the row
            // columns aligned with the IconButton's footprint.
            const SizedBox(width: 48)
          else
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: l10n?.billingRemoveBand ?? 'Remove band',
              onPressed: () => _removeBand(draft),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n?.billingFeeBands ?? 'Fee bands',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        // #537 — the one VAT fact this whole page's prices share: they
        // are GROSS, taxed at the tariff's rate (#542: configurable,
        // default = the workspace default).
        Builder(builder: (context) {
          final chargesVat =
              ref.watch(currentWorkspaceProvider).value?.vatRegime ==
                  'vat_registered';
          final tariffRateId = _tariffVatRateId;
          final rate = vatRateSuffix(
            chargesVat: chargesVat,
            rates: ref.watch(vatRatesProvider).value ?? const [],
            vatRateId: tariffRateId,
          );
          if (rate == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              tariffRateId.isEmpty
                  ? (l10n?.billingPricesVatHint(rate) ??
                      'Prices are gross — VAT $rate (the workspace '
                          'default rate) is included.')
                  : (l10n?.billingTariffVatHint(rate) ??
                      'Prices are gross — VAT $rate (the tariff rate) '
                          'is included.'),
              key: const ValueKey('billing-vat-hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }),
        for (var i = 0; i < _bands.length; i++) _bandRow(l10n, i),
        if (_bandsInvalid)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n?.billingBandsInvalid ??
                  'Bands must increase and end at 100%.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        // #542 — the rate the tariff amounts above tax at; saves on
        // pick, like a toggle (the bands' Save covers the bands only).
        VatRateField(
          dropdownKey: const ValueKey('billing-tariff-vat'),
          rates: ref.watch(vatRatesProvider).value ?? const [],
          value: _tariffVatRateId,
          onChanged: _saveTariffVat,
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: _addBand,
              icon: const Icon(Icons.add),
              label: Text(l10n?.billingAddBand ?? 'Add band'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _saveBands,
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
          ],
        ),
        const Divider(height: 32),
        Text(
          l10n?.billingLevels ?? 'Subscription levels',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final preset in SubscriptionLevels.presets)
              FilterChip(
                label: Text(l10n?.percentValue(preset) ?? '$preset%'),
                selected: _enabledPresets.contains(preset),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _enabledPresets.add(preset);
                  } else {
                    _enabledPresets.remove(preset);
                  }
                }),
              ),
            for (final level in _extraLevels)
              InputChip(
                label: Text(l10n?.percentValue(level) ?? '$level%'),
                onDeleted: () => setState(() => _extraLevels.remove(level)),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newLevel,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n?.billingLevelValue ?? 'Level (1–100)',
                ),
                onSubmitted: (_) => _addLevel(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n?.billingAddLevel ?? 'Add level',
              onPressed: _addLevel,
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            l10n?.billingAllowCustom ?? 'Allow negotiated custom value',
          ),
          value: _allowCustom,
          onChanged: (v) => setState(() => _allowCustom = v),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saveLevels,
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ),
        const Divider(height: 32),
        Text(
          l10n?.billingPackages ?? 'Day packages',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          l10n?.billingPackagesHint ??
              'Members on the package plan buy these when their days run '
                  'out.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final package in widget.packages)
          ListTile(
            key: ValueKey('package-${package.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(package.name),
            // #537 — currency + the pack's own VAT rate on the row:
            // "2 days · 200.00 EUR · incl. VAT 20 %".
            subtitle: Builder(builder: (context) {
              final currencyCode = ref
                      .watch(currentWorkspaceProvider)
                      .value
                      ?.currencyCode ??
                  '';
              final price =
                  '${centsToMajor(package.priceCents)} $currencyCode'
                      .trim();
              final summary =
                  l10n?.billingPackageSummary(package.days, price) ??
                      '${package.days} days · $price';
              final rate = vatRateSuffix(
                chargesVat: ref
                        .watch(currentWorkspaceProvider)
                        .value
                        ?.vatRegime ==
                    'vat_registered',
                rates: ref.watch(vatRatesProvider).value ?? const [],
                vatRateId: package.vatRateId,
              );
              final vatLabel = rate == null
                  ? null
                  : (l10n?.priceVatIncluded(rate) ?? 'incl. VAT $rate');
              return Text(
                  vatLabel == null ? summary : '$summary · $vatLabel');
            }),
            trailing: Switch(
              value: package.active,
              onChanged: (_) => _togglePackage(package),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          l10n?.billingNewPackage ?? 'New package',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _pkgName,
                decoration: InputDecoration(
                  labelText: l10n?.billingPackageName ?? 'Name',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _pkgDays,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n?.billingPackageDays ?? 'Days',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _pkgPrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n?.billingPackagePrice ?? 'Price',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: l10n?.billingAddPackage ?? 'Add package',
              onPressed: _addPackage,
            ),
          ],
        ),
        VatRateField(
          rates: ref.watch(vatRatesProvider).value ?? const [],
          value: _pkgVatRateId,
          onChanged: (id) => setState(() => _pkgVatRateId = id),
        ),
      ],
    );
  }
}
