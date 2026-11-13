// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 — a money tool's tile asks what its route asks: the tile reads
// MoneyToolRights, the route its set in route_access.dart, and the two stay
// equal. (The status's server function, `workspace_status`, asks viewFinances;
// the committed contract keeps only its body's digest, so the server side is
// not pinned here.)
import 'package:deskilo/app/route_access.dart';
import 'package:deskilo/features/money/domain/money_tool_rights.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> _route(String path) => {
  for (final p in routePermissions[path]!) p.wireName,
};

void main() {
  test('the status, the repartition wizard and the suppliers ask at their '
      'route what their tile asks', () {
    expect(_route('/money/status'), MoneyToolRights.status);
    expect(
      _route('/money/repartition-wizard'),
      MoneyToolRights.repartitionWizard,
    );
    expect(_route('/money/suppliers'), MoneyToolRights.suppliers);
  });

  test('the status asks what its server function asks: the right to see the '
      'finances, nothing a member holds for their own money', () {
    expect(MoneyToolRights.status, {'viewFinances'});
  });
}
