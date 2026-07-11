// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/accessory.dart';
import '../../providers/accessory_providers.dart';

/// Compact display of the ACTIVE accessories assigned to one seat, for the
/// plan screen's booking sheets (#169, epic #163).
///
/// Self-loading: watches the accessory catalog and the seat assignments
/// itself, so the (synchronously built) sheets never block on the fetch —
/// while loading, on error or when the seat has no accessories it renders
/// nothing at all (no header, no empty box).
///
/// The per-half-day supplement only shows when the workspace's
/// `accessorySupplements` feature toggle (#170) is ON and the accessory is
/// actually priced; the chip label then mirrors the seat editor's
/// `name (+supplement)` format (#168), in the workspace currency.
class SeatAccessoryRow extends ConsumerWidget {
  const SeatAccessoryRow({super.key, required this.seatId});

  /// Key of the wrap holding the accessory chips (absent when the seat
  /// has none) — used by widget tests.
  static const chipsKey = ValueKey('seat-accessory-chips');

  final String seatId;

  /// Chip label: accessory name, plus its per-half-day supplement (in the
  /// workspace currency) when supplements are billed and one is set.
  String _label(
    Accessory accessory,
    NumberFormat currency, {
    required bool showSupplements,
  }) {
    if (!showSupplements || accessory.supplementCents <= 0) {
      return accessory.name;
    }
    final supplement = currency.format(accessory.supplementCents / 100);
    return '${accessory.name} (+$supplement)';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Active-only catalog in catalog order; inactive accessories stay
    // assigned in the DB but are never shown to bookers.
    final catalog = ref.watch(accessoriesProvider()).value;
    final assignments = ref.watch(seatAccessoriesProvider).value;
    if (catalog == null || assignments == null) {
      // Still loading (or failed): the row simply renders late / not at
      // all — accessories are auxiliary info, never block the sheet.
      return const SizedBox.shrink();
    }
    final assigned = assignments[seatId] ?? const <String>{};
    final accessories = [
      for (final accessory in catalog)
        if (assigned.contains(accessory.id)) accessory,
    ];
    if (accessories.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showSupplements = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.accessorySupplements);
    final currency = NumberFormat.simpleCurrency(
      name: ref.watch(currentWorkspaceProvider).value?.currencyCode,
    );
    final anyPriced = showSupplements &&
        accessories.any((accessory) => accessory.supplementCents > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          key: chipsKey,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final accessory in accessories)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Text(
                  _label(
                    accessory,
                    currency,
                    showSupplements: showSupplements,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
        if (anyPriced) ...[
          const SizedBox(height: 4),
          // Unit hint for the (+price) suffixes: supplements are billed
          // per half-day (#170); shown only when a priced chip is visible.
          Text(
            l10n?.planAccessorySupplementHint ??
                'Supplements are per half-day.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
