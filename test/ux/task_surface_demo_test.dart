// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (desk K3) — a real form through the app, on the Demo: the expense
// form opens as a sheet on a phone and as a side panel at the desk, of its
// named width, on the right edge, with the page behind it, and nothing in it
// overflows. With SHEET=1 the whole window is written to
// `build/sheets/task_surface/<width>.png` for the epic's screenshot sheet.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/ui/adaptive/task_surface.dart';
import 'package:deskilo/core/ui/adaptive/window_class.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/demo_journey.dart';
import 'experience_guards.dart';

/// How long, and how often, the test waits out the reads' retries.
const _retryWait = Duration(seconds: 10);
const _retryRounds = 6;

/// Lets the page, a tap and a container's transition run their course: a
/// desk page may keep a progress mark turning, so frames are pumped for a
/// bounded time instead of until nothing moves.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < _settleFrames; i++) {
    await tester.pump(_settleFrame);
  }
}

const _settleFrame = Duration(milliseconds: 100);
const _settleFrames = 20;

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _writeWindow(WidgetTester tester, String name) async {
  if (Platform.environment['SHEET'] != '1') return;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final image = await tester.runAsync(() => layer.toImage(Offset.zero & size));
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final dir = Directory('build/sheets/task_surface')
    ..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  for (final window in const [Size(390, 844), Size(1440, 900)]) {
    testWidgets('the expense form at ${window.width.toInt()} on the Demo', (
      tester,
    ) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final journey = DemoJourney.start();
      addTearDown(journey.dispose);
      await loadSheetFonts();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: journey.root,
          child: const DeskiloRoot(),
        ),
      );
      await tester.pumpAndSettle();
      final app = ProviderScope.containerOf(
        tester.element(find.byType(DeskiloApp)),
      );
      app.read(routerProvider).go('/money/purchases');
      await _settle(tester);
      // The one way in to an outlay; who paid is asked first where the
      // person may also record the space's purchases.
      await tester.tap(_key('purchases-hub-own-expense'));
      await _settle(tester);
      final mine = _key('add-purchase-me');
      if (mine.evaluate().isNotEmpty) {
        await tester.tap(mine);
        await _settle(tester);
      }
      expect(_key('expense-submit'), findsOneWidget);
      await _writeWindow(tester, '${window.width.toInt()}');
      // The fit is judged in the real fonts the sheet is drawn with; the
      // test font's square glyphs are wider than any real text.
      final problem = tester.takeException();
      if (Platform.environment['SHEET'] == '1') {
        expect(problem, isNull, reason: 'nothing overflows');
      }
      if (WindowClass.ofWidth(window.width) == WindowClass.compact) {
        expect(_key('task-sheet'), findsOneWidget);
      } else {
        final panel = _key('task-side-panel');
        expect(panel, findsOneWidget);
        expect(tester.getSize(panel).width, TaskSurfaceMetrics.sidePanelWidth);
        // On the right edge of the area the page's navigator has (the
        // desk's page frame), the page beside it under the scrim. The desk
        // frame confines popup routes (see the desk epic #3625): once the
        // navigator's overlay spans the page area, this is the window edge.
        expect(
          tester.getTopRight(panel).dx,
          tester.getTopRight(find.byType(ModalBarrier).last).dx,
        );
        // A switch of business under the open, changed form: the form goes
        // with its context, unasked.
        await tester.enterText(
          find.descendant(of: panel, matching: find.byType(EditableText)).first,
          '12',
        );
        await tester.pump();
        final active = app.read(activeWorkspaceIdProvider).value;
        final other = journey.fixture.workspaces.workspaces
            .map((w) => w.id)
            .firstWhere((id) => id != active);
        await app.read(activeWorkspaceIdProvider.notifier).select(other);
        await _settle(tester);
        expect(panel, findsNothing);
        expect(_key('unsaved-changes-dialog'), findsNothing);
      }
      // The real time the image took lets reads schedule their retries:
      // they are run out before the test ends.
      for (var i = 0; i < _retryRounds; i++) {
        await tester.pump(_retryWait);
      }
    });
  }
}
