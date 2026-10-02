// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1915 — before erasing: what goes, what stays and why, and what lies
// outside this installation. Each store is named in the reader's
// language; the counts are the server's.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/rights_request.dart';

String erasureStoreLabel(AppLocalizations? l10n, String store) =>
    switch (store) {
      'messages_sent' => l10n?.erasureStoreMessages ?? 'Messages you sent',
      'custom_answers' =>
        l10n?.erasureStoreAnswers ?? 'Your answers to the space\'s questions',
      'profile' =>
        l10n?.erasureStoreProfile ??
            'Your profile (when this is your last space)',
      'open_reservations' =>
        l10n?.erasureStoreOpenBookings ?? 'Open bookings — cancelled',
      'invoices' || 'ledger_entries' =>
        l10n?.erasureStoreAccounts ??
            'Invoices and ledger — accounting evidence, kept for the '
                'statutory period; issued documents are not rewritten',
      'past_reservations' =>
        l10n?.erasureStorePastBookings ??
            'Past bookings — the space\'s occupancy record',
      'membership_row' =>
        l10n?.erasureStoreMembership ??
            'The membership row — links the records kept; pseudonymous, '
                'not anonymous',
      'custom_answers_under_hold' =>
        l10n?.erasureStoreHeldAnswers ??
            'Answers under a retention hold the space documented',
      'other_installations' =>
        l10n?.erasureStoreOtherInstallations ??
            'Another DesKilo installation is a separate controller — ask '
                'it directly',
      'device_caches' =>
        l10n?.erasureStoreDeviceCaches ??
            'Copies on your devices — cleared when you sign out of each',
      'operator_backups' =>
        l10n?.erasureStoreBackups ??
            'The operator\'s backups — expire on their rotation',
      _ => store,
    };

class ErasurePreviewView extends StatelessWidget {
  const ErasurePreviewView({super.key, required this.preview});

  final ErasurePreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget section(
      String title,
      List<ErasureStore> stores, {
      bool count = true,
    }) {
      final shown = [
        for (final s in stores)
          if (!count || (s.count ?? 0) > 0) s,
      ];
      if (shown.isEmpty) return const SizedBox.shrink();
      // Invoices and ledger read as one line.
      final seen = <String>{};
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            for (final s in shown)
              if (seen.add(erasureStoreLabel(l10n, s.store)))
                Text(
                  count && s.count != null
                      ? '• ${erasureStoreLabel(l10n, s.store)} (${s.count})'
                      : '• ${erasureStoreLabel(l10n, s.store)}',
                  style: theme.textTheme.bodySmall,
                ),
          ],
        ),
      );
    }

    return Column(
      key: const ValueKey('erasure-preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.erasurePreviewTitle ?? 'What erasing does here',
          style: theme.textTheme.titleMedium,
        ),
        section(l10n?.erasurePreviewRemoved ?? 'Removed', [
          ...preview.removed,
          ...preview.restricted,
        ]),
        section(l10n?.erasurePreviewKept ?? 'Kept, and why', preview.retained),
        section(
          l10n?.erasurePreviewOutside ?? 'Outside this installation',
          preview.pendingExternal,
          count: false,
        ),
      ],
    );
  }
}
