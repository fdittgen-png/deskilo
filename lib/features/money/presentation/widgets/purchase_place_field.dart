// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2573 — where the cost of a purchase line belongs: no particular place, a
// site of the space, or one of its levels or offices (each office under its
// level). The server checks that the place is the space's own.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/purchase.dart';
import '../../providers/purchase_providers.dart';

class PurchasePlaceField extends ConsumerWidget {
  const PurchasePlaceField({
    required this.workspaceId,
    required this.value,
    required this.onChanged,
    required this.fieldKey,
    super.key,
  });

  /// The control's key, for the task recorder and the tests.
  final String fieldKey;
  final String workspaceId;
  final PurchasePlace? value;
  final ValueChanged<PurchasePlace?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final places =
        ref.watch(purchasePlacesProvider(workspaceId)).value ??
        const <PurchasePlace>[];
    // A space without sites or a plan has nothing to choose from.
    if (places.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<PurchasePlace?>(
      key: ValueKey(fieldKey),
      initialValue: places.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.purchasesPlace),
      items: [
        DropdownMenuItem<PurchasePlace?>(child: Text(l10n.purchasesPlaceNone)),
        for (final p in places)
          DropdownMenuItem<PurchasePlace?>(
            value: p,
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: switch (p.kind) {
                  'level' => AppSpacing.md,
                  'office' => AppSpacing.lg + AppSpacing.md,
                  _ => 0,
                },
              ),
              child: Text(p.name, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
