// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #974 — the profiles list names the home site on a multi-site
// workspace and lets the person switch it; a single site is no line.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../me/me_app.dart' show tapIn;

Future<FakeWorkspaceRepository> _pump(WidgetTester tester,
    {required int sites}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] = workspace.workspaces[0]
      .copyWith(featureFlags: const {'multiSite': true});
  workspace.sites.addAll([
    const Site(id: 'site-a', workspaceId: 'ws-1', name: 'Pézenas', isDefault: true),
    if (sites > 1)
      const Site(id: 'site-b', workspaceId: 'ws-1', name: 'Béziers'),
  ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Back to Me'));
  await tester.pumpAndSettle();
  // The list is longer and lazy: scroll to the link, then tap it.
  await tapIn(tester, 'me-home-list', find.byKey(const ValueKey('me-home-manage')));
  return workspace;
}

void main() {
  testWidgets('two sites: the profile names the home site and a tap '
      'switches it through the repository', (tester) async {
    final workspace = await _pump(tester, sites: 2);
    final chip = find.byKey(const ValueKey('profile-site-ws-1'));
    expect(chip, findsOneWidget);
    expect(find.text('Site: Pézenas'), findsOneWidget,
        reason: 'no home site chosen = the default site');

    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-site-site-b')));
    await tester.pumpAndSettle();
    expect(workspace.homeSites['member-1'], 'site-b');
  });

  testWidgets('one site: no line at all', (tester) async {
    await _pump(tester, sites: 1);
    expect(find.byKey(const ValueKey('profile-site-ws-1')), findsNothing);
  });
}
