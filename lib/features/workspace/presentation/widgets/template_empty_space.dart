// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';

/// Marks the row where the gallery offers to start empty.
class TemplateEmptySpace {
  const TemplateEmptySpace();
}

/// The "start empty" card of the gallery: no template, a blank space.
class TemplateEmptySpaceCard extends StatelessWidget {
  const TemplateEmptySpaceCard({
    super.key,
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('template-empty'),
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        key: const ValueKey('template-gallery-onboarding-start-empty'),
        leading: Icon(selected ? Icons.check : Icons.crop_square_outlined),
        title: Text(l10n.onboardingStartEmpty),
        subtitle: Text(l10n.onboardingStartEmptyDesc),
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}
