// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- the unit a put-away is counted in: the order line's own, or another unit the item converts from (a carton ordered, pieces on the
// shelf). The server converts by the item's factor, keeps the unit entered with the allocation and counts it against the line in the line's unit.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/dropdown_field.dart';

class PutAwayUnitField extends StatelessWidget {
  const PutAwayUnitField({super.key, required this.units, required this.value, required this.onChanged});

  /// The units offered, the line's own among them.
  final List<String> units;

  /// The unit now chosen.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => AppDropdownField<String>(
    label: context.l10n.purchaseOrderUnit,
    value: value,
    items: [for (final u in units) (u, u)],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}
