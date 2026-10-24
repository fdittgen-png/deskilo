// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › My data: the person's own records, one view at a time — finances,
// reservations and visits, personal information. The view is the route's
// (`/me/data?view=`), so a link, Back and a reload all land on the same one.
// #2557 C2 — each view reads its own source and keeps its own state: the
// finances per workspace host (the own-finances screen), the reservations
// on the selected workspace's host (#2553's body) with the guest visits
// beside them, and the personal information with the personal part of my
// data read on my personal home (`export_my_personal_data_v1`). A source
// that fails says so with Try again in its own view; the others stay.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/presentation/screens/settings_screen.dart';
import '../../visits/presentation/my_visits_section.dart';
import '../../visits/providers/visits_providers.dart';
import 'me_shell.dart';
import 'personal_data_card.dart';

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
    required this.reservations,
    this.workspaceId,
  });

  final MeDataView view;

  /// The finances view: the person's own finances screen, handed in by the
  /// route so the hub owes the money feature nothing.
  final Widget finances;

  /// The reservations body (#2553): the person's own bookings on the
  /// selected workspace's host, handed in by the route likewise.
  final Widget reservations;

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
            MeDataView.reservations => _ReservationsView(body: reservations),
            MeDataView.profile => ListView(
                key: const ValueKey('me-data-profile'),
                children: [
                  const PersonalDataCard(),
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

/// The person's own reservations on the selected workspace's host, in the
/// body that pages and names its own refusals; the visits as a guest, when
/// there are any, open below it.
class _ReservationsView extends ConsumerWidget {
  const _ReservationsView({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visits = ref.watch(myGuestVisitsProvider).value ?? const [];
    return Column(
      key: const ValueKey('me-data-reservations'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        if (visits.isNotEmpty)
          ListTile(
            key: const ValueKey('me-data-guest-visits'),
            leading: const Icon(Icons.badge_outlined),
            title: Text(l10n.meDataGuestVisits(visits.length)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showAppSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const SafeArea(
                child: SingleChildScrollView(
                  padding: AppSpacing.gutterAll,
                  child: MyVisitsSection(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
