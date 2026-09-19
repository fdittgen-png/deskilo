// SPDX-License-Identifier: 0BSD
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
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';

class WorkspaceOwnScreens extends ConsumerWidget {
  const WorkspaceOwnScreens({super.key, required this.helpTopic});

  /// The help topic the rows' symbols open.
  final String helpTopic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final features = ref.watch(enabledFeaturesSyncProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(
          rowKey: 'workspaceSettingsWording',
          icon: Icons.translate_outlined,
          title: l10n?.wordingRow ?? 'Wording',
          anchor: HelpAnchor.workspaceWording,
          subtitle: l10n?.wordingRowHint ??
              'The words this space uses for a seat, the legend and the tabs.',
          path: '/settings/wording',
          helpTopic: helpTopic,
        ),
        if (features.contains(WorkspaceFeature.workspaceBranding))
          _Row(
            rowKey: 'workspaceSettingsColours',
            icon: Icons.palette_outlined,
            title: l10n?.coloursTitle ?? 'Colours',
            anchor: HelpAnchor.workspaceColours,
            subtitle: l10n?.coloursIntro ??
                'One colour, and the app derives its light and dark themes '
                    'from it.',
            path: '/settings/colours',
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
  final String anchor;
  final String subtitle;
  final String path;
  final String helpTopic;

  @override
  Widget build(BuildContext context) => ListTile(
        key: Key(rowKey),
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: HelpDotTitle(title, helpTopic, anchor: anchor),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(path),
      );
}
