// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 — what a bill line bought: a catalogue item of the space, how many
// of it and in what unit. Offered while the purchase figures are on; the
// bill dialog reads the choice through [onChanged].
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/features/enabled_feature_keys.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../providers/money_providers.dart';

/// The item, quantity and unit of a bill line, as typed: [itemId] null
/// buys no item.
typedef PurchaseItemEntry = ({String? itemId, String quantity, String unit});

class PurchaseItemFields extends ConsumerStatefulWidget {
  const PurchaseItemFields({super.key, required this.onChanged});

  final ValueChanged<PurchaseItemEntry> onChanged;

  @override
  ConsumerState<PurchaseItemFields> createState() => _PurchaseItemFieldsState();
}

class _PurchaseItemFieldsState extends ConsumerState<PurchaseItemFields> {
  final _quantity = TextEditingController();
  final _unit = TextEditingController();
  String? _itemId;

  @override
  void dispose() {
    _quantity.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _report() => widget.onChanged((
    itemId: _itemId,
    quantity: _quantity.text,
    unit: _unit.text,
  ));

  @override
  Widget build(BuildContext context) {
    final on = featureOn(
      ref.watch(enabledFeatureKeysProvider),
      purchaseAnalyticsKey,
      byDefault: false,
    );
    if (!on) return const SizedBox.shrink();
    final l10n = context.l10n;
    final itemsRead = ref.watch(servicesProvider);
    // #3680 — the choices are offered only from a list that was read.
    final standIn = ReadsAnswer.of([itemsRead]).standIn(
      onRetry: () => ref.invalidate(servicesProvider),
    );
    if (standIn != null) return standIn;
    final items = itemsRead.requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          key: const ValueKey('purchase-item'),
          initialValue: _itemId,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.purchasesItem),
          items: [
            DropdownMenuItem<String?>(child: Text(l10n.purchasesNoItem)),
            for (final i in items)
              DropdownMenuItem<String?>(value: i.id, child: Text(i.name)),
          ],
          onChanged: (v) {
            setState(() => _itemId = v);
            _report();
          },
        ),
        if (_itemId != null) ...[
          AppTextField(
            key: const ValueKey('purchase-quantity'),
            controller: _quantity,
            label: l10n.purchasesQuantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _report(),
          ),
          AppTextField(
            key: const ValueKey('purchase-unit'),
            controller: _unit,
            label: l10n.purchasesUnit,
            maxLength: 20,
            onChanged: (_) => _report(),
          ),
        ],
      ],
    );
  }
}
