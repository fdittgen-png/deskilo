// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/providers/plan_focus_controller.dart';
import '../../domain/space_bookability.dart';

/// One seat the space sheet lists: taken in the window, or a tap that
/// opens its reserve-or-check-in sheet.
class SpaceSeatTile extends StatelessWidget {
  const SpaceSeatTile({
    super.key,
    required this.seat,
    required this.taken,
    required this.busy,
    required this.onPick,
  });

  final Seat seat;
  final bool taken;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('space-seat-${seat.id}'),
    contentPadding: EdgeInsets.zero,
    enabled: !taken && !busy,
    leading: Icon(
      taken ? Icons.event_busy_outlined : Icons.event_seat_outlined,
    ),
    title: Text(seat.name),
    subtitle: taken ? Text(context.l10n.spaceSeatTaken) : null,
    onTap: taken ? null : onPick,
  );
}

/// WHERE is it? (field request) -- jumps to the plan with the space in focus,
/// closing every sheet on the way so the plan is actually visible.
class SpaceShowOnPlanButton extends ConsumerWidget {
  const SpaceShowOnPlanButton({
    super.key,
    required this.levelId,
    required this.space,
  });

  /// The level the plan opens on.
  final String levelId;

  /// What was selected: its seat, table or office, or the whole floor.
  final ResolvedSpace space;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    key: const ValueKey('space-show-plan'),
    icon: const Icon(Icons.map_outlined),
    label: Text(context.l10n.calendarShowOnPlan),
    onPressed: () {
      // #576 -- the highlight matches WHAT was selected: seat, table, office
      // or the whole floor.
      final seat = space.seat;
      final desk = space.desk;
      final office = space.office;
      ref
          .read(planFocusControllerProvider.notifier)
          .setFocus(
            PlanFocus(
              levelId: levelId,
              seatId: seat?.id,
              deskId: desk?.id,
              officeId: desk == null ? office?.id : null,
              wholeLevel: seat == null && desk == null && office == null,
            ),
          );
      Navigator.of(context).popUntil(
        (route) => route is! ModalBottomSheetRoute && route is! RawDialogRoute,
      );
      context.go('/plan');
    },
  );
}
