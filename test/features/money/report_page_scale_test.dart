// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3947 — a control drawn on the report page stays a target of the kit's
// size on screen: the page says how much it is shrunk, the control grows by
// as much.
import 'package:deskilo/core/ui/kit/kit_metrics.dart';
import 'package:deskilo/features/money/presentation/widgets/report_page_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<double> _onPage(WidgetTester tester, double? scale) async {
  late double size;
  final probe = Builder(
    builder: (context) {
      size = ReportPageScale.onPage(context, KitMetrics.minTarget);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(
    scale == null ? probe : ReportPageScale(scale: scale, child: probe),
  );
  return size;
}

void main() {
  testWidgets('a page shrunk to three quarters draws its targets larger', (
    tester,
  ) async {
    expect(await _onPage(tester, .75), KitMetrics.minTarget / .75);
    expect(
      await _onPage(tester, .75) * .75,
      greaterThanOrEqualTo(KitMetrics.minTarget),
    );
  });

  testWidgets('a page at full size or enlarged keeps the kit size', (
    tester,
  ) async {
    expect(await _onPage(tester, 1), KitMetrics.minTarget);
    expect(await _onPage(tester, 1.5), KitMetrics.minTarget);
  });

  testWidgets('outside a page the kit size stands', (tester) async {
    expect(await _onPage(tester, null), KitMetrics.minTarget);
  });
}
