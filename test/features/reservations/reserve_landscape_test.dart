// SPDX-License-Identifier: 0BSD
//
// #1183 — the Reserve hub with the phone held sideways.
//
// The 2316×1080 screenshots showed the split layout reusing the
// portrait measurements: the seat legend was cut mid-word by the panel
// edge ("Free · Reserved · Checked in · M…"), the bottom bar kept the
// 88 dp it takes on a 2316 px-tall portrait screen, and the zoom
// cluster spent 122 dp of a 240 dp canvas on a column of buttons.
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/core/ui/canvas_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reserve_hub_test.dart' show pumpHub;

void main() {
  // The report said the + and − vanished sideways, leaving only the
  // recentre button. That did not reproduce: the canvas is 240 dp tall
  // in the split layout and the 122 dp column fits. What IS true is
  // that a column of three buttons spends half a short canvas's height
  // on chrome, so on a short canvas the cluster lies down instead.
  testWidgets('the zoom cluster lies along the canvas\'s long axis when '
      'the canvas is short', (tester) async {
    await pumpHub(tester, size: const Size(2316, 1080), pixelRatio: 3);

    final rects = [
      for (final key in const [
        'canvas-zoom-in',
        'canvas-zoom-out',
        'canvas-zoom-reset',
      ])
        tester.getRect(find.byKey(ValueKey(key))),
    ];
    expect(rects.map((r) => r.top).toSet(), hasLength(1),
        reason: 'all three share a row');
    final spent = rects.map((r) => r.height).reduce((a, b) => a > b ? a : b);
    final canvas = tester.getRect(find.byType(CanvasControls).first).height;
    expect(spent, lessThan(canvas / 4),
        reason: 'stacked, the cluster took half the height of a 240 dp '
            'canvas');
  });

  testWidgets('the legend wraps instead of being cut mid-word',
      (tester) async {
    await pumpHub(tester, size: const Size(2316, 1080), pixelRatio: 3);
    final legend = find.byKey(const ValueKey('reserve-legend'));
    expect(legend, findsOneWidget);
    final box = tester.getRect(legend);
    for (final label in const ['Free', 'Reserved', 'Mine', 'Blocked']) {
      final text = find.descendant(of: legend, matching: find.text(label));
      expect(text, findsOneWidget, reason: label);
      expect(tester.getRect(text).right, lessThanOrEqualTo(box.right + 1),
          reason: '$label ran past the panel edge — a legend nobody can '
              'read is a legend that is not there');
    }
  });

  testWidgets('the bottom bar gives the short screen its height back',
      (tester) async {
    await pumpHub(tester, size: const Size(2316, 1080), pixelRatio: 3);
    expect(
      tester.getSize(find.byType(ShellBottomBar)).height,
      ShellBarMetrics.barHeightShort + ShellBarMetrics.rise,
    );
  });

  testWidgets('and nothing overflows', (tester) async {
    await pumpHub(tester, size: const Size(2316, 1080), pixelRatio: 3);
    expect(tester.takeException(), isNull);
  });
}
