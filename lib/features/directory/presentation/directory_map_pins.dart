// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';

/// A workspace on the map: a pill with its name. The selected one grows,
/// takes the accent and points at its place; the others stay quiet.
class DirectoryMapPin extends StatelessWidget {
  const DirectoryMapPin({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: name,
      button: true,
      selected: selected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : scheme.surface,
              borderRadius: AppRadius.mdAll,
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: selected ? 0.35 : 0.2),
                  blurRadius: selected ? 10 : 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: key == null
                    ? null
                    : ValueKey('${(key! as ValueKey<String>).value}-tap'),
                borderRadius: AppRadius.mdAll,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The little tail that points at the place.
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: selected ? scheme.primary : scheme.surface,
          ),
        ],
      ),
    );
  }
}

/// Several workspaces close together: one round bubble with how many.
class DirectoryClusterBubble extends StatelessWidget {
  const DirectoryClusterBubble({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$count',
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 3),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.25),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: scheme.onTertiaryContainer),
          ),
        ),
      ),
    );
  }
}
