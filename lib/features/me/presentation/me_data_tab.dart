// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › My data: the person's own records, one view at a time — finances,
// reservations and visits, personal information. The view is the route's
// (`/me/data?view=`), so a link, Back and a reload all land on the same one.
// This is the hub the per-source own-data work fills in; today it hosts the
// existing own-finances screen, the guest visits and the account's own rows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/screens/settings_screen.dart';
import '../../visits/presentation/my_visits_section.dart';
import '../../visits/providers/visits_providers.dart';
import 'me_shell.dart';

/// The `view` query of My data; finances when absent or unknown.
enum MeDataView {
  finances('finances'),
  reservations('reservations'),
  profile('profile');

  const MeDataView(this.wire);

  final String wire;

  static MeDataView fromQuery(String? wire) =>
      values.where((v) => v.wire == wire).firstOrNull ?? finances;

  String label(AppLocalizations l10n) => switch (this) {
        finances => l10n.financesTitle,
        reservations => l10n.meDataViewReservations,
        profile => l10n.personalInfoTitle,
      };

  IconData get icon => switch (this) {
        finances => Icons.account_balance_wallet_outlined,
        reservations => Icons.event_note_outlined,
        profile => Icons.badge_outlined,
      };
}

/// The address of My data on [view], narrowed to [workspaceId] when given.
String _meDataRoute({
  MeDataView view = MeDataView.finances,
  String? workspaceId,
}) =>
    Uri(path: MeTab.data.path, queryParameters: {
      'view': view.wire,
      if (workspaceId != null && workspaceId.isNotEmpty) 'workspace': workspaceId,
    }).toString();

/// Below this width the view switch shows icons with tooltips: three
/// labelled segments do not fit beside each other on a phone.
const double _labelledSwitchMinWidth = 600;

class MeDataTab extends ConsumerWidget {
  const MeDataTab({
    super.key,
    required this.view,
    required this.finances,
    this.workspaceId,
  });

  final MeDataView view;

  /// The finances view: the person's own finances screen, handed in by the
  /// route so the hub owes the money feature nothing.
  final Widget finances;

  /// Narrows the finances to one space, as a space's own screens link.
  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labelled = constraints.maxWidth >= _labelledSwitchMinWidth;
              return SegmentedButton<MeDataView>(
                key: const ValueKey('me-data-views'),
                showSelectedIcon: false,
                segments: [
                  for (final v in MeDataView.values)
                    ButtonSegment(
                      value: v,
                      icon: Icon(v.icon, key: ValueKey('me-data-view-${v.wire}')),
                      label: labelled ? Text(v.label(l10n)) : null,
                      tooltip: labelled ? null : v.label(l10n),
                    ),
                ],
                selected: {view},
                onSelectionChanged: (chosen) => context.go(
                    _meDataRoute(view: chosen.single, workspaceId: workspaceId)),
              );
            },
          ),
        ),
        Expanded(
          child: switch (view) {
            MeDataView.finances => finances,
            MeDataView.reservations => const _ReservationsView(),
            MeDataView.profile => ListView(
                key: const ValueKey('me-data-profile'),
                children: [
                  ...accountSettingsTiles(context, ref,
                      only: AccountTileGroup.profile),
                  ...accountSettingsTiles(context, ref,
                      only: AccountTileGroup.account),
                ],
              ),
          },
        ),
      ],
    );
  }
}

/// The person's own visits as a guest; their bookings stay in each space's
/// calendar until the own-reservation read exists, and the view says so.
class _ReservationsView extends ConsumerWidget {
  const _ReservationsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visits = ref.watch(myGuestVisitsProvider).value ?? const [];
    return ListView(
      key: const ValueKey('me-data-reservations'),
      padding: AppSpacing.gutterAll,
      children: [
        if (visits.isEmpty)
          EmptyState(
            key: const ValueKey('me-data-visits-empty'),
            icon: Icons.event_note_outlined,
            title: l10n.meDataVisitsEmptyTitle,
            subtitle: l10n.meDataVisitsEmptyBody,
          ),
        const MyVisitsSection(),
      ],
    );
  }
}
