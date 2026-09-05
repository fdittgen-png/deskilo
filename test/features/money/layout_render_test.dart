// SPDX-License-Identifier: 0BSD
//
// #875 — a layout prints where it says.
//
// The whole point of the positioned engine is that `x="110mm" y="45mm"`
// lands at 110/45 on the sheet. So this does not inspect widgets: it
// renders a real PDF and reads the ink back in millimetres with the
// same harness the window-envelope spec is measured with. The Liquid
// pass is checked here too, because the one way a layout can break on
// real data — an ampersand in a member's name — happens before any
// geometry exists.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_model.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_units.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/pdf_geometry.dart';

pw.Font _ttf(String path) =>
    pw.Font.ttf(ByteData.sublistView(File(path).readAsBytesSync()));

const _layout = '''
<report-layout margin="20mm">
  <header height="25mm">
    <text style="heading">{{ workspace }}</text>
    <text style="small">{{ workspace_address }}</text>
  </header>
  <continuation height="8mm">
    <text style="small">{{ workspace }} · {{ number }}</text>
  </continuation>
  <recipient window="fr"/>
  <body y="90mm">
    <text style="subheading">FACTURE {{ number }}</text>
    <table>
      <col w="60%"/><col w="40%" align="right"/>
      {% for line in lines %}<row><cell>{{ line.label }}</cell><cell>{{ line.amount }}</cell></row>
      {% endfor %}
    </table>
    {% if iban != "" %}<text>IBAN {{ iban }}</text>{% endif %}
  </body>
  <footer height="20mm">
    <text style="small">{{ workspace }} — pied fixe</text>
  </footer>
</report-layout>
''';

Map<String, Object?> _data({int lines = 1}) => {
      'workspace': 'COWORKONTI',
      'workspace_address': '4 avenue de Castelnau, 34120 Pézenas',
      'number': 'INV-2026-0050',
      'member': 'Smith & Sons <SASU>',
      'client_address': '209 rue Jean Bart\n31670 LABÈGE',
      'lines': [
        for (var i = 0; i < lines; i++)
          {'label': 'Participation 100 % — $i', 'amount': '100,00 €'},
      ],
    };

Future<Uint8List> _pdf({int lines = 1}) => buildLayoutPdf(
      document: renderLayoutDocument(_layout, _data(lines: lines)),
      data: _data(lines: lines),
      documentTitle: 'test',
      pageLabel: 'Page',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );

void main() {
  group('the Liquid pass', () {
    test('escapes data so an ampersand cannot break the XML', () {
      final d = renderLayoutDocument(
          '<report-layout><body><text>{{ member }}</text></body></report-layout>',
          {'member': 'Smith & Sons <SASU>'});
      expect((d.body.children.single as LayoutText).text,
          'Smith & Sons <SASU>',
          reason: 'escaped on the way in, decoded by the parser');
    });

    test('an absent placeholder is empty, so a guarded element vanishes',
        () {
      final d = renderLayoutDocument(
          '<report-layout><body>{% if iban != "" %}<text>IBAN</text>{% endif %}'
          '</body></report-layout>',
          const {});
      expect(d.body.children, isEmpty);
    });

    test('a loop produces one row per line', () {
      final d = renderLayoutDocument(_layout, _data(lines: 3));
      final table = d.body.children[1] as LayoutTable;
      expect(table.rows, hasLength(3));
      expect(table.rows[2].cells[0].text, 'Participation 100 % — 2');
    });

    test('a Liquid error is a LayoutError.liquid, not a crash', () {
      expect(
        () => renderLayoutDocument(
            '<report-layout>{% for %}</report-layout>', const {}),
        throwsA(isA<LayoutException>()
            .having((e) => e.error, 'error', LayoutError.liquid)),
      );
    });
  });

  group('the sheet', () {
    test('the recipient lands in the 85 × 40 mm aperture at 110/45', () async {
      final bytes = await _pdf();
      saveForInspection(bytes, 'layout-invoice.pdf');
      final page1 = textPositions(bytes).where((i) => i.page == 1);
      final inField = page1
          .where((i) => i.xMm >= 100 && i.yMm >= 40 && i.yMm <= 90)
          .toList();
      expect(inField, isNotEmpty, reason: 'no recipient in the window');
      for (final i in inField) {
        expect(i.xMm, greaterThanOrEqualTo(110 - 0.5), reason: '$i');
        expect(i.xMm, lessThanOrEqualTo(195), reason: '$i');
        expect(i.yMm, greaterThanOrEqualTo(44.5), reason: '$i');
        expect(i.yMm, lessThanOrEqualTo(85), reason: '$i');
      }
      expect(
        addressFieldPages(bytes,
            leftEdgePt: AddressWindow.right.leftEdge,
            topPt: addressWindowTop,
            heightPt: addressWindowHeight),
        [1],
      );
    });

    test('the sender starts at the 20 mm margin and the body at 90 mm',
        () async {
      final bytes = await _pdf();
      final page1 = textPositions(bytes).where((i) => i.page == 1).toList();
      final leftMost = page1.map((i) => i.xMm).reduce((a, b) => a < b ? a : b);
      final topMost = page1.map((i) => i.yMm).reduce((a, b) => a < b ? a : b);
      expect(leftMost, greaterThanOrEqualTo(19.5));
      expect(leftMost, lessThan(24));
      expect(topMost, greaterThanOrEqualTo(19.5));
      expect(topMost, lessThan(30));
      // Nothing of the flow may sit in the window band.
      final intruders =
          page1.where((i) => i.xMm < 100 && i.yMm > 45 && i.yMm < 89.5);
      expect(intruders, isEmpty, reason: '$intruders');
      // And the first body ink is at or under 90 mm.
      final body = page1.where((i) => i.xMm < 100 && i.yMm >= 89.5);
      expect(body, isNotEmpty);
    });

    test('the footer is fixed on every page; page 2 has the strip, not '
        'the letterhead', () async {
      final bytes = await _pdf(lines: 70);
      final ink = textPositions(bytes);
      final pages = ink.map((i) => i.page).toSet();
      expect(pages.length, greaterThan(1));
      for (final page in pages) {
        final bottom = ink
            .where((i) => i.page == page)
            .map((i) => i.yMm)
            .reduce((a, b) => a > b ? a : b);
        expect(bottom, greaterThan(240), reason: 'page $page has no footer');
      }
      final page2Top = ink
          .where((i) => i.page == 2)
          .map((i) => i.yMm)
          .reduce((a, b) => a < b ? a : b);
      expect(page2Top, lessThan(45),
          reason: 'page 2 must not reserve the letterhead band');
    });

    test('a percentage width resolves against the parent, so a 60 % box '
        'starts 60 % across', () async {
      const layout = '''
<report-layout margin="20mm">
  <body>
    <box x="60%" w="40%"><text>DROITE</text></box>
  </body>
</report-layout>''';
      final bytes = await buildLayoutPdf(
        document: renderLayoutDocument(layout, const {}),
        data: const {},
        documentTitle: 't',
        pageLabel: 'Page',
        baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
        boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
      );
      final ink = textPositions(bytes).where((i) => i.page == 1).toList();
      // 20 mm margin + 60 % of the 170 mm content width = 122 mm.
      final text = ink.where((i) => i.yMm < 240).toList();
      expect(text, isNotEmpty);
      expect(text.first.xMm, closeTo(122, 1.0));
    });
  });

  group('zones that outgrow their box', () {
    test('a footer taller than its declared height still prints — it grows, '
        'it never vanishes', () async {
      const layout = '''
<report-layout margin="20mm">
  <body><text>corps</text></body>
  <footer height="10mm">
    <text style="small">L1</text><text style="small">L2</text><text style="small">L3</text>
    <text style="small">L4</text><text style="small">L5</text><text style="small">L6</text>
    <text style="small">L7</text><text style="small">L8</text><text style="small">L9</text>
  </footer>
</report-layout>''';
      final bytes = await buildLayoutPdf(
        document: renderLayoutDocument(layout, const {}),
        data: const {},
        documentTitle: 't',
        pageLabel: 'Page',
        baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
        boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
      );
      final ink = textPositions(bytes).where((i) => i.page == 1);
      // Nine lines at 8 pt need ~ 30 mm; the box said 10. The footer must
      // be there anyway: ink on the LEFT above the page number's line.
      final footer = ink.where((i) => i.yMm > 235 && i.xMm < 150).toList();
      expect(footer.length, greaterThanOrEqualTo(9),
          reason: 'the footer was dropped instead of grown');
    });

    test('a letterhead taller than 25 mm is clipped above the window — '
        'nothing leaks into the 45–90 mm band', () async {
      const layout = '''
<report-layout margin="20mm">
  <header height="25mm">
    <text style="heading">Un</text><text style="heading">Deux</text>
    <text style="heading">Trois</text><text style="heading">Quatre</text>
    <text style="heading">Cinq</text><text style="heading">Six</text>
  </header>
  <recipient window="fr"/>
  <body y="90mm"><text>corps</text></body>
</report-layout>''';
      final bytes = await buildLayoutPdf(
        document: renderLayoutDocument(layout, {'member': 'X', 'client_address': ''}),
        data: const {'member': 'X', 'client_address': ''},
        documentTitle: 't',
        pageLabel: 'Page',
        baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
        boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
      );
      final ink = textPositions(bytes).where((i) => i.page == 1);
      final leak = ink.where((i) => i.xMm < 100 && i.yMm > 45.5 && i.yMm < 89.5);
      expect(leak, isEmpty, reason: 'letterhead overflow reached the window band: $leak');
    });
  });
}
