// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Placeholder for the guided reservation flow (#207).
///
/// Reached from the raised centre Reserve button in the shell's bottom
/// bar. Issue #208 replaces this body with the real flow — the file name
/// and the `/reserve` route are final.
class ReservePlaceholderScreen extends StatelessWidget {
  const ReservePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.shellReserveButton ?? 'Reserve')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_seat_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n?.comingSoon ?? 'Coming soon',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
