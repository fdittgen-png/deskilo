// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 (a) — a day pass sold and used in the reference business, in euros,
// and an e-invoice sent through its configured generic channel with its
// receipt. The figures agree after each: the sales, the receivables and the
// pass's record; the invoice reads sent.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_pass_einvoice_journeys.dart';

void main() {
  test('a day pass is sold and used in the reference business', () async {
    expect(await dayPassJourney(), isTrue);
  });

  test('the e-invoice channel is configured and generic', () async {
    final f = DemoFixture.build();
    final gateway = await f.money.eInvoices.fetchEInvoiceGateway('ws-1');
    expect(gateway.configured, isTrue);
    expect(gateway.provider, 'generic');
    final status = await f.money.eInvoices.fetchEInvoiceStatus('ws-1');
    expect(status.configured, isTrue);
    expect(status.fields.values.join(), isNot(contains('http://')));
  });

  test(
    'an invoice is sent with its receipt, and the uncertain one settles',
    () async {
      expect(await eInvoiceJourney(), isTrue);
    },
  );

  test(
    'the Demo opens with one delivered and one uncertain submission',
    () async {
      final f = DemoFixture.build();
      final all = await f.money.eInvoices.fetchInvoiceTransmissions('ws-1');
      expect(
        all['demo-invoice-ada']!.status,
        EInvoiceSubmissionStatus.accepted,
      );
      expect(
        all['demo-invoice-chiara']!.status,
        EInvoiceSubmissionStatus.uncertain,
      );
    },
  );
}
