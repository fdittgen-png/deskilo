// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1922 — the reminders of an invoice and what is actually known about
// their delivery. "Shared by the sender" is the sender's own statement,
// "accepted by the push service" is not proof anyone read it, and an
// unanswered push says so instead of pretending. Nothing here is about
// payment.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/reminder_evidence.dart';
import '../../providers/reminder_evidence_providers.dart';

@visibleForTesting
String reminderStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'prepared' => l10n.reminderStatusPrepared,
      'queued' => l10n.reminderStatusQueued,
      'provider_accepted' =>
        l10n.reminderStatusAccepted,
      'declared_delivered' =>
        l10n.reminderStatusDeclared,
      'failed' => l10n.reminderStatusFailed,
      'unknown' =>
        l10n.reminderStatusUnknown,
      _ =>
        l10n.reminderStatusLegacy,
    };

String _reminderOriginLabel(AppLocalizations l10n, String origin) =>
    switch (origin) {
      'manual' => l10n.reminderOriginManual,
      'automatic' => l10n.reminderOriginAutomatic,
      _ => l10n.reminderOriginLegacy,
    };

/// The reminder history of [invoiceId]; nothing when it has none.
class ReminderEvidenceList extends ConsumerWidget {
  const ReminderEvidenceList({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidence = ref.watch(reminderEvidenceProvider(invoiceId)).value;
    if (evidence == null || evidence.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final date = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    return Column(
      key: const ValueKey('invoice-reminder-evidence'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.reminderHistoryTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              key: const ValueKey('invoice-reminder-evidence-refresh'),
              tooltip: l10n.reminderHistoryRefresh,
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.invalidate(reminderEvidenceProvider(invoiceId)),
            ),
          ],
        ),
        for (final ReminderEvidence item in evidence)
          Padding(
            key: ValueKey('invoice-reminder-evidence-${item.intentId}'),
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '${l10n.reminderHistoryLine(item.level, _reminderOriginLabel(l10n, item.origin), date.format(item.preparedAt))}\n'
              '${reminderStatusLabel(l10n, item.status)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const Divider(height: AppSpacing.xl),
      ],
    );
  }
}
