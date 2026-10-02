// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1922 — the invoice sheet shows what is known about each reminder's
// delivery, in words that never overclaim: a share is the sender's
// statement, a push acceptance is not proof it was read, silence is
// "no answer", and a reminder from before tracking stays unknown.
import 'package:deskilo/features/money/domain/reminder_evidence.dart';
import 'package:deskilo/features/money/presentation/widgets/reminder_evidence_list.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/invoices.dart';

void main() {
  test('the server evidence parses, attempts in order', () {
    final evidence = ReminderEvidence.fromJson({
      'intent_id': 'i1',
      'level': 2,
      'origin': 'automatic',
      'status': 'unknown',
      'prepared_at': '2026-10-01T06:15:00Z',
      'collectible_cents': 6000,
      'currency': 'EUR',
      'attempts': [
        {
          'channel': 'push',
          'outcome': 'queued',
          'detail': '',
          'at': '2026-10-01T06:15:00Z',
        },
        {
          'channel': 'push',
          'outcome': 'unknown',
          'detail': 'the push queue gave no answer within an hour',
          'at': '2026-10-01T07:17:00Z',
        },
      ],
    });
    expect(evidence.level, 2);
    expect(evidence.collectibleCents, 6000);
    expect(evidence.attempts.map((a) => a.outcome), ['queued', 'unknown']);
  });

  test('every status reads as what it is in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final status in [
        'prepared',
        'queued',
        'provider_accepted',
        'declared_delivered',
        'failed',
        'unknown',
        'legacy_unknown',
      ]) {
        expect(reminderStatusLabel(l10n, status), isNotEmpty);
      }
      expect(
        reminderStatusLabel(l10n, 'provider_accepted'),
        isNot(reminderStatusLabel(l10n, 'declared_delivered')),
      );
    }
  });

  testWidgets('a reminder sent by hand shows in the sheet as the sender\'s '
      'statement, and the history refreshes on demand', (tester) async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    await money.remindInvoice(invoice.id);
    await pumpInvoices(tester, money: money);
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('invoice-open-${invoice.id}')));
    await tester.pumpAndSettle();

    final history = find.byKey(const ValueKey('invoice-reminder-evidence'));
    await tester.ensureVisible(history);
    expect(find.text('Reminder history'), findsOneWidget);
    expect(
      find.textContaining('Shared by the sender — their statement'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('invoice-reminder-evidence-refresh')),
    );
    await tester.pumpAndSettle();
    expect(history, findsOneWidget);
  });
}
