// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- the invoice page through the experience guards: a late
// invoice whose reminder is shared by hand (bottom bar: Share reminder 2), a
// declared payment (Confirm / Not received), and a paid one (no bar), at
// 320, 390 and 1280 px, text scale 1.0 and 1.3, light and dark. With
// SHEET=1 it writes build/sheets/invoice_page/<state>--<width>--<theme>.png.
import 'dart:async';

import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/application/unassigned_money.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/member_account_queries.dart';
import 'package:deskilo/features/money/domain/reminder_evidence.dart';
import 'package:deskilo/features/money/presentation/invoice_journey.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_page.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_reads.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_journey_view.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/reminder_evidence_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../helpers/pump_app.dart';
import 'experience_guards.dart';

final _now = DateTime(2026, 11, 10, 12);

Invoice _invoice(String id, {required DateTime due, int total = 10000}) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'kalo',
      number: '2026-$id',
      issuedAt: due.subtract(const Duration(days: 14)),
      period: '2026-09',
      title: '2026-09',
      lines: [
        InvoiceLine(
          label: 'Flexible desk · 12 days',
          amountCents: total - 2000,
        ),
        const InvoiceLine(label: 'Meeting room · 2 hours', amountCents: 2000),
      ],
      totalCents: total,
      currency: 'CHF',
      memberName: 'SASU KaloA',
      memberAddress: '',
      workspaceName: 'Space',
      workspaceAddress: '',
      issuerName: 'Owner',
      signature: 'sig',
      dueOn: due,
    );

final _late = _invoice('0063', due: DateTime(2026, 9, 21));
final _declared = _invoice('0071', due: DateTime(2026, 10, 12), total: 42000);
final _paid = _invoice('0058', due: DateTime(2026, 10, 15), total: 64000);

/// Issued by mistake and replaced by 0051.
final _cancelled = _invoice(
  '0050',
  due: DateTime(2026, 10),
).copyWith(voidedAt: DateTime(2026, 9, 20));
final _replacement = _invoice(
  '0051',
  due: DateTime(2026, 10, 5),
).copyWith(replacesInvoiceId: '0050', replacesNumber: '2026-0050');

/// The declared payment is the customer's own pending event on 0071.
const _declaredFacts = (
  journey: (
    declaredCents: 42000,
    recordedForMemberCents: 0,
    registeredCents: 0,
    writeoffPending: false,
  ),
  declaration: null,
);

Future<void> _pump(
  WidgetTester tester,
  String id, {
  required double width,
  required bool dark,
  required double scale,
  bool held = false,
  bool remindersFail = false,
  Future<DeclaredPaymentDecided> Function(
    WidgetRef,
    String, {
    required bool accept,
  })?
  decision,
  MemberAccountQueries? ledger,
}) async {
  await pumpApp(
    tester,
    RepaintBoundary(
      child: Theme(
        data: dark ? DeskiloTheme.dark() : DeskiloTheme.light(),
        child: InvoicePage(invoiceId: id),
      ),
    ),
    overrides: [
      clockProvider.overrideWithValue(FixedClock(_now)),
      invoicesProvider.overrideWith(
        (ref) async => [_late, _declared, _paid, _cancelled, _replacement],
      ),
      invoiceMatchesProvider.overrideWith(
        (ref) async => {
          '0058': InvoiceMatch(
            invoiceId: '0058',
            paidCents: 64000,
            resolution: 'exact',
            matchedAt: DateTime(2026, 11, 3),
          ),
        },
      ),
      invoiceRemindersProvider.overrideWith(
        (ref) async => remindersFail
            ? throw StateError('reminders unreadable')
            : {'0063': (count: 1, last: DateTime(2026, 9, 28))},
      ),
      if (ledger != null) memberAccountQueriesProvider.overrideWithValue(ledger),
      dunningRulesProvider.overrideWith((ref) async => const DunningRules()),
      // The bar waits for the money received and not assigned: read, none.
      unassignedMoneyProvider.overrideWith(
        (ref) async => const UnassignedMoney(currency: 'CHF', paymentsOf: {}),
      ),
      dunningHoldsProvider.overrideWith(
        (ref) async => held ? const {"0063": "dispute"} : const {},
      ),
      invoiceTransmissionsProvider.overrideWith((ref) async => const {}),
      // #3680 — the declarations are a named source of the page: answered
      // here (the facts themselves are stubbed below).
      eventsProvider.overrideWith((ref) async => const []),
      // One reminder shared by hand on 0063, as its history shows it.
      reminderEvidenceProvider.overrideWith(
        (ref, invoiceId) async => [
          if (invoiceId == '0063')
            ReminderEvidence(
              intentId: 'r-1',
              level: 1,
              origin: 'share',
              status: 'sent',
              preparedAt: DateTime(2026, 9, 28),
            ),
        ],
      ),
      if (decision != null)
        declaredPaymentDecisionProvider.overrideWithValue(decision),
      invoiceEventFactsProvider.overrideWithValue(
        (invoice, match) => invoice.id == '0071'
            ? (
                journey: _declaredFacts.journey,
                declaration: (
                  eventId: 'e-0071',
                  paidOn: DateTime(2026, 11, 9),
                  amountCents: 42000,
                ),
              )
            : (journey: noJourneyFacts, declaration: null),
      ),
    ],
    size: Size(width, width < 600 ? 5000 : 2400),
    textScale: scale,
  );
  await tester.pumpAndSettle();
}

/// Lets a tapped action answer and its message or route animate in: the
/// calls here answer at once, so a bounded pump is enough.
Future<void> _answer(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  for (final (state, id) in [
    ('reminder-due', '0063'),
    ('declared', '0071'),
    ('paid', '0058'),
  ]) {
    testWidgets('the invoice page · $state', (tester) async {
      await loadSheetFonts();
      final semantics = tester.ensureSemantics();
      final problems = <String, Set<String>>{};
      for (final dark in [false, true]) {
        for (final scale in guardScales) {
          for (final width in guardWidths) {
            await _pump(tester, id, width: width, dark: dark, scale: scale);
            final tag = '$width px, ×$scale, ${dark ? 'dark' : 'light'}';
            for (final p in guardProblems(tester, width: width)) {
              problems.putIfAbsent(p, () => {}).add(tag);
            }
            if (scale == 1.0 && width != 320) {
              await writeSheet(
                tester,
                sheet: 'invoice_page',
                name: '$state--${width.toInt()}--${dark ? 'dark' : 'light'}',
              );
            }
          }
        }
      }
      // The main action of each state sits in the bottom bar.
      switch (state) {
        case 'reminder-due':
          expect(find.byKey(const ValueKey('invoice-page-remind')), findsOne);
        case 'declared':
          expect(find.byKey(const ValueKey('invoice-page-confirm')), findsOne);
          expect(
            find.byKey(const ValueKey('invoice-page-not-received')),
            findsOne,
          );
        case _:
          expect(find.byType(FilledButton), findsNothing);
      }
      semantics.dispose();
      expect(problems, isEmpty);
    });
  }

  testWidgets('a refused decision is said in words', (tester) async {
    var asked = 0;
    await _pump(
      tester,
      '0071',
      width: 390,
      dark: false,
      scale: 1,
      decision: (ref, eventId, {required accept}) async {
        asked++;
        throw const PostgrestException(
            message: 'event already decided', code: 'DKD01');
      },
    );
    await tester.tap(find.byKey(const ValueKey('invoice-page-confirm')));
    await _answer(tester);
    expect(asked, 1);
    expect(
      find.text(
        'Someone has already decided this. The list shows the outcome.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a refusal without a reason is said in words', (tester) async {
    await _pump(
      tester,
      '0071',
      width: 390,
      dark: false,
      scale: 1,
      decision: (ref, eventId, {required accept}) async =>
          throw const PostgrestException(message: ''),
    );
    await tester.tap(find.byKey(const ValueKey('invoice-page-confirm')));
    await _answer(tester);
    expect(
      find.text('Your decision on this payment was not recorded.'),
      findsOneWidget,
    );
  });

  testWidgets('a confirmation the quorum keeps pending matches nothing', (
    tester,
  ) async {
    final ledger = _CountingLedger();
    await _pump(
      tester,
      '0071',
      width: 390,
      dark: false,
      scale: 1,
      ledger: ledger,
      decision: (ref, eventId, {required accept}) async =>
          DeclaredPaymentDecided.waitsForOthers,
    );
    await tester.tap(find.byKey(const ValueKey('invoice-page-confirm')));
    await _answer(tester);
    expect(
      find.text('Your approval is recorded; it waits for the others.'),
      findsOneWidget,
    );
    expect(find.textContaining('Payment confirmed'), findsNothing);
    expect(ledger.reads, 0, reason: 'no payment is looked up to match');
  });

  testWidgets('a Not received the quorum keeps pending says so', (
    tester,
  ) async {
    await _pump(
      tester,
      '0071',
      width: 390,
      dark: false,
      scale: 1,
      decision: (ref, eventId, {required accept}) async =>
          DeclaredPaymentDecided.waitsForOthers,
    );
    await tester.tap(find.byKey(const ValueKey('invoice-page-not-received')));
    await _answer(tester);
    expect(
      find.text('Your answer is recorded; it waits for the others.'),
      findsOneWidget,
    );
    expect(find.textContaining('not received'), findsNothing);
  });

  testWidgets('an approved confirmation goes on to the match', (tester) async {
    final ledger = _CountingLedger();
    await _pump(
      tester,
      '0071',
      width: 390,
      dark: false,
      scale: 1,
      ledger: ledger,
      decision: (ref, eventId, {required accept}) async =>
          DeclaredPaymentDecided.approved,
    );
    await tester.tap(find.byKey(const ValueKey('invoice-page-confirm')));
    await _answer(tester);
    expect(ledger.reads, 1);
  });

  testWidgets('a second tap while the first call runs sends nothing', (
    tester,
  ) async {
    final answer = Completer<DeclaredPaymentDecided>();
    var asked = 0;
    await _pump(
      tester,
      '0071',
      width: 390,
      dark: false,
      scale: 1,
      decision: (ref, eventId, {required accept}) {
        asked++;
        return answer.future;
      },
    );
    await tester.tap(find.byKey(const ValueKey('invoice-page-not-received')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('invoice-page-confirm')));
    await tester.tap(find.byKey(const ValueKey('invoice-page-not-received')));
    await tester.pump();
    expect(asked, 1);
    answer.complete(DeclaredPaymentDecided.ended);
    await _answer(tester);
    expect(find.text('Marked as not received.'), findsOneWidget);
    // Once it answered, the bar takes a tap again.
    await tester.tap(find.byKey(const ValueKey('invoice-page-not-received')));
    await _answer(tester);
    expect(asked, 2);
  });

  testWidgets('while a source the bar reads has failed, the bar stays away', (
    tester,
  ) async {
    await _pump(
      tester,
      '0071',
      width: 390,
      dark: false,
      scale: 1,
      remindersFail: true,
    );
    expect(find.byKey(const ValueKey('invoice-page-confirm')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-page-not-received')), findsNothing);
  });

  testWidgets('an invoice no longer readable says so and closes', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('open-gone'),
            onPressed: () => openInvoicePage(context, 'gone'),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_now)),
        invoicesProvider.overrideWith((ref) async => [_late]),
      ],
      size: const Size(390, 800),
    );
    await _answer(tester);
    await tester.tap(find.byKey(const ValueKey('open-gone')));
    await _answer(tester);
    expect(find.text('This invoice can no longer be read.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invoice-page-close')));
    await _answer(tester);
    expect(find.byKey(const ValueKey('invoice-page-gone')), findsNothing);
    expect(find.byKey(const ValueKey('open-gone')), findsOneWidget);
  });

  // #3587 -- the three states the coordinator reads on one sheet: on hold
  // with its reason, cancelled and replaced, the reminders opened.
  for (final (state, id, held) in [
    ('on-hold', '0063', true),
    ('cancelled-replaced', '0050', false),
    ('reminders-opened', '0063', false),
  ]) {
    testWidgets('the invoice page · $state', (tester) async {
      await loadSheetFonts();
      final semantics = tester.ensureSemantics();
      final problems = <String, Set<String>>{};
      for (final dark in [false, true]) {
        for (final scale in guardScales) {
          for (final width in guardWidths) {
            await _pump(
              tester,
              id,
              width: width,
              dark: dark,
              scale: scale,
              held: held,
            );
            if (state == 'reminders-opened') {
              await tester.tap(
                find.byKey(const ValueKey('invoice-page-reminders')),
              );
              await tester.pumpAndSettle();
            }
            final tag = '$width px, ×$scale, ${dark ? 'dark' : 'light'}';
            for (final p in guardProblems(tester, width: width)) {
              problems.putIfAbsent(p, () => {}).add(tag);
            }
            if (scale == 1.0 && width != 320) {
              await writeSheet(
                tester,
                sheet: 'invoice_page',
                name: '$state--${width.toInt()}--${dark ? 'dark' : 'light'}',
              );
            }
          }
        }
      }
      switch (state) {
        case 'on-hold':
          expect(find.textContaining('Reminders on hold:'), findsOneWidget);
        case 'cancelled-replaced':
          expect(
            find.byKey(const ValueKey('invoice-page-replaced-by')),
            findsOne,
          );
        case _:
          expect(
            find.byKey(const ValueKey('invoice-reminder-evidence')),
            findsOne,
          );
      }
      semantics.dispose();
      expect(problems, isEmpty);
    });
  }
}

/// Counts the ledger reads the match after a confirmation starts with.
class _CountingLedger implements MemberAccountQueries {
  int reads = 0;

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async {
    reads++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
