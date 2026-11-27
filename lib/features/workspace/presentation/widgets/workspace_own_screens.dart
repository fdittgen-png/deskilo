// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1289 — the settings rows that open a screen of their own.
//
// Wording (#1277) and Colours (#1289) are not fields: each browses more
// than a form row can hold and writes through its own keyed server call,
// so neither rides the workspace Save button. They are the same shape —
// icon, help symbol, one line of what it is, a chevron — so they are one
// widget rather than two copies that drift.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/routes.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';

class WorkspaceOwnScreens extends ConsumerWidget {
  const WorkspaceOwnScreens({super.key, required this.helpTopic});

  /// The help topic the rows' symbols open.
  final String helpTopic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final features = ref.watch(enabledFeaturesSyncProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(
          rowKey: 'workspaceSettingsWording',
          icon: Icons.translate_outlined,
          title: l10n.wordingRow,
          anchor: HelpAnchor.workspaceWording,
          subtitle: l10n.wordingRowHint,
          path: '/settings/wording',
          helpTopic: helpTopic,
        ),
        if (features.contains(WorkspaceFeature.workspaceBranding))
          _Row(
            rowKey: 'workspaceSettingsColours',
            icon: Icons.palette_outlined,
            title: l10n.coloursTitle,
            anchor: HelpAnchor.workspaceColours,
            subtitle: l10n.coloursIntro,
            path: '/settings/colours',
            helpTopic: helpTopic,
          ),
        // #1528 — the roles this space defines for itself. #2085 — with
        // roleAssignment they are reached from Roles, the one entry.
        if (features.contains(WorkspaceFeature.customRoles) &&
            !features.contains(WorkspaceFeature.roleAssignment))
          _Row(
            rowKey: 'workspaceSettingsRolesOfSpace',
            icon: Icons.badge_outlined,
            title: l10n.rolesOfSpaceTitle,
            anchor: HelpAnchor.rolesSpace,
            subtitle: l10n.rolesOfSpaceSubtitle,
            path: '/settings/roles-of-this-space',
            helpTopic: helpTopic,
          ),
        // #1288 — the questions this space asks its members.
        if (features.contains(WorkspaceFeature.customFields))
          _Row(
            rowKey: 'workspaceSettingsQuestions',
            icon: Icons.help_outline,
            title: l10n.questionsTitle,
            anchor: null,
            subtitle: l10n.questionsSubtitle,
            path: '/settings/questions',
            helpTopic: helpTopic,
          ),
        // #4485 — every kind of master data, each opening its own screen.
        _Row(
          rowKey: 'workspaceSettingsMasterData',
          icon: Icons.dataset_outlined,
          title: l10n.deploymentKindMasterData,
          anchor: HelpAnchor.masterData,
          subtitle: l10n.masterDataIntro,
          path: Routes.settingsMasterData,
          helpTopic: helpTopic,
        ),
        // #4442 — the units this business measures in and how they convert.
        // #4485 — always offered: the pickers read the units either way.
        _Row(
          rowKey: 'workspaceSettingsUnits',
          icon: Icons.straighten,
          title: l10n.featureUnitsOfMeasureTitle,
          anchor: HelpAnchor.settingsUnits,
          subtitle: l10n.measureUnitsSubtitle,
          path: Routes.settingsUnits,
          helpTopic: helpTopic,
        ),
        // #4466 — the till boards connected to this business.
        if (features.contains(WorkspaceFeature.counterEmbeddedTerminal))
          _Row(
            rowKey: 'workspaceSettingsDevices',
            icon: Icons.point_of_sale,
            title: l10n.devicePairingTitle,
            anchor: HelpAnchor.settingsDevices,
            subtitle: l10n.devicePairingSubtitle,
            path: Routes.settingsDevices,
            helpTopic: helpTopic,
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.anchor,
    required this.subtitle,
    required this.path,
    required this.helpTopic,
  });

  final String rowKey;
  final IconData icon;
  final String title;
  final String? anchor;
  final String subtitle;
  final String path;
  final String helpTopic;

  @override
  Widget build(BuildContext context) => ListTile(
        key: Key(rowKey),
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: anchor == null
            ? Text(title)
            : HelpDotTitle(title, helpTopic, anchor: anchor),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(path),
      );
}
