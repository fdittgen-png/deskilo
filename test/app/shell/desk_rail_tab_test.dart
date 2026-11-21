// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4279 -- the desk's rail keeps every control built, so Tab walks it once and
// comes back to where it began, however many groups it holds. A lazy list
// disposed its first items once Tab had walked past its cache, and a disposed
// focus stop is no longer the one the cycle returns to: an extra menu group made
// Tab reach controls twice on other pages. Here the rail holds many groups of
// four entries (far more than one screen) and Tab walks it in one cycle.
import 'package:deskilo/app/shell/desk_rail.dart';
import 'package:deskilo/app/shell/shell_drawer_entries.dart';
import 'package:deskilo/app/shell/shell_nav_groups.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('Tab walks a rail of many groups once and returns to its first stop', (tester) async {
    DrawerEntry entry(String key) => DrawerEntry(key, Icons.circle, key, () {});
    final groups = [
      for (var g = 0; g < 24; g++)
        NavGroup('group-$g', 'Group $g', Icons.folder_outlined, [for (var i = 0; i < 4; i++) entry('g$g-e$i')]),
    ];
    await pumpApp(
      tester,
      DeskRail(
        destinations: [entry('home')],
        groups: groups,
        account: [entry('account')],
        path: '/reserve',
        badgeOf: (_) => 0,
        onBackToMe: () {},
      ),
      size: const Size(1024, 360),
    );

    final seen = <FocusNode>[];
    for (var i = 0; i < 400; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final now = FocusManager.instance.primaryFocus;
      if (now == null) continue;
      if (seen.isNotEmpty && now == seen.first) break;
      expect(seen.contains(now), isFalse, reason: 'a stop was reached twice at step $i');
      seen.add(now);
    }

    expect(seen, isNotEmpty);
    expect(seen.every((n) => n.context != null), isTrue, reason: 'no stop was disposed on the way');
    expect(FocusManager.instance.primaryFocus, seen.first, reason: 'the cycle comes back to its first stop');
  });
}
