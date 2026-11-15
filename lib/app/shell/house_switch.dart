// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — inside a house of an organisation, the other houses one tap away:
// the chip's sheet on a phone, the rail on the desk. Only the houses of the
// same organisation the person is a member of are listed; every other
// business is reached from Me, as before.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/country_names.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/ui/app_sheet.dart';
import '../../features/profile/presentation/widgets/personal_avatar.dart';
import '../../features/workspace/domain/organisation.dart';
import '../../features/workspace/domain/workspace.dart';
import '../../features/workspace/presentation/widgets/workspace_avatar.dart';
import '../../features/workspace/providers/organisation_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../route_classes.dart';

/// The other houses of the organisation [currentId] is a house of, in Me's
/// order, each as one of the person's businesses; none while either is
/// being read, or when [currentId] is in no organisation. A business and
/// its development twin are both in the organisation: only the houses of
/// the environment the person is in are listed, so no house comes twice
/// and the twin of the current one is not another house.
List<Workspace> otherHousesOf(WidgetRef ref, String? currentId) {
  if (currentId == null) return const [];
  final organisations = ref.watch(myOrganisationsProvider).value;
  final spaces = ref.watch(myWorkspacesProvider).value;
  if (organisations == null || spaces == null) return const [];
  final byId = {for (final s in spaces) s.id: s};
  final current = byId[currentId];
  if (current == null) return const [];
  return [
    for (final house in housesInEnvironment(
      Organisation.othersOf(organisations, currentId),
      current,
      byId,
    ))
      ?byId[house.workspaceId],
  ];
}

/// The chip's sheet: the other houses, then the way back to Me.
class HouseSheet extends StatelessWidget {
  const HouseSheet({super.key, required this.houses});

  final List<Workspace> houses;

  /// Opens the sheet of [houses] over [context]; the house picked, if any.
  static Future<Workspace?> open(
    BuildContext context,
    List<Workspace> houses,
  ) => showAppSheet<Workspace>(
    context: context,
    showDragHandle: true,
    builder: (_) => HouseSheet(houses: houses),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: ListView(
        key: const ValueKey('house-sheet'),
        shrinkWrap: true,
        children: [
          for (final space in houses)
            ListTile(
              key: ValueKey('house-${space.id}'),
              leading: WorkspaceAvatar(workspace: space),
              title: Text(space.name),
              subtitle: Text(
                countryAndCurrency(
                  context.l10n,
                  countryCode: space.countryCode,
                  currencyCode: space.currencyCode,
                ),
              ),
              onTap: () => Navigator.of(context).pop(space),
            ),
          const Divider(),
          ListTile(
            key: const ValueKey('house-sheet-back-to-me'),
            leading: const PersonalAvatar(),
            title: Text(l10n.spaceBackToMe),
            onTap: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.go(kMeHome);
            },
          ),
        ],
      ),
    );
  }
}
