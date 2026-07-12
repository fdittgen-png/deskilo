// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/fee_band.dart';
import '../../domain/subscription_levels.dart';
import '../../providers/money_providers.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.billingTitle ?? 'Billing')),
      body: switch ((bandsAsync, levelsAsync)) {
        (AsyncData(value: final bands), AsyncData(value: final levels)) =>
          _BillingEditor(bands: bands, levels: levels),
        (AsyncError(), _) || (_, AsyncError()) => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
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
  const _BillingEditor({required this.bands, required this.levels});

  final List<FeeBand> bands;
  final SubscriptionLevels levels;

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
    super.dispose();
  }

  String _money(int cents) =>
      cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);

  int? _parseCents(String raw) {
    if (raw.trim().isEmpty) return 0;
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  Future<void> _showError() async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.workspaceGenericError ??
              'Something went wrong. Please try again.',
        ),
      ),
    );
  }

  void _showSaved() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n?.billingSaved ?? 'Saved.')),
    );
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
    // The removed range merges into the following band (its lower boundary
    // is derived from the new previous row).
    if (_bands.length <= 1) return;
    setState(() => _bands.remove(draft));
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
    try {
      await ref
          .read(moneyRepositoryProvider)
          .replaceFeeBands(workspace.id, bands);
    } catch (e, st) {
      debugPrint('fee band save failed: $e\n$st');
      TraceLogger.instance
          .error('money', 'fee band save failed', error: e, stackTrace: st);
      if (!mounted) return;
      await _showError();
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
    try {
      await ref
          .read(moneyRepositoryProvider)
          .setSubscriptionLevels(workspace.id, levels);
    } catch (e, st) {
      debugPrint('subscription levels save failed: $e\n$st');
      TraceLogger.instance.error('money', 'subscription levels save failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      await _showError();
      return;
    }
    ref.invalidate(subscriptionLevelsProvider);
    if (!mounted) return;
    _showSaved();
  }

  // ---- build --------------------------------------------------------------

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
              initialValue: _money(draft.feeCents ?? 0),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n?.billingBandFee ?? 'Monthly fee',
              ),
              onChanged: (raw) => draft.feeCents = _parseCents(raw),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: _money(draft.overageCents ?? 0),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n?.billingBandOverage ?? 'Overage',
              ),
              onChanged: (raw) => draft.overageCents = _parseCents(raw),
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
      ],
    );
  }
}
