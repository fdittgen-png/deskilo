// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/asset_valuation.dart';

/// #2576 — types in the valuation of one asset instead of importing a file.
/// The row is written as the documented CSV and read by the same strict
/// reader, so a typed figure and an imported one are judged alike. Returns
/// the CSV text once it is usable.
Future<String?> showValuationManualDialog(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _ManualDialog());

class _ManualDialog extends StatefulWidget {
  const _ManualDialog();

  @override
  State<_ManualDialog> createState() => _ManualDialogState();
}

class _ManualDialogState extends State<_ManualDialog> {
  static const _amountCount = 6;

  final _asset = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _currency = TextEditingController();
  final _reference = TextEditingController();
  final _amounts = [
    for (var i = 0; i < _amountCount; i++) TextEditingController(),
  ];
  var _basis = 'book';
  var _invalid = false;

  @override
  void dispose() {
    for (final c in [_asset, _from, _to, _currency, _reference, ..._amounts]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _csv => [
    valuationHeaderLine,
    [
      _asset.text,
      _basis,
      _from.text,
      _to.text,
      _currency.text,
      for (final a in _amounts) a.text,
      _reference.text,
    ].map(valuationCsvCell).join(','),
  ].join('\n');

  void _use() {
    if (!readValuationCsv(_csv).usable) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(_csv);
  }

  Widget _field(String key, TextEditingController c, String label) =>
      AppTextField(key: ValueKey(key), controller: c, label: label);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amountLabels = [
      l10n.valuationManualOpening,
      l10n.valuationManualAdditions,
      l10n.valuationManualDisposals,
      l10n.valuationManualDepreciation,
      l10n.valuationManualImpairment,
      l10n.valuationManualClosing,
    ];
    return AlertDialog(
      title: Text(l10n.valuationManual),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('valuation-manual-asset', _asset, l10n.valuationManualAsset),
            DropdownButtonFormField<String>(
              key: const ValueKey('valuation-manual-basis'),
              isExpanded: true,
              initialValue: _basis,
              decoration: InputDecoration(labelText: l10n.valuationManualBasis),
              items: [
                DropdownMenuItem(
                  value: 'book',
                  child: Text(l10n.valuationBasisBook),
                ),
                DropdownMenuItem(
                  value: 'tax',
                  child: Text(l10n.valuationBasisTax),
                ),
              ],
              onChanged: (v) => setState(() => _basis = v ?? _basis),
            ),
            _field('valuation-manual-from', _from, l10n.valuationManualFrom),
            _field('valuation-manual-to', _to, l10n.valuationManualTo),
            _field(
              'valuation-manual-currency',
              _currency,
              l10n.valuationManualCurrency,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.valuationManualAmountsHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (var i = 0; i < _amountCount; i++)
              _field(
                'valuation-manual-amount-$i',
                _amounts[i],
                amountLabels[i],
              ),
            _field(
              'valuation-manual-reference',
              _reference,
              l10n.valuationManualReference,
            ),
            if (_invalid)
              Text(
                l10n.valuationManualInvalid,
                key: const ValueKey('valuation-manual-invalid'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('valuation-manual-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('valuation-manual-use'),
          onPressed: _use,
          child: Text(l10n.valuationManualUse),
        ),
      ],
    );
  }
}
