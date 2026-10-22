// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the drill-through of the capacity figure: the bookings that make
// it, for the months it was read over, day by day, each opening its
// booking. Reading them changes nothing; changing the opening hours stays
// the availability screen's own, permission-gated action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/reservation.dart';
import '../../providers/reservation_providers.dart';

class PeriodReservationsScreen extends ConsumerWidget {
  const PeriodReservationsScreen({
    super.key,
    required this.fromMonth,
    required this.toMonth,
  });

  /// `YYYY-MM`, both included.
  final String fromMonth;
  final String toMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rows = ref.watch(periodReservationsProvider(fromMonth, toMonth));
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final targets = ref.watch(bookingTargetNamesProvider).value ?? const {};
    final format = ref.watch(appFormatProvider);
    String target(Reservation r) =>
        targets[r.seatId ?? r.officeId ?? r.levelId ?? ''] ??
        l10n.periodReservationsUnnamed;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          fromMonth == toMonth
              ? l10n.periodReservationsTitle(fromMonth)
              : l10n.periodReservationsTitle('$fromMonth – $toMonth'),
        ),
      ),
      body: switch (rows) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          key: const ValueKey('period-reservations-empty'),
          icon: Icons.event_busy_outlined,
          title: l10n.periodReservationsEmpty,
        ),
        AsyncData(:final value) => ListView(
          key: const ValueKey('period-reservations'),
          padding: AppSpacing.gutterAll,
          children: [
            for (final (i, r) in value.indexed) ...[
              if (i == 0 ||
                  WorkspaceTime.dateOf(value[i - 1].startsAt) !=
                      WorkspaceTime.dateOf(r.startsAt))
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    format.date(r.startsAt),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ListTile(
                key: ValueKey('period-reservation-${r.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(target(r)),
                subtitle: Text(
                  '${names[r.memberId] ?? ''} · '
                  '${format.time(r.startsAt)}–${format.time(r.endsAt)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/res/${r.id}'),
              ),
            ],
          ],
        ),
        AsyncError() => EmptyState(
          icon: Icons.error_outline,
          title: l10n.periodReservationsFailed,
        ),
        _ => const LoadingView(),
      },
    );
  }
}
