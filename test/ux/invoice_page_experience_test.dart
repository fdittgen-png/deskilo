// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- the invoice page through the experience guards: a late
// invoice whose reminder is shared by hand (bottom bar: Share reminder 2), a
// declared payment (Confirm / Not received), and a paid one (no bar), at
// 320, 390 and 1280 px, text scale 1.0 and 1.3, light and dark. With
// SHEET=1 it writes build/sheets/invoice_page/<state>--<width>--<theme>.png.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/presentation/invoice_journey.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_page.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_journey_view.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<String?> Function(WidgetRef, String, {required bool accept})?
  decision,
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
      invoicesProvider.overrideWith((ref) async => [_late, _declared, _paid]),
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
        (ref) async => {'0063': (count: 1, last: DateTime(2026, 9, 28))},
      ),
      dunningRulesProvider.overrideWith(
        (ref) async => const DunningRules(),
      ),
      dunningHoldsProvider.overrideWith((ref) async => const {}),
      invoiceTransmissionsProvider.overrideWith((ref) async => const {}),
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
        return 'Someone else has already decided this payment.';
      },
    );
    await tester.tap(find.byKey(const ValueKey('invoice-page-confirm')));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(
      find.text('Someone else has already decided this payment.'),
      findsOneWidget,
    );
  });
}
