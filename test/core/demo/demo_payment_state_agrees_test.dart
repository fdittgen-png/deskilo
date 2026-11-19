// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4225 — a payment reads the same on both sides. The Payments tab of My
// finances lists what a person paid; a transfer that arrived and that no
// invoice has taken is "received, waiting to be matched" there, and the
// business holds it under Payments to match (what is left of it, by the
// rule every reader of the business shares). A payment an invoice has taken
// is confirmed on both. Read from the same Demo, for each business.
import 'package:deskilo/core/demo/demo_finances.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/features/money/application/unassigned_money.dart';
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

void main() {
  test('every entry of the Payments tab reads as the business holds it: '
      'waiting to be matched where payments to match has it left, confirmed '
      'where an invoice took it', () async {
    final journey = DemoJourney.start(persona: DemoPersona.member);
    addTearDown(journey.dispose);
    final fixture = journey.fixture;
    final me = fixture.actor.memberId;
    final rows = await demoActivityRepository(fixture)
        .list(AccountActivityKind.payments);
    expect(rows, isNotEmpty);

    var waiting = 0;
    for (final key in DemoSpaceKey.values) {
      final money = fixture.space(key).money;
      final use = paymentUseOf(
        junction: await money.fetchConsumedPaymentIds(key.id),
        moved: const {},
      );
      for (final e in money.ledger) {
        if (e.memberId != me ||
            e.category != LedgerCategory.payment ||
            e.kind != LedgerKind.credit) {
          continue;
        }
        // the tab is a page: the entries it lists are the ones compared
        final row = rows.where((r) => r.id == e.id).firstOrNull;
        if (row == null) continue;
        final held = use.remainingOf(e) > 0;
        expect(
          row.status,
          held ? 'awaiting_match' : 'confirmed',
          reason: '${e.id}: the tab and the business agree on its state',
        );
        if (held) waiting++;
      }
    }
    expect(
      rows.where((r) => r.status == 'awaiting_match'),
      hasLength(waiting),
      reason: 'nothing waits on the tab that the business does not hold',
    );
    expect(
      rows.any(
        (r) =>
            r.id == 'demo-payment-bruno-unmatched' &&
            r.status == 'awaiting_match',
      ),
      isTrue,
      reason: 'the transfer of the day before waits for a match',
    );
  });
}
