// SPDX-License-Identifier: 0BSD
//
// #833 — the month's bookings, and what each of them costs.
//
// Three numbers per row, and they are deliberately three: the window
// BOOKED, the time actually PRESENT, and what BILLS. Booking is the
// commitment, presence is the fact, and the gap between them is the
// whole subject — a booking nobody came to bills in full, and one left
// early bills in full until somebody else agrees otherwise.
//
// The member sees their own; whoever may see the money sees everyone's.
// The list is the audit trail #833 asked for, so a corrected row keeps
// saying what it used to be.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/usage_record.dart';
import '../../providers/money_providers.dart';
import '../../providers/usage_providers.dart';

/// One month of usage, newest first.
class UsageFace extends ConsumerWidget {
  const UsageFace({super.key, required this.period});

  final String period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(usageRecordsProvider(period));
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final me = ref.watch(myMemberProvider).value;

    return switch (async) {
      AsyncData(value: final records) when records.isEmpty => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            l10n?.usageEmpty ?? 'No usage this month.',
            key: const ValueKey('usage-empty'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      AsyncData(value: final records) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final record in records)
              UsageRecordCard(
                record: record,
                memberName: names[record.memberId] ?? '',
                // Only the person who was there may ask, which is the
                // server's rule too — the button never lies about it.
                mine: me?.id == record.memberId,
                mayRemove: (me?.isAdmin ?? false) || (me?.isOwner ?? false),
              ),
          ],
        ),
      AsyncError() => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(l10n?.workspaceGenericError ?? 'Something went wrong.'),
        ),
      _ => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
    };
  }
}

/// One booking: what it was, what happened, what it costs.
class UsageRecordCard extends ConsumerWidget {
  const UsageRecordCard({
    super.key,
    required this.record,
    required this.memberName,
    required this.mine,
    required this.mayRemove,
  });

  final UsageRecord record;
  final String memberName;
  final bool mine;
  final bool mayRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final day = DateFormat.MMMEd(locale).format(record.reservedFrom);
    final from = DateFormat.Hm(locale).format(record.reservedFrom);
    final to = DateFormat.Hm(locale).format(record.reservedTo);

    return Card(
      key: ValueKey('usage-${record.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      day,
                      '$from–$to',
                      if (record.spaceLabel.isNotEmpty) record.spaceLabel,
                      if (!mine && memberName.isNotEmpty) memberName,
                    ].join(' · '),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  usageDuration(record.countedMinutes),
                  key: ValueKey('usage-billed-${record.id}'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: record.isCorrected
                        ? AppStatusColors.successTextOf(theme.brightness)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [
                '${l10n?.usageBooked ?? 'Booked'} '
                    '${usageDuration(record.reservedMinutes)}',
                if (record.actualMinutes case final actual?)
                  '${l10n?.usagePresent ?? 'Present'} '
                      '${usageDuration(actual)}',
                '${l10n?.usageBilled ?? 'Billed'} '
                    '${usageDuration(record.countedMinutes)}',
              ].join(' · '),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            // A booking nobody came to. Said plainly, because it is the
            // one line people dispute and the rule is not obvious.
            if (record.isNoShow)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  l10n?.usageNoShow ??
                      'Nobody checked in — the booking bills in full',
                  key: ValueKey('usage-noshow-${record.id}'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            // A corrected row keeps saying what it used to be: that is
            // the audit trail, not decoration.
            if (record.isCorrected)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${l10n?.usageCorrected ?? 'Corrected'} — '
                  '${l10n?.usageWas(usageDuration(record.correctedFromMinutes ?? record.reservedMinutes)) ?? 'was ${usageDuration(record.correctedFromMinutes ?? record.reservedMinutes)}'}',
                  key: ValueKey('usage-corrected-${record.id}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: AppStatusColors.successTextOf(theme.brightness)),
                ),
              ),
            if (mine && record.leftEarly)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: ValueKey('usage-ask-${record.id}'),
                  icon: const Icon(Icons.timelapse_outlined, size: 18),
                  label: Text(
                      l10n?.usageAsk ?? 'Bill the time I was here'),
                  onPressed: () => _ask(context, ref),
                ),
              ),
            if (mayRemove)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: ValueKey('usage-delete-${record.id}'),
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error),
                  icon: const Icon(Icons.playlist_remove_outlined, size: 18),
                  label: Text(l10n?.usageDelete ?? 'Remove this record'),
                  onPressed: () => _remove(context, ref),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _ask(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final asked = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.usageAsk ?? 'Bill the time I was here'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n?.usageAskExplain(
                  usageDuration(record.reservedMinutes),
                  usageDuration(record.actualMinutes ?? 0),
                  usageDuration(record.reducibleMinutes),
                ) ??
                'Somebody else decides it — never you.'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('usage-ask-reason'),
              controller: controller,
              decoration: InputDecoration(
                labelText: l10n?.usageReasonLabel ?? 'Why (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('usage-ask-submit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.usageAskSubmit ?? 'Ask'),
          ),
        ],
      ),
    );
    if (asked != true || !context.mounted) return;
    try {
      await ref
          .read(moneyRepositoryProvider)
          .requestUsageCorrection(record.id, reason: controller.text.trim());
      ref.invalidate(usageRecordsProvider);
      invalidateBookingData(ref);
      if (!context.mounted) return;
      AppSnack.success(context,
          l10n?.usageAskSubmitted ?? 'Asked. Somebody else decides it.');
    } catch (error, stack) {
      TraceLogger.instance.error('money', 'usage correction request failed',
          error: error, stackTrace: stack);
      if (!context.mounted) return;
      AppSnack.error(
          context, l10n?.workspaceGenericError ?? 'Something went wrong.');
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(moneyRepositoryProvider).requestUsageRecordDelete(record.id);
      ref.invalidate(usageRecordsProvider);
      if (!context.mounted) return;
      AppSnack.success(
          context, l10n?.usageDeleteSubmitted ?? 'Removal requested.');
    } catch (error, stack) {
      TraceLogger.instance.error('money', 'usage record delete failed',
          error: error, stackTrace: stack);
      if (!context.mounted) return;
      AppSnack.error(
          context, l10n?.workspaceGenericError ?? 'Something went wrong.');
    }
  }
}
