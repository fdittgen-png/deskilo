// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3335 — the Demo use case of settling an unsettled e-invoice submission by
// hand. Chiara's invoice was sent and the platform's answer was lost, so its
// submission is `uncertain` and Send is not offered. An issuer says what the
// platform's own record shows (with a reason and the evidence), and the
// submission settles; a second try changes nothing. Simulated Demo behaviour:
// the server's rules are pgTAP 365 and the handler tests.

import 'package:deskilo/core/demo/seed/demo_money_seed.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';

void main() {
  test('the Demo holds an unsettled submission an issuer can settle once',
      () async {
    final money = FakeMoneyRepository();
    final now = DateTime(2026, 11, 6, 10);
    seedDemoMoneyStory(money, now, const []);

    final before = (await money.fetchInvoiceTransmissions('ws-1'))
        ['demo-invoice-chiara']!;
    expect(before.status, EInvoiceSubmissionStatus.uncertain);
    expect(before.isUnresolved, isTrue);

    final done = await money.resolveEInvoiceTransmission(
      workspaceId: 'ws-1',
      transmissionId: before.id,
      resolution: EInvoiceResolution.accepted,
      reason: 'the platform lists it',
      evidence: 'portal reference, 4 Nov',
    );
    expect(done.resolved, isTrue);
    expect(
      (await money.fetchInvoiceTransmissions('ws-1'))['demo-invoice-chiara']!
          .status,
      EInvoiceSubmissionStatus.accepted,
    );

    final again = await money.resolveEInvoiceTransmission(
      workspaceId: 'ws-1',
      transmissionId: before.id,
      resolution: EInvoiceResolution.failed,
      reason: 'again',
      evidence: 'again',
    );
    expect(again.resolved, isFalse);
    expect(
      (await money.fetchInvoiceTransmissions('ws-1'))['demo-invoice-chiara']!
          .status,
      EInvoiceSubmissionStatus.accepted,
    );
  });
}
