// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a member meets at the tablet by the door before anything else: the
// kiosk's own top line — the tablet mark, the space's name and how to
// check in — over the badge mark. The setup guide shows it as the kiosk
// step's preview; it acts on nothing.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';

class KioskGreeting extends StatelessWidget {
  const KioskGreeting({super.key, required this.workspaceName});

  final String workspaceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('kiosk-greeting'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.tablet_mac_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                workspaceName,
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(context.l10n.kioskTapHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Icon(
          Icons.contactless_outlined,
          size: 48,
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }
}
