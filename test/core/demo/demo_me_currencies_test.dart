// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances in the Demo reads every space the person is in — the main
// space and Leipzig (euros), London (pounds) and New York (dollars) — and
// never adds one currency to another: the amount to pay is one figure per
// currency, each the sum of that currency's open documents, and every
// document is in its own space's currency.
import 'package:deskilo/core/demo/demo_finances.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a member of four spaces sees euros, pounds and dollars apart', () {
    final fixture = DemoFixture.build()..becomePersona(DemoPersona.member);
    final overview = demoFinanceOverview(fixture);

    expect({for (final i in overview.invoices) i.currency}, {'EUR', 'GBP', 'USD'});
    expect({for (final i in overview.invoices) i.workspaceId}, hasLength(4),
        reason: 'the main space, Leipzig, London and New York');

    final expected = <String, int>{};
    for (final i in overview.outstanding) {
      expected[i.currency] = (expected[i.currency] ?? 0) + i.remainingCents;
    }
    expect(overview.owedByCurrency, expected,
        reason: 'one figure per currency, never a sum across currencies');
    expect(overview.owedByCurrency.keys.toSet(),
        {for (final i in overview.outstanding) i.currency});
  });

  test("every document is in its own space's currency", () {
    final fixture = DemoFixture.build()..becomePersona(DemoPersona.member);
    final currencyOf = {
      for (final w in fixture.workspaces.workspaces) w.id: w.currencyCode,
    };
    for (final i in demoFinanceOverview(fixture).invoices) {
      expect(i.currency, currencyOf[i.workspaceId],
          reason: '${i.number} in ${i.workspaceName}');
    }
  });
}
