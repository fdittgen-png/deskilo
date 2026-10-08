// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';

/// Task groups preserve their mounted controls when their header is closed.
class SettingsTaskSection extends StatelessWidget {
  const SettingsTaskSection({required this.id, required this.title,
    required this.children, this.initiallyExpanded = true, super.key});
  final String id, title;
  final List<Widget> children;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: ListTileTheme(
      data: const ListTileThemeData(minTileHeight: 56),
      child: ExpansionTile(key: PageStorageKey('settings-section-$id'),
        maintainState: true, initiallyExpanded: initiallyExpanded,
        title: Text(title), children: children),
    ),
  );
}
