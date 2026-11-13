// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances in the Demo reads every space the person is in — the main
// space, Leipzig and Milan (euros), London (pounds), New York (dollars),
// and Zurich (francs) — and
// never adds one currency to another: the amount to pay is one figure per
// currency, and every document is in its own space's currency.
//
// The expected amounts are summed straight from the spaces' money (the
// invoices addressed to the person, less what was matched to them), not from
// the overview under test.
import 'package:deskilo/core/demo/demo_finance_projection.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_owed.dart';

void main() {
  test('a member owes in euros, francs, pounds and dollars, apart', () {
    final fixture = DemoFixture.build()..becomePersona(DemoPersona.member);
    final overview = demoFinanceForUser(fixture.personalSpaces, fixture.auth.currentUserId);

    expect({for (final i in overview.invoices) i.workspaceId}, {
      for (final space in fixture.personalSpaces)
        space.workspaces.myMember.workspaceId,
    });
    expect({for (final i in overview.outstanding) i.currency},
        {'EUR', 'CHF', 'GBP', 'USD'},
        reason: 'open documents in every represented currency');

    final fromTheSpaces = demoOwedFromTheSpaces(fixture);
    expect(fromTheSpaces.keys.toSet(), {'EUR', 'CHF', 'GBP', 'USD'});
    expect(overview.owedByCurrency, fromTheSpaces,
        reason: 'one figure per currency, never a sum across currencies');
  });

  test("every document is in its own space's currency", () {
    final fixture = DemoFixture.build()..becomePersona(DemoPersona.member);
    final currencyOf = {
      for (final w in fixture.workspaces.workspaces) w.id: w.currencyCode,
    };
    for (final i in demoFinanceForUser(fixture.personalSpaces, fixture.auth.currentUserId).invoices) {
      expect(i.currency, currencyOf[i.workspaceId],
          reason: '${i.number} in ${i.workspaceName}');
    }
  });
}
