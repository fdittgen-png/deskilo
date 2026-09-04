// SPDX-License-Identifier: 0BSD
//
// #875 — the page-true mirror places things where the PDF places them.
//
// The mirror shares the model, the unit resolver and the zone rules
// with the PDF engine, so its geometry is identical by construction —
// but "by construction" is a claim, and this is the check: pump one
// A4 sheet at the PDF's own point size and measure where the recipient
// and the body landed, in points, against the same millimetres the
// PDF harness asserts.
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/features/money/presentation/widgets/report_layout_preview.dart';
import 'package:deskilo/features/money/presentation/widgets/report_page_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _mm = 72 / 25.4;

const _layout = '''
<report-layout margin="20mm">
  <header height="25mm"><text style="heading">{{ workspace }}</text></header>
  <recipient window="fr"/>
  <body y="90mm">
    <text style="subheading">FACTURE {{ number }}</text>
    <image name="logo" h="10mm"/>
    <box x="60%" w="40%"><text>DROITE</text></box>
  </body>
  <footer height="20mm"><text style="small">pied</text></footer>
</report-layout>
''';

final _data = <String, Object?>{
  'workspace': 'COWORKONTI',
  'number': 'INV-2026-0050',
  'member': 'SASU KaloA',
  'client_address': '31670 LABÈGE',
};

/// A 1×1 PNG the engine can decode — hand-rolled bytes fail the codec
/// (memory note), so this is the smallest valid file, byte for byte.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x60, 0x60, 0x00,
  0x00, 0x00, 0x04, 0x00, 0x01, 0x5C, 0xCD, 0xFF, 0x69, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<void> _pump(WidgetTester tester, {Map<String, Uint8List> images = const {}}) async {
  tester.view.physicalSize = const Size(ReportPage.width, ReportPage.height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: LayoutPageView(
          document: renderLayoutDocument(_layout, _data),
          data: _data,
          images: images,
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('the recipient sits at 110 mm across and 45 mm down', (tester) async {
    await _pump(tester);
    final name = tester.getTopLeft(find.text('SASU KaloA'));
    expect(name.dx, closeTo(110 * _mm, 1.0), reason: 'x = 110 mm');
    expect(name.dy, closeTo(45 * _mm, 1.0), reason: 'y = 45 mm');
  });

  testWidgets('the sender starts at the 20 mm margin and the body at 90 mm',
      (tester) async {
    await _pump(tester);
    final sender = tester.getTopLeft(find.text('COWORKONTI'));
    expect(sender.dx, closeTo(20 * _mm, 1.0));
    expect(sender.dy, closeTo(20 * _mm, 1.0));
    final body = tester.getTopLeft(find.text('FACTURE INV-2026-0050'));
    expect(body.dy, greaterThanOrEqualTo(90 * _mm - 0.5), reason: 'body ≥ 90 mm');
    expect(body.dy, lessThan(100 * _mm), reason: 'and not far below it');
  });

  testWidgets('a 60 % box starts 60 % across the content width — 122 mm',
      (tester) async {
    await _pump(tester);
    final box = tester.getTopLeft(find.text('DROITE'));
    expect(box.dx, closeTo(122 * _mm, 1.5));
  });

  testWidgets('the footer is at the bottom of the sheet', (tester) async {
    await _pump(tester);
    final foot = tester.getBottomLeft(find.text('pied'));
    expect(foot.dy, greaterThan(250 * _mm), reason: 'footer near the bottom');
    expect(foot.dy, lessThanOrEqualTo(ReportPage.height - 20 * _mm + 1));
  });

  testWidgets('an image from the library is drawn; an unknown name draws '
      'nothing', (tester) async {
    await _pump(tester);
    expect(find.byType(Image), findsNothing, reason: 'no library → no image');
    await _pump(tester, images: {'logo': _png});
    expect(find.byType(Image), findsOneWidget);
  });
}
