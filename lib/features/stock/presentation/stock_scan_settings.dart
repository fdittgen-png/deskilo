// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- the scanner's two device settings, in Stock settings: the longest gap between two keys of one
// scan and what ends the code. They are kept on this device (one handheld types faster than another); whether a
// business uses a scanner at all, and whether a repeated scan adds one or asks, are the business's own settings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/scan/scan_detector.dart';
import '../../../core/scan/scan_prefs.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import 'stock_scan_hint.dart';

class StockScanSettings extends ConsumerStatefulWidget {
  const StockScanSettings({super.key});

  @override
  ConsumerState<StockScanSettings> createState() => _StockScanSettingsState();
}

class _StockScanSettingsState extends ConsumerState<StockScanSettings> {
  final _interval = TextEditingController();
  ScanTerminator? _terminator;
  ScanConfirm? _confirm;
  String? _error;
  bool _seeded = false;

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save(ScanPrefs current) async {
    final l10n = context.l10n;
    final ms = int.tryParse(_interval.text.trim());
    if (ms == null || ms < ScanPrefs.minIntervalMs || ms > ScanPrefs.maxIntervalMs) {
      setState(() => _error = l10n.stockScanIntervalInvalid);
      return;
    }
    setState(() => _error = null);
    await ref.read(scanPrefsProvider.notifier).save(current.copyWith(intervalMs: ms, terminator: _terminator, confirm: _confirm));
    if (mounted) AppSnack.success(context, l10n.valuationSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefs = ref.watch(scanPrefsProvider).value;
    if (prefs == null) return const SizedBox.shrink();
    if (!_seeded) {
      _seeded = true;
      _interval.text = '${prefs.intervalMs}';
      _terminator = prefs.terminator;
      _confirm = prefs.confirm;
    }
    String label(ScanTerminator t) => switch (t) {
      ScanTerminator.either => l10n.stockScanTerminatorEither,
      ScanTerminator.enter => l10n.stockScanTerminatorEnter,
      ScanTerminator.tab => l10n.stockScanTerminatorTab,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.stockScanSettingsTitle, style: Theme.of(context).textTheme.titleMedium)),
            HelpDot(l10n.stockScanHelp, anchor: HelpAnchor.moneyStockScanning),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.stockScanSettingsHint, style: Theme.of(context).textTheme.bodySmall),
        const StockScanHint(),
        const FormGap(),
        AppTextField(
          key: const ValueKey('stock-scan-interval'),
          controller: _interval,
          fieldKey: 'interval',
          label: l10n.stockScanInterval,
          error: _error,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const FormGap(),
        AppDropdownField<ScanTerminator>(
          key: const ValueKey('stock-scan-terminator'),
          label: l10n.stockScanTerminator,
          value: _terminator ?? prefs.terminator,
          items: [for (final t in ScanTerminator.values) (t, label(t))],
          onChanged: (v) => setState(() => _terminator = v),
        ),
        const FormGap(),
        Text(l10n.stockScanConfirm, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<ScanConfirm>(
          key: const ValueKey('stock-scan-confirm'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: ScanConfirm.none, label: Text(l10n.stockScanConfirmNone)),
            ButtonSegment(value: ScanConfirm.vibrate, label: Text(l10n.stockScanConfirmVibrate)),
            ButtonSegment(value: ScanConfirm.click, label: Text(l10n.stockScanConfirmClick)),
          ],
          selected: {_confirm ?? prefs.confirm},
          onSelectionChanged: (s) => setState(() => _confirm = s.first),
        ),
        const FormGap(),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const ValueKey('stock-scan-save'),
            onPressed: () => _save(prefs),
            child: Text(l10n.stockScanSave),
          ),
        ),
      ],
    );
  }
}
