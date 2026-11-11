// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3602 (desk F1) — the window's size class is defined once: 600 / 840 /
// 1200 / 1600 logical pixels. It is read from the window (its physical size
// over its pixel ratio), so the app's reading frame does not change it.
import 'package:deskilo/core/ui/adaptive/window_class.dart';
import 'package:deskilo/core/ui/app_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each bound belongs to the class it opens', () {
    expect(WindowClass.ofWidth(599), WindowClass.compact);
    expect(WindowClass.ofWidth(600), WindowClass.medium);
    expect(WindowClass.ofWidth(839), WindowClass.medium);
    expect(WindowClass.ofWidth(840), WindowClass.expanded);
    expect(WindowClass.ofWidth(1199), WindowClass.expanded);
    expect(WindowClass.ofWidth(1200), WindowClass.large);
    expect(WindowClass.ofWidth(1599), WindowClass.large);
    expect(WindowClass.ofWidth(1600), WindowClass.extraLarge);
    expect(WindowClass.expanded.atLeast(WindowClass.medium), isTrue);
    expect(WindowClass.medium.atLeast(WindowClass.expanded), isFalse);
  });

  Future<WindowClass> classIn(
    WidgetTester tester, {
    required Size physical,
    required double ratio,
    bool framed = false,
  }) async {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    late WindowClass seen;
    final probe = Builder(
      builder: (context) {
        seen = WindowClass.of(context);
        return const SizedBox();
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: framed ? AppFrame(maxWidth: 400, child: probe) : probe),
    );
    return seen;
  }

  testWidgets('the window is measured in logical pixels', (tester) async {
    expect(
      await classIn(tester, physical: const Size(1680, 2000), ratio: 2),
      WindowClass.expanded,
      reason: '1680 physical pixels at ratio 2 are 840 logical',
    );
    expect(
      await classIn(tester, physical: const Size(1678, 2000), ratio: 2),
      WindowClass.medium,
    );
  });

  testWidgets('the reading frame does not change the window class', (
    tester,
  ) async {
    expect(
      await classIn(
        tester,
        physical: const Size(1440, 900),
        ratio: 1,
        framed: true,
      ),
      WindowClass.large,
    );
  });
}
