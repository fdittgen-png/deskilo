// SPDX-License-Identifier: 0BSD
//
// #869 — the geometry test pins the numbers; this one proves the
// RENDERED sheet honours them. It reads the produced PDF back and
// checks the recipient is drawn at the window's page coordinates,
// because every earlier layout bug here was invisible until something
// was printed and folded.
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders one page with the address block placed as the invoice places
/// it, then reports where the text actually landed.
Future<Uint8List> _sheet(AddressWindow window) async {
  // Uncompressed so the test can read the placement transforms.
  final doc = pw.Document(compress: false);
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
        buildBackground: (context) => addressWindowBackground(
          window,
          pageNumber: context.pageNumber,
          child: addressWindowRecipient(
              name: 'SASU KaloA', address: '31670 Labege'),
        ),
      ),
      build: (context) => [pw.Text('body')],
    ),
  );
  return doc.save();
}

void main() {
  const mm = 72 / 25.4;

  test('the sheet is A4 and the address lands inside the window, on the '
      'side the convention asks for', () async {
    for (final window in [AddressWindow.left, AddressWindow.right]) {
      final bytes = await _sheet(window);
      final raw = String.fromCharCodes(bytes);
      expect(raw, contains('/MediaBox'));

      // The pdf package emits the placement as a `1 0 0 1 x y cm`
      // transform. The address is the block whose x matches the window.
      final wanted = window.leftEdge;
      final matches = RegExp(r'1 0 0 1 ([\d.]+) ([\d.]+) cm')
          .allMatches(raw)
          .map((m) =>
              (x: double.parse(m.group(1)!), y: double.parse(m.group(2)!)))
          .where((p) => (p.x - wanted).abs() < 1.0)
          .toList();
      expect(matches, isNotEmpty,
          reason: '${window.name}: nothing drawn at x=${wanted / mm} mm');

      // y is measured from the BOTTOM, so the field's top edge sits at
      // page height minus 45 mm.
      final wantedTop = PdfPageFormat.a4.height - addressWindowTop;
      expect(
        matches.any((p) =>
            p.y <= wantedTop + 1 && p.y >= wantedTop - addressWindowHeight - 1),
        isTrue,
        reason: '${window.name}: drawn outside the 45–90 mm band',
      );
    }
  });

  test('only the first sheet is addressed', () {
    expect(
      addressWindowBackground(AddressWindow.left,
          pageNumber: 2, child: pw.Text('x')),
      isA<pw.SizedBox>(),
    );
  });
}
