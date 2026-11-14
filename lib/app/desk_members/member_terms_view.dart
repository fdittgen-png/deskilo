// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3858 — a member's dated plan terms in words: each share change with the
// first statement it shows on, each pause with its dates and which months
// stay charged in full and which it frees, and how each stands (waiting for
// approval, scheduled, in force, refused with the reason, cancelled). The
// months already invoiced keep the terms they were invoiced with.
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
String _what(
  AppLocalizations l,
  AppFormat format,
  MemberTermEntry e,
  Set<DateTime> invoiced,
) {
  final day = format.dates(DateShape.numeric).format;
  final month = format.dates(DateShape.monthYear).format;
  final c = e.change;
  if (!e.isPause) {
    return l.memberTermShare(
      subscriptionText(l, format, c.toPct ?? 0),
      day(c.dueOn),
      month(firstPeriodOf(c.dueOn, invoiced: invoiced)),
    );
  }
  return switch (e.until) {
    final end? => l.memberTermPauseDated(day(c.dueOn), day(end.dueOn)),
    null => l.memberTermPauseOpen(day(c.dueOn)),
  };
}

/// Months in words: one, a run from the first to the last, or a list.
String _months(AppLocalizations l, AppFormat format, List<DateTime> months) {
  final month = format.dates(DateShape.monthYear).format;
  if (months.length == 1) return month(months.single);
  final run = [
    for (var i = 1; i < months.length; i++)
      DateTime(months[i - 1].year, months[i - 1].month + 1) == months[i],
  ].every((next) => next);
  return run
      ? l.memberTermMonthRange(month(months.first), month(months.last))
      : months.map(month).join(', ');
}

/// The money a pause [e] means, in words: the months that stay charged in
/// full (the month it starts in unless it starts on the 1st, and the months
/// already invoiced) and the months it frees. Nothing is prorated.
String _pauseMoney(
  AppLocalizations l,
  AppFormat format,
  MemberTermEntry e,
  Set<DateTime> invoiced,
) {
  final money = pauseMoneyOf(
    e.change.dueOn,
    e.until?.dueOn,
    invoiced: invoiced,
  );
  if (money.free.isEmpty) return l.memberTermNoFreeMonth;
  final free = e.until == null
      ? l.memberTermMonthOnwards(
          format.dates(DateShape.monthYear).format(money.free.first),
        )
      : _months(l, format, money.free);
  return money.charged.isEmpty
      ? l.memberTermFreeOnly(free)
      : l.memberTermChargedThenFree(_months(l, format, money.charged), free);
}

/// How [c] stands, in words.
String _state(AppLocalizations l, AppFormat format, MemberTermChange c) {
  final day = format.dates(DateShape.numeric).format;
  return switch (c.state) {
    MemberTermState.pending => l.memberTermPending,
    MemberTermState.scheduled => l.memberTermScheduled,
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

/// The dated terms of [memberId], in date order; nothing while there are
/// none or they are not read.
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
      ref.watch(memberTermChangesProvider).value ??
          const [], // empty-ok: no section until the changes are read
    );
    final invoiced =
        ref.watch(memberInvoicedMonthsProvider).value?[memberId] ??
        const <
          DateTime
        >{}; // empty-ok: before they are read, no month counts as invoiced
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
              title: Text(_what(l, format, e, invoiced)),
              subtitle: Text(
                [
                  if (e.isPause) _pauseMoney(l, format, e, invoiced),
                  _state(
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
