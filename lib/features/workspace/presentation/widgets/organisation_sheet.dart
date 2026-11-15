// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — Settings › Organisation: the organisation this business is a house
// of, its houses with their country and currency and the reader's own role
// in each, and the owners' commands — rename it, add one of their
// businesses, take a house out. A business in no organisation may become
// the head of one. Who owns a house is read inside that house; the server
// decides every command and says why when it does not.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/space_entry.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/country_names.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/member.dart';
import '../../domain/organisation.dart';
import '../../domain/workspace.dart';
import '../../providers/organisation_providers.dart';
import '../../providers/workspace_providers.dart';
import '../screens/organisation_overview_screen.dart';
import 'add_house_form.dart';
import 'house_birth_view.dart';
import 'organisation_name_dialog.dart';

String _roleText(AppLocalizations l10n, HouseRole role) => switch (role) {
  HouseRole.owner => l10n.organisationRoleOwner,
  HouseRole.coOwner => l10n.organisationRoleCoOwner,
  HouseRole.admin => l10n.organisationRoleAdmin,
  HouseRole.member => l10n.organisationRoleMember,
};

String organisationRefusalText(
  AppLocalizations l10n,
  OrganisationRefusal r,
) => switch (r) {
  OrganisationRefusal.notOwner => l10n.organisationRefusedNotOwner,
  OrganisationRefusal.noName => l10n.organisationRefusedNoName,
  OrganisationRefusal.alreadyInOne => l10n.organisationRefusedAlreadyInOne,
  OrganisationRefusal.inNone => l10n.organisationRefusedInNone,
  OrganisationRefusal.headLeavesLast => l10n.organisationRefusedHeadLeavesLast,
  OrganisationRefusal.notAHouse => l10n.organisationRefusedNotAHouse,
  OrganisationRefusal.twinNeverHead => l10n.organisationRefusedTwinNeverHead,
  OrganisationRefusal.featureOff => l10n.organisationRefusedFeatureOff,
  OrganisationRefusal.language => l10n.organisationRefusedLanguage,
  OrganisationRefusal.requestUsed => l10n.organisationRefusedRequestUsed,
  OrganisationRefusal.demoOneHouse => l10n.organisationRefusedDemoOneHouse,
  OrganisationRefusal.other => l10n.organisationRefusedOther,
};

/// The organisation of [workspace], as a sheet over Settings.
class OrganisationSheet extends ConsumerWidget {
  const OrganisationSheet({super.key, required this.workspace});

  final Workspace workspace;

  /// Opens the sheet of [workspace]'s organisation.
  /// The id of a house made from it, if one was.
  static Future<String?> open(BuildContext context, Workspace workspace) =>
      showAppSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => OrganisationSheet(workspace: workspace),
      );

  /// #4005 — opens the sheet; when a house abroad was made from it, the
  /// person lands in that house, whose home shows its birth record once.
  static Future<void> openAndEnter(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace,
  ) async {
    final id = await open(context, workspace);
    if (id == null || !context.mounted) return;
    final spaces = await ref.read(myWorkspacesProvider.future);
    final house = spaces.where((s) => s.id == id).firstOrNull;
    if (house == null || !context.mounted) return;
    ref.read(pendingHouseBirthProvider.notifier).set(id);
    await enterSpace(context, ref, house);
  }

  Future<String?> _askName(BuildContext context, String title, String now) =>
      showDialog<String>(
        context: context,
        builder: (_) => OrganisationNameDialog(title: title, initial: now),
      );

  Future<void> _done(
    BuildContext context,
    Future<OrganisationRefusal?> command,
  ) async {
    final refused = await command;
    if (refused != null && context.mounted) {
      AppSnack.error(context, organisationRefusalText(context.l10n, refused));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final commands = ref.read(organisationCommandsProvider);
    final read = ref.watch(myOrganisationsProvider);
    if (!read.hasValue) {
      return SafeArea(
        child: Padding(
          padding: AppSpacing.lgAll,
          child: read.error == null
              ? const LoadingView()
              : ReadFailureBanner(
                  error: read.error!,
                  onRetry: () => ref.invalidate(myOrganisationsProvider),
                ),
        ),
      );
    }
    final organisations = read.requireValue;
    final spaces =
        ref.watch(myWorkspacesProvider).value ??
        const []; // empty-ok: no candidate to add until they are read
    final organisation = organisations
        .where((o) => o.houseOf(workspace.id) != null)
        .firstOrNull;
    // Only a business the person owns can join: the memberships Me reads.
    final owned = {
      for (final m
          in ref.watch(myMembershipsProvider).value ??
              const <
                Member
              >[]) // empty-ok: none offered until the memberships are read
        if (m.isOwner) m.workspaceId,
    };
    // One row per house: a business and its development twin are two houses
    // on the server, and the page shows those of this business's own
    // environment.
    final houses = organisation == null
        ? const <OrganisationHouse>[]
        : housesInEnvironment(organisation.byCountry, workspace, {
            for (final s in spaces) s.id: s,
          });
    // The head's owner manages the organisation; a house's owner may only
    // take their own house out.
    final headOwner =
        organisation?.houseOf(organisation.headWorkspaceId)?.role ==
        HouseRole.owner;
    final birth = ref.watch(houseBirthProvider(workspace.id)).value;
    final title = Row(
      children: [
        Expanded(
          child: Text(
            organisation?.name ?? l10n.organisationTitle,
            key: const ValueKey('organisation-name'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (organisation != null && headOwner)
          IconButton(
            key: const ValueKey('organisation-rename'),
            tooltip: l10n.organisationRename,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final name = await _askName(
                context,
                l10n.organisationRename,
                organisation.name,
              );
              if (name == null || !context.mounted) return;
              await _done(context, commands.rename(organisation.id, name));
            },
          ),
        HelpDot(l10n.organisationTitle, anchor: HelpAnchor.organisation),
      ],
    );
    return SafeArea(
      child: ListView(
        key: const ValueKey('organisation-sheet'),
        shrinkWrap: true,
        padding: AppSpacing.lgAll,
        children: [
          title,
          ..._birthOf(birth, organisation),
          const FormGap(),
          if (organisation == null) ...[
            Text(l10n.organisationNone),
            const FormGap(),
            FilledButton(
              key: const ValueKey('organisation-create'),
              onPressed: () async {
                final name = await _askName(
                  context,
                  l10n.organisationCreate,
                  workspace.name,
                );
                if (name == null || !context.mounted) return;
                await _done(context, commands.create(workspace.id, name));
              },
              child: Text(l10n.organisationCreate),
            ),
          ] else ...[
            for (final house in houses)
              _HouseRow(
                house: house,
                organisation: organisation,
                headOwner: headOwner,
                alone: houses.length == 1,
                onCommand: (command) => _done(context, command),
              ),
            const FormGap(),
            // #4007 — the houses side by side, for whoever reads this page.
            OutlinedButton.icon(
              key: const ValueKey('organisation-overview'),
              icon: const Icon(Icons.table_chart_outlined),
              label: Text(l10n.organisationOverviewTitle),
              onPressed: () =>
                  OrganisationOverviewScreen.open(context, organisation.id),
            ),
            if (headOwner)
              ..._headActions(
                context,
                ref,
                owned,
                spaces,
                organisations,
                organisation,
              ),
          ],
        ],
      ),
    );
  }

  /// #4005 — how this business began, when it was made as a house.
  List<Widget> _birthOf(HouseBirth? birth, Organisation? organisation) => [
    if (birth != null) ...[
      const FormGap(),
      HouseBirthView(
        birth: birth,
        head: organisation?.houseOf(birth.headWorkspaceId ?? '')?.name ?? '',
      ),
    ],
  ];

  /// What the head's owner does: add one of their businesses, or a house
  /// abroad (the sheet then answers the house made).
  List<Widget> _headActions(
    BuildContext context,
    WidgetRef ref,
    Set<String> owned,
    List<Workspace> spaces,
    List<Organisation> organisations,
    Organisation organisation,
  ) {
    final l10n = context.l10n;
    return [
      OutlinedButton.icon(
        key: const ValueKey('organisation-add'),
        icon: const Icon(Icons.add),
        label: Text(l10n.organisationAdd),
        onPressed: () =>
            _add(context, ref, owned, spaces, organisations, organisation),
      ),
      const FormGap.small(),
      OutlinedButton.icon(
        key: const ValueKey('organisation-add-house'),
        icon: const Icon(Icons.public),
        label: Text(l10n.houseAddTitle),
        onPressed: () async {
          final id = await AddHouseForm.open(context, ref, organisation);
          if (id != null && context.mounted) Navigator.of(context).pop(id);
        },
      ),
    ];
  }

  /// Offers the person's businesses in no organisation (one side of a
  /// pair: the server moves its twin with it).
  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    Set<String> owned,
    List<Workspace> spaces,
    List<Organisation> organisations,
    Organisation organisation,
  ) async {
    final l10n = context.l10n;
    final candidates = [
      for (final s in spaces)
        if (owned.contains(s.id) &&
            !organisations.any((o) => o.houseOf(s.id) != null) &&
            !(s.isDevelopment && s.pairId.isNotEmpty))
          s,
    ];
    if (candidates.isEmpty) {
      AppSnack.info(context, l10n.organisationAddNone);
      return;
    }
    final picked = await showAppSheet<Workspace>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in candidates)
              ListTile(
                key: ValueKey('organisation-candidate-${s.id}'),
                title: Text(s.name),
                subtitle: Text(
                  '${localizedCountryName(l10n, s.countryCode)} · '
                  '${s.currencyCode}',
                ),
                onTap: () => Navigator.of(sheet).pop(s),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await _done(
      context,
      ref.read(organisationCommandsProvider).add(organisation.id, picked.id),
    );
  }
}

/// One house of the organisation: its name (the head says so), its country,
/// currency and the reader's role, and what the reader may do with it — the
/// head's owner makes another house of theirs the head or takes a house out;
/// a house's own owner may only leave.
class _HouseRow extends ConsumerWidget {
  const _HouseRow({
    required this.house,
    required this.organisation,
    required this.headOwner,
    required this.alone,
    required this.onCommand,
  });

  final OrganisationHouse house;
  final Organisation organisation;
  final bool headOwner;

  /// The only house left: taking it out ends the organisation.
  final bool alone;
  final void Function(Future<OrganisationRefusal?> command) onCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final commands = ref.read(organisationCommandsProvider);
    final id = house.workspaceId;
    final isHead = id == organisation.headWorkspaceId;
    final owns = house.role == HouseRole.owner;
    return ListTile(
      key: ValueKey('organisation-house-$id'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        isHead ? '${house.name} · ${l10n.organisationHead}' : house.name,
      ),
      subtitle: Text(
        [
          if (house.countryCode.isNotEmpty)
            localizedCountryName(l10n, house.countryCode),
          if (house.currencyCode.isNotEmpty) house.currencyCode,
          l10n.organisationYourRole(_roleText(l10n, house.role)),
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (headOwner && !isHead && owns)
            IconButton(
              key: ValueKey('organisation-head-$id'),
              tooltip: l10n.organisationMakeHead,
              icon: const Icon(Icons.star_outline),
              onPressed: () async {
                final agreed = await confirmOrganisationChange(
                  context,
                  text: l10n.organisationConfirmHead(house.name),
                  action: l10n.organisationMakeHead,
                  destructive: false,
                );
                if (agreed) onCommand(commands.setHead(organisation.id, id));
              },
            ),
          if (headOwner || owns)
            IconButton(
              key: ValueKey(
                headOwner
                    ? 'organisation-remove-$id'
                    : 'organisation-leave-$id',
              ),
              tooltip: headOwner
                  ? l10n.organisationRemove
                  : l10n.organisationLeave,
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final agreed = await confirmOrganisationChange(
                  context,
                  text: isHead && alone
                      ? l10n.organisationConfirmEnd(
                          organisation.name,
                          house.name,
                        )
                      : l10n.organisationConfirmLeave(
                          house.name,
                          organisation.name,
                        ),
                  action: headOwner
                      ? l10n.organisationRemove
                      : l10n.organisationLeave,
                );
                if (agreed) onCommand(commands.remove(id));
              },
            ),
        ],
      ),
    );
  }
}
