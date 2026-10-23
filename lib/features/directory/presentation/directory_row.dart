// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/server_label.dart';
import '../domain/public_workspace.dart';
import 'saved_place_button.dart';

/// One listed space: its name, its place, what it offers, and three
/// separate actions (Bookmark, View, Locate on map). The card itself is
/// not tappable: no interactive surface encloses the buttons, so the
/// keyboard and a screen reader walk the text and then the actions, row
/// after row, in the order the list shows them.
class DirectoryRow extends StatelessWidget {
  const DirectoryRow({
    super.key,
    required this.workspace,
    required this.selected,
    required this.onView,
    required this.onLocate,
  });

  final PublicWorkspace workspace;

  /// The same selection as the map's pin.
  final bool selected;
  final VoidCallback onView;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final w = workspace;
    final id = '${w.source}/${w.id}';
    final place = [
      w.text('address'),
      if (w.source.isNotEmpty) serverLabel(l, w.source),
    ].where((part) => part.isNotEmpty).join(' · ');
    final offer = switch (w.text('host_type')) {
      'association' => l.portalAssociation,
      'company' => l.portalCompany,
      _ => l.portalPerson,
    };
    final description = w.text('description');
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      key: ValueKey('directory-row-$id'),
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.name, style: theme.textTheme.titleMedium),
                  if (place.isNotEmpty) Text(place, style: muted),
                  Text(offer, style: theme.textTheme.bodySmall),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SavedPlaceButton(workspace: w),
                FilledButton.tonalIcon(
                  key: ValueKey('directory-view-$id'),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l.discoveryView),
                  onPressed: onView,
                ),
                IconButton(
                  key: ValueKey('directory-locate-$id'),
                  tooltip: l.directoryLocate,
                  icon: const Icon(Icons.location_on_outlined),
                  onPressed: onLocate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
