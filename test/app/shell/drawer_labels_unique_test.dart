// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3071 (review of #3063) -- no two drawer entries share a label. The
// pricing screen is "Pricing & packages", the invoice pipeline "Invoicing";
// two doors with one name send a newcomer to the wrong one.
import 'package:deskilo/app/shell/shell_drawer_entries.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('every drawer entry an owner with every feature sees has a '
      'label of its own', (tester) async {
    late List<DrawerEntry> entries;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          final d = DrawerEntries(
            context: context,
            features: WorkspaceFeature.values.toSet(),
            permissions: WorkspacePermission.values.toSet(),
            accountMenu: false,
            permanent: false,
            visibleBranches: const [],
            tabTitles: const [],
            currentIndex: 0,
            onBranch: (_) {},
            go: (_, {push = false}) {},
          );
          entries = [
            ...d.navigation(),
            ...d.money(),
            ...d.accounting(),
            ...d.administration(),
            ...d.reporting(
              sections: const ['finance', 'documents', 'overview', 'bi'],
              onSection: (_) => true,
            ),
          ];
          return const SizedBox();
        },
      ),
    );
    final byLabel = <String, List<String>>{};
    for (final e in entries) {
      (byLabel[e.label] ??= []).add(e.key);
    }
    final shared = {
      for (final MapEntry(:key, :value) in byLabel.entries)
        if (value.length > 1) key: value,
    };
    expect(shared, isEmpty, reason: 'one name per door: $shared');
    expect(
      entries.map((e) => e.key).toSet().length,
      entries.length,
      reason: 'one key per door',
    );
  });
}
