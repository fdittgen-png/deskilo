// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3858 — a member's scheduled plan terms in words: each share change with
// the first statement it shows on, each pause with its dates and which
// months are charged in full and which owe no subscription fee, and how
// each stands (waiting for approval, scheduled, applied, applied later
// than its date, refused with the reason, cancelled).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/workspace/domain/member_term_change.dart';
import '../../features/workspace/presentation/subscription_text.dart';
import '../../features/workspace/providers/member_term_providers.dart';
import '../../l10n/app_localizations.dart';

/// What [e] does, in words: the share and the first statement it shows on,
/// or the pause's dates.
String memberTermWhat(AppLocalizations l, AppFormat format, MemberTermEntry e) {
  final day = format.dates(DateShape.numeric).format;
  final month = format.dates(DateShape.monthYear).format;
  final c = e.change;
  if (!e.isPause) {
    return l.memberTermShare(
      subscriptionText(l, format, c.toPct ?? 0),
      day(c.dueOn),
      month(firstPeriodOf(c.dueOn)),
    );
  }
  return switch (e.until) {
    final end? => l.memberTermPauseDated(day(c.dueOn), day(end.dueOn)),
    null => l.memberTermPauseOpen(day(c.dueOn)),
  };
}

/// The money a pause [e] costs, in words: the month it starts in is charged
/// in full unless it starts on the first; every month whose first day it
/// covers owes no subscription fee. Nothing is prorated.
String memberPauseMoney(
  AppLocalizations l,
  AppFormat format,
  MemberTermEntry e,
) {
  final month = format.dates(DateShape.monthYear).format;
  final from = e.change.dueOn;
  final until = e.until?.dueOn;
  final free = freeMonthsOfPause(from, until);
  if (free.isEmpty) return l.memberTermNoFreeMonth;
  final freeText = until == null
      ? l.memberTermMonthOnwards(month(free.first))
      : free.length == 1
      ? month(free.first)
      : l.memberTermMonthRange(month(free.first), month(free.last));
  return from.day == 1
      ? l.memberTermFreeOnly(freeText)
      : l.memberTermChargedThenFree(month(from), freeText);
}

/// How [c] stands, in words.
String memberTermState(
  AppLocalizations l,
  AppFormat format,
  MemberTermChange c,
) {
  final day = format.dates(DateShape.numeric).format;
  return switch (c.state) {
    MemberTermState.pending => l.memberTermPending,
    MemberTermState.scheduled => l.memberTermScheduled,
    MemberTermState.applied when c.late => l.memberTermLate(
      day(c.dueOn),
      day(c.effectiveOn!),
    ),
    MemberTermState.applied => l.memberTermApplied(day(c.dueOn)),
    MemberTermState.refused => l.memberTermRefused(c.reason),
    MemberTermState.cancelled => l.memberTermCancelled,
  };
}

/// The short line the members' table shows for [e]'s next step.
String memberTermNext(AppLocalizations l, AppFormat format, MemberTermEntry e) {
  final day = format.dates(DateShape.numeric).format;
  final c = e.change;
  if (!e.isPause) {
    return l.memberTermNextShare(
      subscriptionText(l, format, c.toPct ?? 0),
      day(c.dueOn),
    );
  }
  return c.upcoming
      ? l.memberTermNextPause(day(c.dueOn))
      : l.memberTermNextResume(day(e.until!.dueOn));
}

/// The scheduled terms of [memberId], newest date last; nothing while
/// there are none or they are not read.
class MemberTermsSection extends ConsumerWidget {
  const MemberTermsSection({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final theme = Theme.of(context);
    final entries = memberTermEntries(
      memberId,
      ref.watch(memberTermChangesProvider).value ?? const [], // empty-ok: no section until the changes are read
    );
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        key: const ValueKey('member-terms'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.memberTermsTitle, style: theme.textTheme.titleSmall),
          for (final e in entries)
            ListTile(
              key: ValueKey('member-term-${e.change.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(memberTermWhat(l, format, e)),
              subtitle: Text(
                [
                  if (e.isPause) memberPauseMoney(l, format, e),
                  memberTermState(
                    l,
                    format,
                    e.change.upcoming || e.until == null ? e.change : e.until!,
                  ),
                ].join('\n'),
              ),
            ),
        ],
      ),
    );
  }
}
