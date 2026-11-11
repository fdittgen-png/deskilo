// SPDX-License-Identifier: AGPL-3.0-or-later
// #3284 — the booking sheet says "present" one way, and the review shows the
// half-days left this month when the statement answered (the sentence on how
// the charge is settled stays either way).
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_review_summary.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

const _statement = Statement(
  period: '2026-05',
  subscriptionPct: 100,
  feeCents: 15000,
  includedHalfDays: 10,
  openDays: 22,
  usedHalfDays: 7,
  extraHalfDays: 0,
  overageCents: 0,
  creditsCents: 0,
  balanceCents: 0,
  remainingHalfDays: 3,
);

final _now = DateTime(2026, 5, 13, 10);

Widget _sheet({required bool offerModes}) => BookingSheet(
  seatName: 'A1',
  resourceContext: const ['Demo'],
  timezone: 'Europe/Berlin',
  start: DateTime(2026, 5, 13, 8),
  initialEnd: DateTime(2026, 5, 13, 12),
  cap: null,
  capped: false,
  walkUp: false,
  now: _now,
  fixedEnd: true,
  granularity: BookingGranularity.halfDay,
  walkUpOption: offerModes
      ? (start: _now, end: DateTime(2026, 5, 13, 12), cap: null, capped: false)
      : null,
  myMemberId: 'flo',
  members: const [(id: 'flo', name: 'Flo')],
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const checkIn = ValueKey('booking-check-in-now');
  testWidgets(
    'a live window with the mode selector has no second check-in switch',
    (tester) async {
      await _pump(
        tester,
        _sheet(offerModes: true),
        overrides: [
          memberStatementProvider(
            'flo',
            '2026-05',
          ).overrideWith((_) async => null),
        ],
      );
      expect(
        find.byKey(const ValueKey('booking-sheet-booking-mode-selector')),
        findsOneWidget,
      );
      expect(find.byKey(checkIn), findsNothing);
    },
  );

  testWidgets('without a selector the switch is the one way to check in', (
    tester,
  ) async {
    await _pump(
      tester,
      _sheet(offerModes: false),
      overrides: [
        memberStatementProvider(
          'flo',
          '2026-05',
        ).overrideWith((_) async => null),
      ],
    );
    expect(find.byKey(checkIn), findsOneWidget);
  });

  Widget summary() => BookingReviewSummary(
    resource: const ['A1'],
    person: 'Flo',
    window: (start: DateTime(2026, 5, 14, 8), end: DateTime(2026, 5, 14, 12)),
    today: DateTime(2026, 5, 13),
    allowance: (memberId: 'flo', period: '2026-05'),
  );

  testWidgets('the review shows the half-days left from the statement', (
    tester,
  ) async {
    await _pump(
      tester,
      summary(),
      overrides: [
        memberStatementProvider(
          'flo',
          '2026-05',
        ).overrideWith((_) async => _statement),
      ],
    );
    expect(
      find.text('3 half-days left in your allowance this month'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('booking-charge-context')),
      findsOneWidget,
    );
  });

  testWidgets(
    'an unread statement shows no allowance, only how it is settled',
    (tester) async {
      await _pump(
        tester,
        summary(),
        overrides: [
          memberStatementProvider(
            'flo',
            '2026-05',
          ).overrideWith((_) async => throw StateError('offline')),
        ],
      );
      expect(
        find.byKey(const ValueKey('booking-allowance-left')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('booking-charge-context')),
        findsOneWidget,
      );
    },
  );
}
