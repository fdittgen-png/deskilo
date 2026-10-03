// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #945 — sites: the model and the screen.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  test('a site reads its row and prints its postal block', () {
    final s = Site.fromRow({
      'id': 's1', 'workspace_id': 'ws-1', 'name': 'Annexe Agde',
      'street': '12 quai du Port', 'postal_code': '34300', 'city': 'Agde',
      'country_code': 'FR', 'legal_id': '10825191900024', 'is_default': false, 'sort_order': 1,
    });
    expect(s.postalBlock, '12 quai du Port\n34300 AGDE');
    expect(s.hasAddress, isTrue);
    expect(Site.fromRow(const {'id': 'x'}).hasAddress, isFalse);
    // #948 — a distinct legal entity's own numbers ride on the site.
    final entity = Site.fromRow({'id': 'e', 'vat_id': 'FR12901234567', 'tax_exemption_reason': 'art. 293 B'});
    expect((entity.vatId, entity.taxExemptionReason), ('FR12901234567', 'art. 293 B'));
    expect(entity.copyWith(vatId: '').vatId, '');
  });

  testWidgets('the Sites screen lists the default site, adds one through '
      'the sheet, and assigns a level to it', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: {'multiSite': true},
    )..sites.add(const Site(id: 'default', workspaceId: 'ws-1', name: 'Test Space', street: '1 rue du Test', city: 'Pézenas', isDefault: true));
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('settings-sites'));
    await tester.scrollUntilVisible(tile, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('site-default')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sites-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('site-name')), 'Annexe Agde');
    await tester.enterText(find.byKey(const ValueKey('site-street')), '12 quai du Port');
    await tester.enterText(find.byKey(const ValueKey('site-city')), 'Agde');
    await tester.tap(find.byKey(const ValueKey('site-save')));
    await tester.pumpAndSettle();
    expect(workspace.siteWrites, ['new:Annexe Agde']);
    expect(find.text('Annexe Agde'), findsOneWidget);
  });
}
