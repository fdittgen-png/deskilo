// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3798 — on the desk the windows a page opens stand in the page area, not
// in the page's column: the modal barrier covers the page area, a panel at
// the overlay's end edge stands at the window's right edge, and a dialog is
// centred in the page area and no wider than its own maximum. Through the
// app, at 1440 (sidebar) and 1024 (rail), on a framed route (/members, the
// 960 column) and on a work route (/invoices).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/desk_page_frame.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/ui/adaptive/task_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Finder _k(String key) => find.byKey(ValueKey(key));

Future<Rect> _pageArea(
  WidgetTester tester, {
  required Size size,
  required bool rail,
  required String path,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        deskRailCollapsed: InMemoryShellFlagStore(value: rail),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
  await tester.pumpAndSettle();
  return tester.getRect(_k('desk-page'));
}

/// A context inside the page the route shows.
BuildContext _pageContext(WidgetTester tester) => tester.element(
  find.descendant(of: _k('desk-page'), matching: find.byType(Scaffold)).last,
);

void main() {
  for (final (width, height, rail) in [
    (1440.0, 900.0, false),
    (1024.0, 768.0, true),
  ]) {
    for (final path in ['/members', '/invoices']) {
      final at = '$path at ${width.toInt()}${rail ? ' on the rail' : ''}';

      testWidgets('$at: a dialog\'s barrier covers the page area and the '
          'dialog is centred in it, at most its own width', (tester) async {
        final area = await _pageArea(
          tester,
          size: Size(width, height),
          rail: rail,
          path: path,
        );
        // Not awaited: the dialog's future ends when it closes.
        showDialog<void>(
          context: _pageContext(tester),
          builder: (_) => const Dialog(
            key: ValueKey('probe-dialog'),
            child: SizedBox(height: 120, width: double.infinity),
          ),
        ).ignore();
        await tester.pumpAndSettle();
        final barrier = tester.getRect(find.byType(ModalBarrier).last);
        expect(barrier, area, reason: 'the scrim covers the page area');
        // The dialog's card, not the widget around it (its insets).
        final dialog = tester.getRect(
          find
              .descendant(
                of: _k('probe-dialog'),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(dialog.center.dx, closeTo(area.center.dx, 1));
        expect(dialog.width, lessThanOrEqualTo(deskDialogMaxWidth));
      });

      testWidgets('$at: a task\'s side panel (#3608) stands at the '
          'window\'s right edge, its scrim over the page area', (tester) async {
        final area = await _pageArea(
          tester,
          size: Size(width, height),
          rail: rail,
          path: path,
        );
        showTask<void>(
          _pageContext(tester),
          size: TaskSize.standard,
          builder: (_) => const SizedBox.expand(key: ValueKey('probe-task')),
        ).ignore();
        await tester.pumpAndSettle();
        final panel = tester.getRect(
          find
              .ancestor(of: _k('probe-task'), matching: find.byType(Material))
              .first,
        );
        expect(panel.right, width, reason: 'the panel is at the window edge');
        expect(tester.getRect(find.byType(ModalBarrier).last), area);
      });

      testWidgets('$at: a panel at the overlay\'s end stands at the '
          'window\'s right edge', (tester) async {
        await _pageArea(
          tester,
          size: Size(width, height),
          rail: rail,
          path: path,
        );
        showGeneralDialog<void>(
          context: _pageContext(tester),
          barrierDismissible: true,
          barrierLabel: 'close',
          pageBuilder: (_, _, _) => const Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(
              key: ValueKey('probe-panel'),
              width: 400,
              height: double.infinity,
            ),
          ),
        ).ignore();
        await tester.pumpAndSettle();
        expect(tester.getRect(_k('probe-panel')).right, width);
      });
    }
  }
}
