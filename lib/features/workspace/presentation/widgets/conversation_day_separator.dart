// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Whether [a] and [b] fall on the same calendar day where the device is.
bool sameLocalDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// #821 — "Today", "Yesterday" or the date, centred between the days.
class ConversationDaySeparator extends StatelessWidget {
  const ConversationDaySeparator({
    super.key,
    required this.day,
    required this.today,
  });

  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final d = DateTime(day.year, day.month, day.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t).inDays;
    final label = diff == 0
        ? (l10n.conversationToday)
        : diff == -1
        ? (l10n.conversationYesterday)
        : DateFormat.yMMMEd(Localizations.maybeLocaleOf(context)?.toString())
              .format(day);
    return Center(
      child: Container(
        key: ValueKey('conversation-day-${d.year}-${d.month}-${d.day}'),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.xlAll,
        ),
        child: Text(label, style: theme.textTheme.labelSmall),
      ),
    );
  }
}
