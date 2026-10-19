// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/room_offer.dart';
import '../../providers/place_feedback_providers.dart';

String _unit(AppLocalizations l10n, RoomOfferUnit u) => switch (u) {
  RoomOfferUnit.halfDay => l10n.roomOfferUnitHalfDay,
  RoomOfferUnit.hour => l10n.roomOfferUnitHour,
  RoomOfferUnit.day => l10n.roomOfferUnitDay,
};

/// The price lines of the space sheet: the whole-space price when the
/// resource has one, and, for a room the space rents (#2575), until when it
/// is rented and what one use costs the member. Nothing for a room that is
/// not offered to them.
class SpacePriceLine extends ConsumerWidget {
  const SpacePriceLine({
    this.workspaceId,
    this.priceLine,
    this.officeId,
    super.key,
  });

  final String? workspaceId;
  final String? priceLine;
  final String? officeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = workspaceId;
    final office = officeId;
    final offer = office != null && workspace != null
        ? ref
              .watch(roomOfferProvider((workspaceId: workspace, officeId: office)))
              .value
        : null;
    final style = Theme.of(context).textTheme.bodySmall;
    final money = offer == null ? null : moneyFormat(offer.currency);
    final until = offer?.availableUntil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (priceLine != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            priceLine!,
            // #638 — the converged sheet carries the level sheet's own
            // price line; the key travelled with it.
            key: const ValueKey('space-price-line'),
            style: style,
          ),
        ],
        if (offer != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            until == null
                ? l10n.roomOfferOpen
                : l10n.roomOfferUntil(
                    MaterialLocalizations.of(context).formatMediumDate(until),
                  ),
            key: const ValueKey('space-room-window'),
            style: style,
          ),
          for (final f in offer.fees)
            Text(
              l10n.roomOfferFee(money!.formatMinor(f.feeCents), _unit(l10n, f.unit)),
              key: ValueKey('space-room-fee-${f.unit.wire}'),
              style: style,
            ),
        ],
      ],
    );
  }
}
