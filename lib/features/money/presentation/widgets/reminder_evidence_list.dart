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

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/reminder_evidence.dart';
import '../../providers/reminder_evidence_providers.dart';

String reminderStatusLabel(AppLocalizations? l10n, String status) =>
    switch (status) {
      'prepared' => l10n?.reminderStatusPrepared ?? 'Prepared',
      'queued' => l10n?.reminderStatusQueued ?? 'Handed to the push service',
      'provider_accepted' =>
        l10n?.reminderStatusAccepted ??
            'Accepted by the push service — not proof it was read',
      'declared_delivered' =>
        l10n?.reminderStatusDeclared ??
            'Shared by the sender — their statement, not a receipt',
      'failed' => l10n?.reminderStatusFailed ?? 'Not delivered',
      'unknown' =>
        l10n?.reminderStatusUnknown ?? 'No answer from the push service',
      _ =>
        l10n?.reminderStatusLegacy ??
            'Recorded before delivery was tracked — unknown',
    };

String reminderOriginLabel(AppLocalizations? l10n, String origin) =>
    switch (origin) {
      'manual' => l10n?.reminderOriginManual ?? 'by hand',
      'automatic' => l10n?.reminderOriginAutomatic ?? 'automatic',
      _ => l10n?.reminderOriginLegacy ?? 'earlier',
    };

/// The reminder history of [invoiceId]; nothing when it has none.
class ReminderEvidenceList extends ConsumerWidget {
  const ReminderEvidenceList({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidence = ref.watch(reminderEvidenceProvider(invoiceId)).value;
    if (evidence == null || evidence.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
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
                l10n?.reminderHistoryTitle ?? 'Reminder history',
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              key: const ValueKey('invoice-reminder-evidence-refresh'),
              tooltip: l10n?.reminderHistoryRefresh ?? 'Check delivery again',
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
              '${l10n?.reminderHistoryLine(item.level, reminderOriginLabel(l10n, item.origin), date.format(item.preparedAt)) ?? 'Level ${item.level} · '
                      '${reminderOriginLabel(l10n, item.origin)} · '
                      '${date.format(item.preparedAt)}'}\n'
              '${reminderStatusLabel(l10n, item.status)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const Divider(height: AppSpacing.xl),
      ],
    );
  }
}
