// SPDX-License-Identifier: 0BSD
//
// #1216 — the level canvas asked its user to hold six tools in their
// head, on a row that showed four.
//
// The two that fell off the end were Select, the tool the editor rests
// in, and Office, the one a new floor needs first. Select is not a tool
// now — it is what the canvas does when nothing is armed — and Erase is
// not a tool either, because a destructive MODE deletes whatever your
// finger lands on next rather than a thing you chose and can see.
import 'package:deskilo/features/editor/presentation/screens/editor_tool.dart';
import 'package:deskilo/features/editor/presentation/widgets/editor_selection_bar.dart';
import 'package:deskilo/features/editor/presentation/widgets/editor_toolbar.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import 'level_canvas_test.dart' show cellCenter, pumpCanvas, seedOffice;

Finder get _toolbar => find.byType(EditorToolbar);
Finder get _selectionBar => find.byType(EditorSelectionBar);

Finder tool(EditorTool t) => find.byKey(ValueKey('editor-tool-${t.name}'));

FloorPlanPainter painterOf(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const ValueKey('level-canvas')))
        .painter! as FloorPlanPainter;

Future<void> seedDesk(FakeFloorPlanRepository plans, String levelId) async {
  await seedOffice(plans, levelId);
  await plans.createDesk(
    workspaceId: 'ws-1',
    officeId: plans.offices.single.id,
    name: 'Table 1',
    // Wide enough for TWO seats: a seat's footprint is 6 × 4, and a
    // 6-wide desk holds exactly one (and a 12-wide one holds two only
    // if the first lands on the very first cell), which is a correct
    // refusal to
    // duplicate onto and a poor fixture for testing that it can.
    rect: const GridRect(x: 4, y: 4, w: 18, h: 4),
  );
}

void main() {
  group('the toolbar', () {
    testWidgets('shows every tool it has, on a phone', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpCanvas(tester);

      for (final t in EditorTool.values) {
        expect(tool(t), findsOneWidget, reason: t.name);
      }
      // The row that replaced six segments fits four, and the canvas
      // rests without a tool rather than spending one on "Select".
      expect(EditorTool.values, hasLength(4));
    });

    testWidgets('a second tap on the armed tool puts the canvas back to '
        'selecting — the way out is the button that got you in',
        (tester) async {
      await pumpCanvas(tester);
      expect(tester.widget<EditorToolbar>(_toolbar).armed, isNull);

      await tester.tap(tool(EditorTool.desk));
      await tester.pumpAndSettle();
      expect(tester.widget<EditorToolbar>(_toolbar).armed, EditorTool.desk);

      await tester.tap(tool(EditorTool.desk));
      await tester.pumpAndSettle();
      expect(tester.widget<EditorToolbar>(_toolbar).armed, isNull);
    });

    testWidgets('an armed tool says what the next gesture does, and offers '
        'the way out', (tester) async {
      await pumpCanvas(tester);
      expect(find.byKey(const ValueKey('editor-tool-hint')), findsNothing);

      await tester.tap(tool(EditorTool.seat));
      await tester.pumpAndSettle();
      expect(find.text('Tap a desk to add a seat'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('editor-tool-hint-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor-tool-hint')), findsNothing);
      expect(tester.widget<EditorToolbar>(_toolbar).armed, isNull);
    });
  });

  group('the rules are shown, not only enforced', () {
    testWidgets('arming Desk lights the offices a desk may go in',
        (tester) async {
      final plans = await pumpCanvas(tester, seed: seedOffice);
      expect(painterOf(tester).dropTargets, isNull,
          reason: 'nothing armed dims nothing');

      await tester.tap(tool(EditorTool.desk));
      await tester.pumpAndSettle();

      expect(painterOf(tester).dropTargets, {plans.offices.single.id},
          reason: '"Must be fully inside an office." used to arrive AFTER '
              'a failed drag');
    });

    testWidgets('arming Seat lights the desks instead', (tester) async {
      final plans = await pumpCanvas(tester, seed: seedDesk);

      await tester.tap(tool(EditorTool.seat));
      await tester.pumpAndSettle();

      expect(painterOf(tester).dropTargets, {plans.desks.single.id});
    });

    testWidgets('an empty floor dims entirely rather than staying silent',
        (tester) async {
      await pumpCanvas(tester);

      await tester.tap(tool(EditorTool.desk));
      await tester.pumpAndSettle();

      expect(painterOf(tester).dropTargets, isEmpty,
          reason: 'a tool is armed and there is nowhere legal to put it — '
              'empty is an answer, null is "no tool armed"');
    });

    testWidgets('the office tool dims nothing, because nothing is illegal',
        (tester) async {
      await pumpCanvas(tester, seed: seedOffice);

      await tester.tap(tool(EditorTool.office));
      await tester.pumpAndSettle();

      expect(painterOf(tester).dropTargets, isNull);
    });
  });

  group('the selection', () {
    testWidgets('raises a bar naming what it acts on', (tester) async {
      await pumpCanvas(tester, seed: seedDesk);
      expect(_selectionBar, findsNothing);
      expect(_toolbar, findsOneWidget);

      await tester.tapAt(cellCenter(tester, 5, 5));
      await tester.pumpAndSettle();

      expect(_selectionBar, findsOneWidget);
      expect(_toolbar, findsNothing,
          reason: 'there is nothing to ADD to a selection, so the two bars '
              'never share the row');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('editor-selection-name')))
            .data,
        'Table 1',
      );
    });

    testWidgets('dismisses back to the tools', (tester) async {
      await pumpCanvas(tester, seed: seedDesk);
      await tester.tapAt(cellCenter(tester, 5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('editor-selection-dismiss')));
      await tester.pumpAndSettle();
      expect(_toolbar, findsOneWidget);
    });

    testWidgets('a cancelled delete leaves the element alone', (tester) async {
      final plans = await pumpCanvas(tester, seed: seedDesk);
      await tester.tapAt(cellCenter(tester, 5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('editor-selection-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(plans.desks, hasLength(1));
    });

    testWidgets('only a seat offers Duplicate — it is the repetitive one',
        (tester) async {
      final plans = await pumpCanvas(tester, seed: seedDesk);
      await tester.tapAt(cellCenter(tester, 5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor-selection-duplicate')),
          findsNothing,
          reason: 'a desk is drawn where you want it, not copied');

      // Put a seat on the desk, then rest and select it.
      await tester.tap(find.byKey(const ValueKey('editor-selection-dismiss')));
      await tester.pumpAndSettle();
      await tester.tap(tool(EditorTool.seat));
      await tester.pumpAndSettle();
      await tester.tapAt(cellCenter(tester, 5, 5));
      await tester.pumpAndSettle();
      expect(plans.seats, hasLength(1));

      // Disarm, then tap the seat to select it.
      await tester.tap(tool(EditorTool.seat));
      await tester.pumpAndSettle();
      await tester.tapAt(cellCenter(tester, 5, 5));
      await tester.pumpAndSettle();

      final duplicate =
          find.byKey(const ValueKey('editor-selection-duplicate'));
      expect(duplicate, findsOneWidget);

      await tester.tap(duplicate);
      await tester.pumpAndSettle();
      expect(plans.seats, hasLength(2),
          reason: 'a six-seat table is six identical placements; the copy '
              'lands on the first free cell of the same desk');
    });
  });

  testWidgets('an empty floor says what to do first, and the button arms '
      'the tool that does it', (tester) async {
    await pumpCanvas(tester);
    final card = find.byKey(const ValueKey('editor-empty-floor'));
    expect(card, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-empty-floor-start')));
    await tester.pumpAndSettle();

    expect(tester.widget<EditorToolbar>(_toolbar).armed, EditorTool.office);
    expect(card, findsNothing, reason: 'the card steps aside once you start');
  });
}
