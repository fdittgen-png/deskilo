// SPDX-License-Identifier: 0BSD
//
// #833 — a check-out leaves a trace, and the trace is readable.
//
// Three numbers, kept apart on purpose: the window BOOKED, the time
// actually PRESENT, and what BILLS. A booking nobody came to bills in
// full — that was already true on the server and nothing said so. A
// booking left early bills in full too, until somebody OTHER than the
// person who left agrees to reduce it.
import 'package:deskilo/features/money/domain/usage_record.dart';
import 'package:deskilo/features/money/presentation/widgets/usage_face.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

UsageRecord _record({
  int reserved = 480,
  int? actual,
  UsageBasis basis = UsageBasis.reserved,
  int? correctedFrom,
}) =>
    UsageRecord(
      id: 'usage-1',
      memberId: 'member-1',
      reservationId: 'res-1',
      period: '2026-08',
      reservedFrom: DateTime.utc(2026, 8, 12, 9),
      reservedTo: DateTime.utc(2026, 8, 12, 9).add(Duration(minutes: reserved)),
      checkedInAt: actual == null ? null : DateTime.utc(2026, 8, 12, 9),
      checkedOutAt: actual == null
          ? null
          : DateTime.utc(2026, 8, 12, 9).add(Duration(minutes: actual)),
      countedMinutes: basis == UsageBasis.corrected ? actual! : reserved,
      reservedMinutes: reserved,
      actualMinutes: actual,
      basis: basis,
      correctedFromMinutes: correctedFrom,
      spaceLabel: 'Desk A1',
    );

Future<void> _pumpCard(
  WidgetTester tester,
  UsageRecord record, {
  bool mine = true,
  bool mayRemove = false,
  FakeMoneyRepository? money,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(money: money),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: UsageRecordCard(
            record: record,
            memberName: 'Flo',
            mine: mine,
            mayRemove: mayRemove,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('the three numbers', () {
    test('a booking nobody came to counts in full, and says so', () {
      final record = _record();
      expect(record.isNoShow, isTrue);
      expect(record.countedMinutes, record.reservedMinutes);
      expect(record.leftEarly, isFalse,
          reason: 'there is no early departure without a check-out');
      expect(record.reducibleMinutes, 0);
    });

    test('leaving early bills the booking until it is corrected', () {
      final record = _record(actual: 180);
      expect(record.countedMinutes, 480);
      expect(record.actualMinutes, 180);
      expect(record.leftEarly, isTrue);
      expect(record.reducibleMinutes, 300);
    });

    test('staying to the end leaves nothing to ask for', () {
      expect(_record(actual: 480).leftEarly, isFalse);
      expect(_record(actual: 500).leftEarly, isFalse,
          reason: 'staying past the end is not an early departure');
    });

    test('a corrected record can never be corrected twice', () {
      final record =
          _record(actual: 180, basis: UsageBasis.corrected, correctedFrom: 480);
      expect(record.isCorrected, isTrue);
      expect(record.countedMinutes, 180);
      expect(record.correctedFromMinutes, 480);
      expect(record.leftEarly, isFalse);
    });

    test('durations read as hours and minutes, never as raw minutes', () {
      expect(usageDuration(480), '8 h');
      expect(usageDuration(200), '3 h 20');
      expect(usageDuration(45), '45 min');
    });
  });

  group('the card', () {
    testWidgets('names booked, present and billed together', (tester) async {
      await _pumpCard(tester, _record(actual: 180));
      expect(find.textContaining('Booked 8 h'), findsOneWidget);
      expect(find.textContaining('Present 3 h'), findsOneWidget);
      expect(find.textContaining('Billed 8 h'), findsOneWidget);
    });

    testWidgets('a no-show says the booking bills in full', (tester) async {
      await _pumpCard(tester, _record());
      expect(find.byKey(const ValueKey('usage-noshow-usage-1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('usage-ask-usage-1')), findsNothing);
    });

    testWidgets('a corrected record keeps saying what it used to be',
        (tester) async {
      await _pumpCard(
          tester,
          _record(
              actual: 180,
              basis: UsageBasis.corrected,
              correctedFrom: 480));
      expect(find.byKey(const ValueKey('usage-corrected-usage-1')),
          findsOneWidget);
      expect(find.textContaining('was 8 h'), findsOneWidget);
    });

    testWidgets('only the person who was there is offered the ask',
        (tester) async {
      await _pumpCard(tester, _record(actual: 180), mine: false);
      expect(find.byKey(const ValueKey('usage-ask-usage-1')), findsNothing);
      await _pumpCard(tester, _record(actual: 180));
      expect(find.byKey(const ValueKey('usage-ask-usage-1')), findsOneWidget);
    });

    testWidgets('asking reduces the billed time and says somebody else '
        'decides', (tester) async {
      final money = FakeMoneyRepository();
      final seeded =
          money.seedUsage(reservedMinutes: 480, actualMinutes: 180);
      await _pumpCard(tester, seeded, money: money);

      await tester.tap(find.byKey(ValueKey('usage-ask-${seeded.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('usage-ask-submit')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('usage-ask-submit')));
      await tester.pumpAndSettle();

      final after = money.usageRecords.single;
      expect(after.isCorrected, isTrue);
      expect(after.countedMinutes, 180);
      expect(after.correctedFromMinutes, 480);
    });

    testWidgets('with a rule configured the ask changes nothing yet',
        (tester) async {
      final money = FakeMoneyRepository()..usagePolicyConfigured = true;
      final seeded =
          money.seedUsage(reservedMinutes: 480, actualMinutes: 180);
      await _pumpCard(tester, seeded, money: money);
      await tester.tap(find.byKey(ValueKey('usage-ask-${seeded.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('usage-ask-submit')));
      await tester.pumpAndSettle();
      expect(money.usageRecords.single.isCorrected, isFalse,
          reason: 'it waits for somebody else, which is the whole point');
    });

    testWidgets('somebody else cannot ask on the member\'s behalf',
        (tester) async {
      final money = FakeMoneyRepository()..usageMemberId = 'member-9';
      final seeded =
          money.seedUsage(reservedMinutes: 480, actualMinutes: 180);
      await expectLater(
        money.requestUsageCorrection(seeded.id),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('an admin is offered the removal, a member is not',
        (tester) async {
      await _pumpCard(tester, _record(actual: 180));
      expect(find.byKey(const ValueKey('usage-delete-usage-1')), findsNothing);
      await _pumpCard(tester, _record(actual: 180), mayRemove: true);
      expect(
          find.byKey(const ValueKey('usage-delete-usage-1')), findsOneWidget);
    });
  });

  test('the fake refuses what the server refuses', () async {
    final money = FakeMoneyRepository();
    final noShow = money.seedUsage(reservedMinutes: 480);
    await expectLater(money.requestUsageCorrection(noShow.id),
        throwsA(isA<StateError>()));
    final full = money.seedUsage(reservedMinutes: 480, actualMinutes: 480);
    await expectLater(money.requestUsageCorrection(full.id),
        throwsA(isA<StateError>()));
  });
}
