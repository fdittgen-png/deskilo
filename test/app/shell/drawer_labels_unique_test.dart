// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3071 — one name per thing in the navigation: with every feature and
// every right, no two drawer entries share a label, and no two entries open
// the same route.
import 'package:deskilo/app/shell/shell_drawer_entries.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final accountMenu in [false, true]) {
    testWidgets('no two drawer entries share a label or a route '
        '(accountMenu: $accountMenu)', (tester) async {
      late DrawerEntries entries;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            entries = DrawerEntries(
              context: context,
              features: WorkspaceFeature.values.toSet(),
              permissions: WorkspacePermission.values.toSet(),
              accountMenu: accountMenu,
              permanent: true,
              visibleBranches: const [0, 1, 2, 3, 4],
              tabTitles: const ['a', 'b', 'c', 'd', 'e'],
              currentIndex: 0,
              onBranch: (_) {},
              go: (_, {bool push = false}) {},
              setupOpen: true,
            );
            return const SizedBox();
          },
        ),
      );
      final all = [
        ...entries.money(),
        ...entries.accounting(),
        ...entries.setupGuide(),
        ...entries.administration(),
        ...entries.reporting(
          sections: const [
            'finance',
            'operations',
            'templates',
            'bi',
            'documents',
          ],
          onSection: (_) => false,
        ),
        ...entries.account(),
      ];
      final byLabel = <String, List<String>>{};
      final byRoute = <String, List<String>>{};
      for (final e in all) {
        byLabel.putIfAbsent(e.label, () => []).add(e.key);
        if (e.route != null) byRoute.putIfAbsent(e.route!, () => []).add(e.key);
      }
      expect(
        {
          for (final e in byLabel.entries)
            if (e.value.length > 1) e.key: e.value,
        },
        isEmpty,
        reason: 'two entries with one label',
      );
      expect(
        {
          for (final e in byRoute.entries)
            if (e.value.length > 1) e.key: e.value,
        },
        isEmpty,
        reason: 'two entries to one route',
      );
    });
  }
}
