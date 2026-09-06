// SPDX-License-Identifier: 0BSD
//
// #945 — sites: the model, the screen, and the SQL twin.
import 'dart:io';

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
  });

  test('the SQL twin (0168): a default site per workspace, the default '
      'cannot be deleted, deleting a site falls back to the default', () {
    final sql = File('supabase/migrations/0168_sites.sql').readAsStringSync();
    expect(sql, contains('sites_one_default_per_workspace'));
    expect(sql, contains("raise exception 'the default site cannot be deleted'"));
    expect(sql, contains('update public.levels set site_id = null where site_id = p_site_id'));
    expect(sql, contains('update public.members set home_site_id = null where home_site_id = p_site_id'));
    expect("raise exception 'admins only'".allMatches(sql).length, 4);
    expect(sql, contains('where not exists (select 1 from public.sites s where s.workspace_id = w.id and s.is_default)'));
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
