// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3648 — the month grid, the week strip and a date picker opened from a
// screen all start the week on the same day: the reader's format locale's
// (Sunday in en_US, Monday in de_DE and fr_FR, Saturday in ar_EG), or the
// day they chose. The picker returns the day that was tapped.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/i18n/week_start.dart';
import 'package:deskilo/core/ui/app_date_picker.dart';
import 'package:deskilo/features/calendar/presentation/widgets/calendar_month_grid.dart';
import 'package:deskilo/features/calendar/presentation/widgets/calendar_week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// 2026-11-01 is a Sunday: the day whose column tells the first day.
final _firstOfNovember = DateTime(2026, 11);
final _thursday = DateTime(2026, 11, 12);

typedef _Case = ({String name, String locale, WeekStartPref pref, int first});

const _cases = <_Case>[
  (name: 'en_US follows its Sunday', locale: 'en_US', pref: WeekStartPref.locale, first: 7),
  (name: 'de_DE follows its Monday', locale: 'de_DE', pref: WeekStartPref.locale, first: 1),
  (name: 'fr_FR follows its Monday', locale: 'fr_FR', pref: WeekStartPref.locale, first: 1),
  (name: 'ar_EG follows its Saturday', locale: 'ar_EG', pref: WeekStartPref.locale, first: 6),
  (name: 'the setting overrides en_US', locale: 'en_US', pref: WeekStartPref.monday, first: 1),
  (name: 'the setting overrides de_DE', locale: 'de_DE', pref: WeekStartPref.saturday, first: 6),
  (name: 'the setting overrides fr_FR', locale: 'fr_FR', pref: WeekStartPref.sunday, first: 7),
];

/// The column (0 = leftmost) of the first of the month among the days 1..7
/// of one grid: the days 1..7 occupy seven different columns, so the number
/// of them that sit to the left of day 1 is its column.
int _columnOfFirst(WidgetTester tester, Finder Function(int day) dayCell) {
  final left = tester.getCenter(dayCell(1)).dx;
  return [for (var d = 2; d <= 7; d++) tester.getCenter(dayCell(d)).dx]
      .where((x) => x < left)
      .length;
}

void main() {
  setUpAll(initializeDateFormatting);

  for (final c in _cases) {
    testWidgets('${c.name}: grid, strip and picker agree', (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final format = AppFormat(locale: c.locale, currencyCode: 'EUR', weekStart: c.pref);
      final first = weekStartOf(format);
      expect(first, c.first);
      final expectedColumn = (DateTime.sunday - first + 7) % 7;

      DateTime? picked;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appFormatProvider.overrideWithValue(format)],
          child: MaterialApp(
            // The interface is French; the picker's WEEK is the format's.
            locale: const Locale('fr'),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('fr')],
            home: Scaffold(
              body: Builder(
                builder: (context) => ListView(
                  children: [
                    CalendarMonthGrid(
                      month: _firstOfNovember,
                      selectedDay: _thursday,
                      today: _thursday,
                      groupsByDay: const {},
                      onSelect: (_) {},
                    ),
                    CalendarWeekStrip(
                      weekStart: startOfWeek(_thursday, first),
                      selectedDay: _thursday,
                      today: _thursday,
                      groupsByDay: const {},
                      countsByDay: const {},
                      onSelect: (_) {},
                    ),
                    TextButton(
                      key: const ValueKey('open-picker'),
                      onPressed: () async => picked = await showAppDatePicker(
                        context: context,
                        initialDate: _thursday,
                        firstDate: DateTime(2026),
                        lastDate: DateTime(2027),
                      ),
                      child: const Text('open'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // The month grid: the Sunday the 1st sits where the week puts it.
      expect(
        _columnOfFirst(
          tester,
          (d) => find.byKey(CalendarMonthGrid.cellKey(DateTime(2026, 11, d))),
        ),
        expectedColumn,
        reason: 'month grid',
      );

      // The week strip: its leftmost pill is the first day of the week.
      double leftOf(DateTime day) =>
          tester.getCenter(find.byKey(CalendarWeekStrip.pillKey(day))).dx;
      final pills = [
        for (var i = 0; i < 7; i++)
          startOfWeek(_thursday, first).add(Duration(days: i)),
      ]..sort((a, b) => leftOf(a).compareTo(leftOf(b)));
      expect(pills.first.weekday, first, reason: 'week strip');
      expect(pills.first.isAfter(_thursday), isFalse);
      expect(_thursday.difference(pills.first).inDays, lessThan(7));

      // The picker, opened from the screen: same column for the 1st, and
      // the day tapped is the day returned.
      await tester.tap(find.byKey(const ValueKey('open-picker')));
      await tester.pumpAndSettle();
      final calendar = find.byType(CalendarDatePicker);
      expect(calendar, findsOneWidget);
      expect(
        _columnOfFirst(
          tester,
          (d) => find.descendant(of: calendar, matching: find.text('$d')),
        ),
        expectedColumn,
        reason: 'picker',
      );
      await tester.tap(find.descendant(of: calendar, matching: find.text('3')));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(picked, DateTime(2026, 11, 3), reason: 'date identity');
    });
  }

  for (final language in ['en', 'de', 'fr', 'es', 'it']) {
    testWidgets('the picker keeps the $language interface and changes the week only',
        (tester) async {
      for (final pref in [WeekStartPref.sunday, WeekStartPref.monday, WeekStartPref.saturday]) {
        final format = AppFormat(locale: 'en_US', currencyCode: 'EUR', weekStart: pref);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appFormatProvider.overrideWithValue(format)],
            child: MaterialApp(
              key: ValueKey(pref),
              locale: Locale(language),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: [Locale(language)],
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAppDatePicker(
                    context: context,
                    initialDate: _thursday,
                    firstDate: DateTime(2026),
                    lastDate: DateTime(2027),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        final app = MaterialLocalizations.of(tester.element(find.text('open')));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final picker = MaterialLocalizations.of(tester.element(find.byType(CalendarDatePicker)));
        // Sunday is 0 for the framework, Monday 1, Saturday 6: one conversion.
        expect(picker.firstDayOfWeekIndex, switch (pref) {
          WeekStartPref.sunday => 0,
          WeekStartPref.monday => 1,
          _ => 6,
        });
        // ... and the language, the date syntax and the words are untouched.
        expect(picker.narrowWeekdays, app.narrowWeekdays);
        expect(picker.okButtonLabel, app.okButtonLabel);
        expect(picker.cancelButtonLabel, app.cancelButtonLabel);
        expect(picker.dateInputLabel, app.dateInputLabel);
        expect(picker.formatMediumDate(_thursday), app.formatMediumDate(_thursday));
        expect(picker.formatMonthYear(_thursday), app.formatMonthYear(_thursday));
        await tester.tap(find.text(app.cancelButtonLabel));
        await tester.pumpAndSettle();
      }
    });
  }
}
