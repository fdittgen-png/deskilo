// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3858 — a member's dated plan terms in words: each share change with the
// first statement it shows on, each pause with its dates and which months
// stay charged in full and which it frees, and how each stands (waiting for
// approval, scheduled, in force, refused with the reason, cancelled). The
// months already invoiced keep the terms they were invoiced with. A waiting
// pause counts the member's bookings in the months it frees: they stay, and
// are charged as use.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/time/clock.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/domain/booking_policies.dart';
import '../../features/workspace/domain/member_term_change.dart';
import '../../features/workspace/presentation/subscription_text.dart';
import '../../features/workspace/providers/member_term_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
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
  final c = e.change;
  if (!e.isPause) {
    return memberShareText(l, format, c.toPct ?? 0, c.dueOn, invoiced);
  }
  return switch (e.until) {
    final end? => l.memberTermPauseDated(day(c.dueOn), day(end.dueOn)),
    null => l.memberTermPauseOpen(day(c.dueOn)),
  };
}

/// A share of [pct] from [on], in words, with the first statement it shows
/// on (past the months already [invoiced]).
String memberShareText(
  AppLocalizations l,
  AppFormat format,
  int pct,
  DateTime on,
  Set<DateTime> invoiced,
) => l.memberTermShare(
  subscriptionText(l, format, pct),
  format.dates(DateShape.numeric).format(on),
  format
      .dates(DateShape.monthYear)
      .format(firstPeriodOf(on, invoiced: invoiced)),
);

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

/// The money a pause from [from] until [until] (null: until resumed) means,
/// in words: the months that stay charged in full (the month it starts in
/// unless it starts on the 1st, and the months already [invoiced]) and the
/// months it frees. Nothing is prorated.
String memberPauseMoneyText(
  AppLocalizations l,
  AppFormat format,
  DateTime from,
  DateTime? until,
  Set<DateTime> invoiced,
) {
  final money = pauseMoneyOf(from, until, invoiced: invoiced);
  if (money.free.isEmpty) return l.memberTermNoFreeMonth;
  final free = until == null
      ? l.memberTermMonthOnwards(
          format.dates(DateShape.monthYear).format(money.free.first),
        )
      : _months(l, format, money.free);
  return money.charged.isEmpty
      ? l.memberTermFreeOnly(free)
      : l.memberTermChargedThenFree(_months(l, format, money.charged), free);
}

/// The months a pause frees that can hold bookings: those it frees, and for
/// a pause until resumed every later one not invoiced up to the furthest a
/// booking can be made.
List<DateTime> _bookableFreeMonths(
  WidgetRef ref,
  DateTime from,
  DateTime? until,
  Set<DateTime> invoiced,
) {
  final money = pauseMoneyOf(from, until, invoiced: invoiced);
  if (until != null || money.free.isEmpty) return money.free;
  final horizon =
      ref.watch(bookingPoliciesProvider).value?.advanceHorizonDays ??
      BookingPolicies.defaultHorizonDays;
  final last = ref.watch(clockProvider).now().add(Duration(days: horizon));
  final months = <DateTime>[];
  for (
    var m = money.free.first;
    !m.isAfter(DateTime(last.year, last.month)) || months.isEmpty;
    m = DateTime(m.year, m.month + 1)
  ) {
    if (!invoiced.contains(m)) months.add(m);
  }
  return months;
}

/// The bookings of [memberId] in the months a pause from [from] until
/// [until] frees, in words — they stay, and are charged as use beyond a
/// quota of 0 — or null when there are none or they are not read yet.
String? memberPauseBookingsText(
  WidgetRef ref,
  AppLocalizations l,
  String memberId,
  DateTime from,
  DateTime? until,
  Set<DateTime> invoiced,
) => switch (_bookingsIn(
  ref,
  memberId,
  _bookableFreeMonths(ref, from, until, invoiced),
)) {
  final n? when n > 0 => l.memberTermBookingsInFreeMonths(n),
  _ => null,
};

/// The member's bookings in [months]. Null while a month is not read.
int? _bookingsIn(WidgetRef ref, String memberId, List<DateTime> months) {
  var n = 0;
  for (final m in months) {
    final rows = ref.watch(reservationsForMonthProvider(monthKeyOf(m))).value;
    if (rows == null) return null;
    n += rows.where((r) => r.memberId == memberId && r.held).length;
  }
  return n;
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
                  if (e.isPause)
                    memberPauseMoneyText(
                      l,
                      format,
                      e.change.dueOn,
                      e.until?.dueOn,
                      invoiced,
                    ),
                  if (e.isPause && e.change.upcoming)
                    ?memberPauseBookingsText(
                      ref,
                      l,
                      memberId,
                      e.change.dueOn,
                      e.until?.dueOn,
                      invoiced,
                    ),
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
