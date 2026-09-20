// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1339, #1582 — the screens hold at a narrow phone, on a wide surface,
// at twice the text size, under Tab traversal and with animation off.
//
// The table this file used to carry is now `matrix.dart`. This file is
// the five layout-and-motion axes of it:
//
//   * narrow / wide / largeText — nothing overflows. A RenderFlex
//     overflow is an exception, and `tester.takeException()` sees one.
//   * keyboard — Tab moves focus to a real, mounted node. A screen
//     where it moves nowhere cannot be operated without a pointer.
//   * reducedMotion — #1582's correction: the screen must reach the
//     SAME FINAL STATE with animation off, not merely fail to throw.
//     The state is the set of screen-reader labels; the gotcha is that
//     `MotionReveal` SKIPS its `AnimatedSize` when motion is off (the
//     framework asserts at `Duration.zero`), so the motion-off path is
//     a different tree and has to be compared, not assumed.
//
// It does NOT re-run `meetsGuideline` here: at 2x text a contrast
// failure is a real defect worth its own issue, and a matrix that fails
// for reasons nobody investigated teaches the next person to ignore it.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'matrix.dart';

/// A phone most members actually hold, and a wide surface.
const _phone = Size(360, 800);
const _tablet = Size(1200, 900);

/// What the screen offers, as a screen reader would read it — labels
/// rather than child counts, because a state that differs only in how
/// many `Padding`s wrap it is not one a member can tell apart.
Set<String> _spoken(WidgetTester tester) {
  final labels = <String>{};
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  for (final view in RendererBinding.instance.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return labels;
}

void main() {
  for (final row in matrixRowsFor(MatrixAxis.narrow)) {
    testWidgets('${row.screen} holds at 360 dp', (tester) async {
      await row.pump!(tester, _phone);
      expect(tester.takeException(), isNull,
          reason: '${row.screen} overflowed at 360 dp — the width most '
              'members hold');
    });
  }

  for (final row in matrixRowsFor(MatrixAxis.wide)) {
    testWidgets('${row.screen} holds on a wide surface', (tester) async {
      await row.pump!(tester, _tablet);
      expect(tester.takeException(), isNull,
          reason: '${row.screen} overflowed at ${_tablet.width} dp');
    });
  }

  for (final row in matrixRowsFor(MatrixAxis.largeText)) {
    testWidgets('${row.screen} holds at twice the text size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await row.pump!(tester, _phone);
      expect(tester.takeException(), isNull,
          reason: '${row.screen} overflowed at 2x text — the accessibility '
              'setting, not an edge case');
    });
  }

  for (final row in matrixRowsFor(MatrixAxis.keyboard)) {
    testWidgets('${row.screen} can be entered from the keyboard',
        (tester) async {
      await row.pump!(tester, _tablet);
      final before = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final after = FocusManager.instance.primaryFocus;

      expect(after, isNotNull);
      expect(after?.context, isNotNull,
          reason: '${row.screen}: Tab left focus on a node with no element');
      expect(after, isNot(before),
          reason: '${row.screen}: Tab moved focus nowhere, so nothing on '
              'this screen can be reached without a pointer');
    });
  }

  for (final row in matrixRowsFor(MatrixAxis.reducedMotion)) {
    testWidgets('${row.screen} reaches the same final state with motion off',
        (tester) async {
      final handle = tester.ensureSemantics();
      await row.pump!(tester, _phone);
      final animated = _spoken(tester);
      expect(animated, isNotEmpty,
          reason: '${row.screen} said nothing a screen reader could read, '
              'so the comparison below would compare two empty sets');

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      // Unmount first: pumping the same root widget again UPDATES the
      // element rather than replacing it, so the app's State — and the
      // router's location with it — would survive into the second pass.
      await tester.pumpWidget(const SizedBox.shrink());
      await row.pump!(tester, _phone);

      expect(tester.takeException(), isNull,
          reason: '${row.screen} failed with animations disabled');
      expect(_spoken(tester), animated,
          reason: '${row.screen} settles on a DIFFERENT state when motion '
              'is off. Reduced motion removes the animation, never the '
              'content — and the motion-off path really is a different '
              'tree, because MotionReveal skips its AnimatedSize rather '
              'than run it at Duration.zero');
      handle.dispose();
    });
  }

  // Everything above asserts an ABSENCE — no exception — and an absence
  // that can never appear is not a test. These two pin the mechanisms
  // the table leans on: a row that cannot fit, and a screen nothing can
  // focus, both have to be caught by the same assertions. They pin the
  // mechanism rather than a screen, deliberately — asserting that some
  // real screen overflows would encode a size nobody supports.
  testWidgets('the matrix can fail: an overflow is caught', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [SizedBox(width: 10000, height: 10)]),
    ));

    expect(tester.takeException(), isNotNull,
        reason: 'a 10000 dp box in a 360 dp row did not register as an '
            'exception, so `takeException` is not seeing overflow and '
            'every assertion in the table above is vacuous');
  });

  testWidgets('the matrix can fail: a screen nothing can focus',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
    final before = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(FocusManager.instance.primaryFocus, before,
        reason: 'Tab moved focus on a screen with nothing focusable, so '
            'the keyboard axis above would pass on any screen at all');
  });
}
