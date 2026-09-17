// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/carnets.dart';
import '../../providers/credit_providers.dart';

/// #1279 — the carnet catalogue in Billing: what the workspace sells, each
/// with its switch, and a form to add one. A carnet already sold is
/// switched off rather than edited, like a day package: the price a member
/// paid stays the price of what they bought.
class CarnetsEditor extends ConsumerStatefulWidget {
  const CarnetsEditor({super.key});

  @override
  ConsumerState<CarnetsEditor> createState() => _CarnetsEditorState();
}

class _CarnetsEditorState extends ConsumerState<CarnetsEditor> {
  final _name = TextEditingController();
  final _halfDays = TextEditingController();
  final _price = TextEditingController();
  final _validity = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _halfDays.dispose();
    _price.dispose();
    _validity.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final halfDays = int.tryParse(_halfDays.text.trim());
    final price = parseCentsInput(_price.text);
    final validityRaw = _validity.text.trim();
    final validity = validityRaw.isEmpty ? null : int.tryParse(validityRaw);
    if (name.isEmpty ||
        halfDays == null ||
        halfDays < 1 ||
        halfDays > 500 ||
        price == null ||
        (validityRaw.isNotEmpty && validity == null)) {
      return;
    }
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'carnet create failed',
      action: () => addCarnet(ref,
          name: name,
          halfDays: halfDays,
          priceCents: price,
          validityMonths: validity),
    );
    if (ok) {
      _name.clear();
      _halfDays.clear();
      _price.clear();
      _validity.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(creditProductsProvider).value ?? const [];
    return Column(
      key: const ValueKey('carnets-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n?.carnetsTitle ?? 'Carnets',
            style: Theme.of(context).textTheme.titleMedium),
        if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(l10n?.carnetsEmpty ?? 'No carnet yet.'),
          ),
        for (final p in products)
          SwitchListTile(
            key: ValueKey('carnet-${p.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(p.name),
            subtitle: Text(l10n?.carnetSummary(
                    p.halfDays, centsToMajor(p.priceCents)) ??
                '${p.halfDays} half-days · ${centsToMajor(p.priceCents)}'),
            value: p.active,
            onChanged: (on) => runGuarded(
              context,
              domain: 'money',
              message: 'carnet toggle failed',
              action: () => setCarnetActive(ref, p.id, on),
            ),
          ),
        TextField(
          key: const ValueKey('carnet-name'),
          controller: _name,
          decoration:
              InputDecoration(labelText: l10n?.carnetName ?? 'Name'),
        ),
        Row(children: [
          Expanded(
            child: TextField(
              key: const ValueKey('carnet-half-days'),
              controller: _halfDays,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: l10n?.carnetHalfDays ?? 'Half-days'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              key: const ValueKey('carnet-price'),
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: l10n?.carnetPrice ?? 'Price'),
            ),
          ),
        ]),
        TextField(
          key: const ValueKey('carnet-validity'),
          controller: _validity,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: l10n?.carnetValidity ??
                  'Valid for (months, empty = never expires)'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const ValueKey('carnet-add'),
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(l10n?.carnetAdd ?? 'Add carnet'),
          ),
        ),
      ],
    );
  }
}
