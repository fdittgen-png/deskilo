// SPDX-License-Identifier: 0BSD
//
// Mahnwesen (#472): the pure suggestion rule, the parameterizable
// policy, the Open-tab "Reminder N due" flag, and the reminder LETTER
// generated through the banded report engine.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;

void main() {
  final issued = DateTime.utc(2026, 7, 1);

  group('dueReminderLevel (#472)', () {
    const rules = DunningRules(
      levels: 2,
      firstAfterDays: 14,
      betweenDays: 7,
    );

    test('nothing is due before first_after_days', () {
      expect(
        dueReminderLevel(
          issuedAt: issued,
          reminderCount: 0,
          lastReminderAt: null,
          rules: rules,
          now: issued.add(const Duration(days: 13)),
        ),
        isNull,
      );
    });

    test('level 1 becomes due after first_after_days', () {
      expect(
        dueReminderLevel(
          issuedAt: issued,
          reminderCount: 0,
          lastReminderAt: null,
          rules: rules,
          now: issued.add(const Duration(days: 14)),
        ),
        1,
      );
    });

    test('the next level waits between_days after the LAST reminder', () {
      final last = issued.add(const Duration(days: 14));
      expect(
        dueReminderLevel(
          issuedAt: issued,
          reminderCount: 1,
          lastReminderAt: last,
          rules: rules,
          now: last.add(const Duration(days: 6)),
        ),
        isNull,
      );
      expect(
        dueReminderLevel(
          issuedAt: issued,
          reminderCount: 1,
          lastReminderAt: last,
          rules: rules,
          now: last.add(const Duration(days: 7)),
        ),
        2,
      );
    });

    test('after the configured number of levels, nothing more is EVER '
        'suggested', () {
      expect(
        dueReminderLevel(
          issuedAt: issued,
          reminderCount: 2,
          lastReminderAt: issued.add(const Duration(days: 60)),
          rules: rules,
          now: issued.add(const Duration(days: 365)),
        ),
        isNull,
      );
    });
  });

  group('DunningRules', () {
    test('round-trips json; absent keys take the 3/14/14 defaults; '
        'nonsense clamps', () {
      expect(DunningRules.fromJson(const {}), DunningRules.defaults);
      final rules = const DunningRules(
              levels: 4, firstAfterDays: 10, betweenDays: 5)
          .toJson();
      expect(DunningRules.fromJson(rules),
          const DunningRules(levels: 4, firstAfterDays: 10, betweenDays: 5));
      expect(DunningRules.fromJson(const {'levels': 999}).levels, 9);
      expect(DunningRules.fromJson(const {'first_after_days': -3})
          .firstAfterDays, 1);
    });

    test('migration 0093 stores the column the repository reads', () {
      final sql = File('supabase/migrations/0093_dunning_rules.sql')
          .readAsStringSync();
      expect(sql, contains('dunning_rules'));
    });
  });

  testWidgets('an overdue open invoice is flagged "Reminder 1 due" and '
      'the remind action generates the LETTER — not the invoice PDF '
      '(#472)', (tester) async {
    final shared = <({String name, Uint8List bytes})>[];
    final money = await seededMoney(matched: false);
    // 20 days old — past the 14-day default for level 1.
    money.invoices[0] = money.invoices[0]
        .copyWith(issuedAt: kTestNow.subtract(const Duration(days: 20)));
    await pumpInvoices(
      tester,
      money: money,
      sharer: ({
        required bytes,
        required fileName,
        required mimeType,
        String? text,
      }) async {
        shared.add((name: fileName, bytes: bytes));
      },
    );
    final invoice = money.invoices.single;

    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('invoice-dunning-due-${invoice.id}')),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await tester
          .tap(find.byKey(ValueKey('invoice-remind-${invoice.id}')));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    // The letter went out (its own document, PDF magic bytes), and the
    // reminder was recorded.
    expect(String.fromCharCodes(shared.single.bytes.sublist(0, 5)),
        '%PDF-');
    // #496 — the fixture workspace is German (country DE, no locale
    // configured): the letter resolves to German and says so in its
    // very filename.
    expect(shared.single.name, contains('zahlungserinnerung'));
    expect(money.invoiceReminders[invoice.id], hasLength(1));
    expect(find.text('Reminder recorded.'), findsOneWidget);
  });

  testWidgets('the report editor edits reminder level 1 as its own '
      'document: Reset inserts the Zahlungserinnerung template and Save '
      'stores it per level (#472)', (tester) async {
    final money = await pumpInvoices(tester, money: await seededMoney());

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('invoice-template-doc-r1')),
      120,
      scrollable: find
          .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('invoice-template-doc-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-save')));
    await tester.tap(find.byKey(const ValueKey('invoice-template-save')));
    await tester.pumpAndSettle();

    final level1 = money.pdfTemplate.reminderBands(1);
    expect(level1, isNotNull);
    expect(level1!.header, contains('Payment reminder'));
    expect(level1.body, contains('{{ reminder_level }}'));
    // The invoice's own bands stayed untouched.
    expect(money.pdfTemplate.invoiceBands.hasBands, isFalse);
  });
}
