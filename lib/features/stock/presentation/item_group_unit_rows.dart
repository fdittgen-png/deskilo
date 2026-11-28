// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- an item and the units of its group: the unit it is SOLD in (with what one of it makes of the inventory unit and its price) and
// the unit it is BOUGHT in (with its factor), each as it is in force now. An item without a value of its own reads its group's current one
// and says so ("From Mugs since 3 Dec"); it can take its own, and give it back to the group's. One row per block; the dialog of the item's
// group holds them and makes the calls.
import 'package:flutter/material.dart';

import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/item_groups.dart';
import '../domain/purchase_factor.dart';
import '../domain/workspace_units.dart';
import 'item_group_units.dart';

/// The blocks of unit parameters an item can take its own of.
enum ItemUnitBlock {
  sale([groupParamSaleUnit, groupParamSaleFactorNum, groupParamSaleFactorDen, groupParamSalePrice]),
  purchase([groupParamPurchaseUnit, groupParamPurchaseFactorNum, groupParamPurchaseFactorDen]);

  const ItemUnitBlock(this.parameters);

  /// The parameters of the block, the unit first.
  final List<String> parameters;
}

/// The unit blocks as they read for an item: the unit, its factor and its price, as one line.
String itemUnitBlockText(AppLocalizations l10n, AppFormat format, ItemUnitBlock block, ItemEffective effective) {
  Object? value(String p) => effective.params[p]?.value;
  final unit = value(block.parameters.first);
  if (unit == null) return l10n.itemGroupNotSet;
  final numKey = block.parameters[1];
  final factor = value(numKey) == null ? null : purchaseFactorText((value(numKey)! as num).toInt(), ((value(block.parameters[2]) ?? 1) as num).toInt());
  final price = block == ItemUnitBlock.sale && value(groupParamSalePrice) != null ? format.money((value(groupParamSalePrice)! as num).toInt()) : null;
  return [unit, ?factor, ?price].join(' · ');
}

/// One block of an item: what is in force, where it comes from, and the ways to take its own or give it back.
class ItemGroupUnitRow extends StatelessWidget {
  const ItemGroupUnitRow({super.key, required this.block, required this.effective, required this.onSetOwn, required this.onUseGroup});

  final ItemUnitBlock block;
  final ItemEffective effective;
  final VoidCallback onSetOwn;
  final VoidCallback onUseGroup;

  bool get _own => block.parameters.any((p) => effective.params[p]?.own ?? false);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final name = block.name;
    final lead = effective.params[block.parameters.first];
    final label = block == ItemUnitBlock.sale ? l10n.itemGroupSaleUnit : l10n.itemGroupPurchaseUnit;
    final source = _own
        ? l10n.itemGroupOwn
        : (lead == null || lead.group == null ? '' : (lead.since == null ? l10n.itemGroupFrom(lead.group!) : l10n.itemGroupFromSince(lead.group!, format.date(lead.since!))));
    return Padding(
      key: ValueKey('item-group-unit-$name'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.labelWithValue(label, itemUnitBlockText(l10n, format, block, effective))),
          if (source.isNotEmpty) Text(source, key: ValueKey('item-group-unit-source-$name'), style: Theme.of(context).textTheme.bodySmall),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton(key: ValueKey('item-group-unit-own-$name'), onPressed: onSetOwn, child: Text(l10n.itemGroupSetOwn)),
              if (_own) TextButton(key: ValueKey('item-group-unit-use-$name'), onPressed: onUseGroup, child: Text(l10n.itemGroupUseGroup)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The fields an item takes its own unit with: those of [block], started from what is in force.
({GroupUnitProposals fields, List<Widget> Function(AppLocalizations, void Function(void Function()), VoidCallback) widgets, Map<String, Object?> Function() values}) ownUnitForm({
  required ItemUnitBlock block,
  required ItemEffective effective,
  required AppFormat format,
  required String workspaceId,
  required List<WorkspaceUnit> units,
}) {
  final started = GroupUnitProposals.initial({for (final e in effective.params.entries) e.key: e.value.value}, format);
  final form = GroupUnitProposals(FormControllers(started), format, workspaceId, units);
  return (
    fields: form,
    widgets: block == ItemUnitBlock.sale ? form.saleWidgets : form.purchaseWidgets,
    values: block == ItemUnitBlock.sale ? form.saleParameters : form.purchaseParameters,
  );
}
