// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1915 — before erasing: what goes, what stays and why, and what lies
// outside this installation. Each store is named in the reader's
// language; the counts are the server's.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/rights_request.dart';

String _erasureStoreLabel(AppLocalizations l10n, String store) =>
    switch (store) {
      'messages_sent' => l10n.erasureStoreMessages,
      'custom_answers' =>
        l10n.erasureStoreAnswers,
      'profile' =>
        l10n.erasureStoreProfile,
      'open_reservations' =>
        l10n.erasureStoreOpenBookings,
      'invoices' || 'ledger_entries' =>
        l10n.erasureStoreAccounts,
      'past_reservations' =>
        l10n.erasureStorePastBookings,
      'membership_row' =>
        l10n.erasureStoreMembership,
      'custom_answers_under_hold' =>
        l10n.erasureStoreHeldAnswers,
      'other_installations' =>
        l10n.erasureStoreOtherInstallations,
      'device_caches' =>
        l10n.erasureStoreDeviceCaches,
      'operator_backups' =>
        l10n.erasureStoreBackups,
      _ => store,
    };

class ErasurePreviewView extends StatelessWidget {
  const ErasurePreviewView({super.key, required this.preview});

  final ErasurePreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
              if (seen.add(_erasureStoreLabel(l10n, s.store)))
                Text(
                  count && s.count != null
                      ? '• ${_erasureStoreLabel(l10n, s.store)} (${s.count})'
                      : '• ${_erasureStoreLabel(l10n, s.store)}',
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
          l10n.erasurePreviewTitle,
          style: theme.textTheme.titleMedium,
        ),
        section(l10n.erasurePreviewRemoved, [
          ...preview.removed,
          ...preview.restricted,
        ]),
        section(l10n.erasurePreviewKept, preview.retained),
        section(
          l10n.erasurePreviewOutside,
          preview.pendingExternal,
          count: false,
        ),
      ],
    );
  }
}
