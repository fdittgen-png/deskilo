// SPDX-License-Identifier: 0BSD
//
// #1306 S1 — one destination model for the shell.
//
// The bottom bar and the web drawer render ONE list of branches, built from
// the workspace's features by `visibleShellBranches`. For every combination
// of the gating features the list starts with Messages, holds each enabled
// destination exactly once in bar order, never holds the Reserve hub (the
// centre button), and the selected position of every listed branch is its
// own index — the invariant the bar's position↔branch mapping relies on.
import 'dart:io';

import 'package:deskilo/app/shell/shell_destinations.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gating = [
    WorkspaceFeature.calendarTab,
    WorkspaceFeature.membersDirectory,
    WorkspaceFeature.moneyTab,
    WorkspaceFeature.eventsTab,
  ];

  test('every combination of the gating features yields a sound bar', () {
    for (var mask = 0; mask < 1 << gating.length; mask++) {
      final features = {
        for (var i = 0; i < gating.length; i++)
          if (mask & (1 << i) != 0) gating[i],
      };
      final branches = visibleShellBranches(features);
      final label = features.map((f) => f.name).join('+');

      expect(branches.first, ShellBranch.messages, reason: label);
      expect(branches.toSet(), hasLength(branches.length),
          reason: 'duplicate destination under $label');
      expect(branches, isNot(contains(ShellBranch.reserve)), reason: label);
      expect(branches, [
        ShellBranch.messages,
        if (features.contains(WorkspaceFeature.calendarTab)) ShellBranch.calendar,
        if (features.contains(WorkspaceFeature.membersDirectory))
          ShellBranch.directory,
        if (features.contains(WorkspaceFeature.moneyTab)) ShellBranch.money,
      ], reason: label);
      for (var position = 0; position < branches.length; position++) {
        expect(branches.indexOf(branches[position]), position, reason: label);
      }
    }
  });

  test('the branch integers never move — the shell keeps state by index', () {
    expect(
      [
        ShellBranch.messages,
        ShellBranch.calendar,
        ShellBranch.directory,
        ShellBranch.money,
        ShellBranch.reserve,
      ],
      [0, 1, 2, 3, 4],
    );
  });

  test('each destination has one icon, outlined and filled', () {
    for (final branch in [0, 1, 2, 3, 4]) {
      expect(shellBranchIcon(branch), isNot(shellBranchIcon(branch, selected: true)));
    }
  });

  test('the bar and the drawer build no destination list of their own', () {
    // A second hand-written list is how the two drifted apart before.
    for (final path in [
      'lib/app/shell/shell_screen.dart',
      'lib/app/shell/shell_drawer.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('if (features.contains(WorkspaceFeature.calendarTab))')),
          reason: '$path gates a bar destination by hand');
      expect(source, isNot(contains('ShellBranch.plan')), reason: path);
    }
  });
}
