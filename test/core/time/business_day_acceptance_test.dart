// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3659 (i18n I13) -- the acceptance: a business in Zurich, a person whose
// device is somewhere else, around Zurich's midnight. Every instant is UTC
// and falls where Zurich's day is not the day in UTC nor in Los Angeles, so
// a read of the device's (the runner's) calendar fails here wherever the
// runner sits. Overdue, dunning, the half-day window, the reservation's day
// and month all agree with the business.
import 'package:deskilo/core/time/business_day_providers.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/providers/finance_overview_provider.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/walk_up_window.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

/// 23:30 UTC on 11 November 2026: 00:30 on the 12th in Zurich, 15:30 on the
/// 11th in Los Angeles.
final _justAfterZurichMidnight = DateTime.utc(2026, 11, 11, 23, 30);

FinanceInvoice _invoice(String? zone, {String dueOn = '2026-11-12'}) =>
    FinanceInvoice.fromJson({
      'id': 'inv-$zone',
      'workspace_id': 'ws-$zone',
      'workspace_name': 'Space',
      'number': 'N-1',
      'issued_at': '2026-10-13T09:00:00Z',
      'due_on': dueOn,
      'total_cents': 10000,
      'paid_cents': 0,
      'currency': 'CHF',
      'state': 'open',
      'workspace_timezone': zone,
    });

final class _Clock implements Clock {
  _Clock(this.instant);
  DateTime instant;
  @override
  DateTime now() => instant;
}

final class _Scheduler implements DayBoundaryScheduler {
  final fires = <DateTime, void Function()>{};
  @override
  void Function() at(DateTime instant, void Function() fire) {
    fires[instant] = fire;
    return () => fires.remove(instant);
  }
}

class _Overview extends FinanceOverviewComposer {
  _Overview(this.overview);
  final FinanceOverview overview;
  @override
  Future<FinanceOverview> build() async => overview;
}

void main() {
  setUp(() => WorkspaceTime.install('Europe/Zurich'));
  tearDown(WorkspaceTime.reset);

  group('overdue is the issuing business\'s day', () {
    test('due on the 12th: late in Zurich, not yet in Los Angeles', () {
      expect(_invoice('Europe/Zurich').overdueAt(_justAfterZurichMidnight),
          isTrue);
      expect(
          _invoice('America/Los_Angeles').overdueAt(_justAfterZurichMidnight),
          isFalse);
    });

    test('a frozen due date stays the date it is', () {
      expect(_invoice('Europe/Zurich').dueOn, DateTime(2026, 11, 12));
    });

    test('no zone: never claimed late, and said to be unknown', () {
      for (final zone in [null, 'Mars/Olympus']) {
        final invoice = _invoice(zone);
        expect(invoice.overdueAt(_justAfterZurichMidnight), isFalse,
            reason: '$zone');
        expect(invoice.dueDayUnknownAt(_justAfterZurichMidnight), isTrue,
            reason: '$zone');
      }
      expect(
          _invoice('Europe/Zurich').dueDayUnknownAt(_justAfterZurichMidnight),
          isFalse);
    });

    test('the first reminder is due on the business\'s due day', () {
      int? level(DateTime today) => dueReminderLevel(
            issuedAt: DateTime.utc(2026, 10, 13, 9),
            reminderCount: 0,
            lastReminderAt: null,
            rules: DunningRules.defaults,
            at: (now: _justAfterZurichMidnight, today: today),
            dueOn: DateTime(2026, 11, 12),
          );
      final zurich = businessTodayAt(_justAfterZurichMidnight, 'Europe/Zurich');
      final la =
          businessTodayAt(_justAfterZurichMidnight, 'America/Los_Angeles');
      expect(level(zurich.date!), 1);
      expect(level(la.date!), isNull);
    });
  });

  group('bookings are on the business\'s calendar', () {
    test('the walk-up\'s day is Zurich\'s 12th', () {
      final window = HalfDayWindows.fullDay(
          WorkspaceTime.dateOf(_justAfterZurichMidnight));
      final zurich = tz.getLocation('Europe/Zurich');
      expect(window.start, tz.TZDateTime(zurich, 2026, 11, 12, 8));
      expect(window.end, tz.TZDateTime(zurich, 2026, 11, 12, 17));
      expect(walkUpWindow(BookingGranularity.fullDay, _justAfterZurichMidnight),
          (start: window.start, end: window.end));
    });

    test('the reservation\'s day and month are Zurich\'s', () {
      const zurich = WorkspaceTime.dateOf;
      expect(dayKeyOf(zurich(_justAfterZurichMidnight)), '2026-11-12');
      expect(monthKeyOf(zurich(DateTime.utc(2026, 11, 30, 23, 30))), '2026-12');
      // A picked calendar date is read as the date it is.
      expect(dayKeyOf(DateTime(2026, 11, 12)), '2026-11-12');
      expect(dayKeysForWindow(DateTime.utc(2026, 11, 11, 23),
          DateTime.utc(2026, 11, 12, 23), zurich), ['2026-11-12'],
          reason: 'a Zurich day is one key, wherever the device is');
    });
  });

  test('Me turns an invoice late at its business\'s midnight, with no data '
      'change', () async {
    final clock = _Clock(DateTime.utc(2026, 11, 11, 22, 59, 59));
    final scheduler = _Scheduler();
    final overview = FinanceOverview(invoices: [_invoice('Europe/Zurich')]);
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(clock),
      dayBoundarySchedulerProvider.overrideWithValue(scheduler),
      financeOverviewProvider.overrideWith(() => _Overview(overview)),
    ]);
    addTearDown(container.dispose);
    // Kept read, as the screen keeps it.
    container.listen(financeOverviewProvider, (_, _) {});
    await container.read(financeOverviewProvider.future);
    final late = <bool>[];
    container.listen(financeNowProvider,
        (_, now) => late.add(overview.invoices.single.overdueAt(now)),
        fireImmediately: true);
    expect(late, [false]);

    clock.instant = DateTime.utc(2026, 11, 11, 23);
    scheduler.fires[DateTime.utc(2026, 11, 11, 23)]!();
    container.read(financeNowProvider);
    expect(late, [false, true]);
  });
}
