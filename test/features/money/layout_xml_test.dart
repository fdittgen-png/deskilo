// SPDX-License-Identifier: 0BSD
//
// #875 — the layout vocabulary, read and written.
//
// A design is a file a person edits. So the units it accepts, the
// exact inverse of reading and writing, and the error it gives for a
// mistake are the contract — pinned here, element by element, before
// any of it reaches paper.
import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_model.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_units.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_xml.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lengths', () {
    test('every unit parses, and a bare number is millimetres', () {
      expect(Length.parse('12mm'), const Length(12, LengthUnit.mm));
      expect(Length.parse('2.5cm'), const Length(2.5, LengthUnit.cm));
      expect(Length.parse('40px'), const Length(40, LengthUnit.px));
      expect(Length.parse('10pt'), const Length(10, LengthUnit.pt));
      expect(Length.parse('30%'), const Length(30, LengthUnit.percent));
      expect(Length.parse(' 12 '), const Length(12, LengthUnit.mm),
          reason: 'the envelope spec is written in mm; so is a ruler');
      expect(Length.parse('-5mm').value, -5);
    });

    test('resolution is exact: mm and cm by 72/25.4, px is the CSS pixel, '
        '% is of the parent', () {
      const mm = 72 / 25.4;
      expect(Length.parse('45mm').resolve(0), closeTo(45 * mm, 1e-9));
      expect(Length.parse('4.5cm').resolve(0), closeTo(45 * mm, 1e-9));
      expect(Length.parse('96px').resolve(0), closeTo(72, 1e-9),
          reason: '96 CSS px is one inch');
      expect(Length.parse('10pt').resolve(999), 10);
      expect(Length.parse('50%').resolve(400), 200);
      expect(Length.parse('50%').isRelative, isTrue);
      expect(Length.parse('50mm').isRelative, isFalse);
    });

    test('an unknown unit or a missing number is a named error', () {
      expect(
        () => Length.parse('12in', attribute: 'text/@x'),
        throwsA(isA<LayoutException>()
            .having((e) => e.error, 'error', LayoutError.badUnit)
            .having((e) => e.detail, 'detail', contains('text/@x'))),
      );
      expect(() => Length.parse('mm'), throwsA(isA<LayoutException>()));
      expect(() => Length.parse(''), throwsA(isA<LayoutException>()));
      expect(Length.tryParse(null), isNull);
      expect(Length.tryParse('  '), isNull);
    });

    test('toString is the canonical spelling and survives a round trip', () {
      for (final raw in ['12mm', '2.5cm', '40px', '10pt', '30%']) {
        expect(Length.parse(raw).toString(), raw);
        expect(Length.parse(Length.parse(raw).toString()), Length.parse(raw));
      }
      // A bare number comes back explicit, so the file says what it means.
      expect(Length.parse('12').toString(), '12mm');
    });

    test('a frame flows unless it has x or y', () {
      expect(LayoutFrame.flow.isPositioned, isFalse);
      expect(const LayoutFrame(w: Length(1, LengthUnit.mm)).isPositioned,
          isFalse);
      expect(const LayoutFrame(x: Length(1, LengthUnit.mm)).isPositioned,
          isTrue);
      expect(const LayoutFrame(y: Length(1, LengthUnit.mm)).isPositioned,
          isTrue);
    });
  });

  group('reading', () {
    const full = '''
<report-layout version="1" page="A4" margin="20mm">
  <header height="25mm">
    <image name="logo" x="0" y="0" h="14mm" fit="cover" align="right"/>
    <text x="0" y="16mm" style="heading">COWORKONTI</text>
    <text style="small" align="center" bold="true">Association loi 1901</text>
  </header>
  <continuation height="8mm">
    <text style="small">COWORKONTI · INV-1</text>
    <rule/>
  </continuation>
  <recipient window="fr"/>
  <body y="90mm">
    <text style="subheading">FACTURE INV-1</text>
    <spacer size="4mm"/>
    <table w="100%">
      <col w="55%"/><col w="15%" align="right"/><col w="30%" align="right"/>
      <row bold="true"><cell>Désignation</cell><cell>Qté</cell><cell>Total</cell></row>
      <row><cell>Participation 100 %</cell><cell align="center">1</cell><cell>100,00 €</cell></row>
    </table>
    <box x="60%" w="40%">
      <text align="right" bold="true">Total TTC 100,00 €</text>
    </box>
    <columns>
      <column><text>gauche</text></column>
      <column><markup>&gt; petit texte</markup></column>
    </columns>
  </body>
  <footer height="28mm">
    <text style="small">IBAN FR76</text>
  </footer>
</report-layout>
''';

    test('every element and attribute reads into the model', () {
      final d = parseLayoutXml(full);
      expect(d.page, 'A4');
      expect(d.margin, const Length(20, LengthUnit.mm));
      expect(d.header.height, const Length(25, LengthUnit.mm));
      expect(d.body.y, const Length(90, LengthUnit.mm));
      expect(d.recipient!.window, AddressWindow.right);
      expect(d.recipient!.frame, isNull);

      final image = d.header.children[0] as LayoutImage;
      expect(image.name, 'logo');
      expect(image.fit, LayoutFit.cover);
      expect(image.align, LayoutAlign.right);
      expect(image.frame.h, const Length(14, LengthUnit.mm));
      expect(image.frame.isPositioned, isTrue);

      final title = d.header.children[1] as LayoutText;
      expect(title.text, 'COWORKONTI');
      expect(title.style, LayoutStyle.heading);
      expect(title.frame.y, const Length(16, LengthUnit.mm));

      final small = d.header.children[2] as LayoutText;
      expect(small.style, LayoutStyle.small);
      expect(small.align, LayoutAlign.center);
      expect(small.bold, isTrue);
      expect(small.frame.isPositioned, isFalse);

      expect(d.continuation.children[1], isA<LayoutRule>());
      expect((d.body.children[1] as LayoutSpacer).size,
          const Length(4, LengthUnit.mm));

      final table = d.body.children[2] as LayoutTable;
      expect(table.columns.map((c) => c.w.toString()), ['55%', '15%', '30%']);
      expect(table.columns[1].align, LayoutAlign.right);
      expect(table.rows[0].bold, isTrue);
      expect(table.rows[1].cells[1].align, LayoutAlign.center);
      expect(table.rows[1].cells[0].align, isNull,
          reason: 'a cell without its own align inherits the column');

      final box = d.body.children[3] as LayoutBox;
      expect(box.frame.x, const Length(60, LengthUnit.percent));
      expect((box.children.single as LayoutText).bold, isTrue);

      final cols = d.body.children[4] as LayoutColumns;
      expect(cols.columns, hasLength(2));
      expect((cols.columns[1].single as LayoutMarkup).source, '> petit texte',
          reason: 'markup travels verbatim, entities decoded');

      expect(d.footer.height, const Length(28, LengthUnit.mm));
    });

    test('writing then reading gives the same tree — the exact inverse',
        () {
      final once = parseLayoutXml(full);
      final xml = layoutToXml(once);
      final twice = parseLayoutXml(xml);
      expect(layoutToXml(twice), xml,
          reason: 'a second round trip must be byte-identical');
      expect(twice.body.children.length, once.body.children.length);
      expect((twice.body.children[2] as LayoutTable).columns[0].w.toString(),
          '55%');
      expect(twice.recipient!.window, AddressWindow.right);
    });

    test('an explicit recipient frame is page-absolute and round-trips', () {
      final d = parseLayoutXml(
          '<report-layout><recipient x="110mm" y="45mm" w="85mm" h="40mm"/>'
          '</report-layout>');
      expect(d.recipient!.window, isNull);
      expect(d.recipient!.frame!.x, const Length(110, LengthUnit.mm));
      expect(layoutToXml(d), contains('x="110mm"'));
    });

    test('a recipient with neither window nor frame is refused', () {
      expect(
        () => parseLayoutXml('<report-layout><recipient/></report-layout>'),
        throwsA(isA<LayoutException>()
            .having((e) => e.error, 'error', LayoutError.badAttribute)),
      );
    });

    test('the four window spellings and off', () {
      for (final (spelling, want) in [
        ('fr', AddressWindow.right),
        ('right', AddressWindow.right),
        ('din', AddressWindow.left),
        ('left', AddressWindow.left),
        ('off', AddressWindow.off),
      ]) {
        final d = parseLayoutXml(
            '<report-layout><recipient window="$spelling"/></report-layout>');
        expect(d.recipient!.window, want, reason: spelling);
      }
    });

    test('indentation inside <text> does not become content', () {
      final d = parseLayoutXml('''
<report-layout><body><text>
      first line
      second line
</text></body></report-layout>''');
      expect((d.body.children.single as LayoutText).text,
          'first line\nsecond line');
    });
  });

  group('errors name the place', () {
    LayoutError errorOf(String xml) {
      try {
        parseLayoutXml(xml);
      } on LayoutException catch (e) {
        return e.error;
      }
      fail('parsed: $xml');
    }

    test('not XML → malformed', () {
      expect(errorOf('<report-layout><body>'), LayoutError.malformed);
      expect(errorOf('nope'), LayoutError.malformed);
    });

    test('XML that is not a layout → notALayout', () {
      expect(errorOf('<deskilo-workspace/>'), LayoutError.notALayout);
    });

    test('a newer version → unsupportedVersion', () {
      expect(errorOf('<report-layout version="2"/>'),
          LayoutError.unsupportedVersion);
    });

    test('an element outside the vocabulary → unknownElement, with its path',
        () {
      expect(
        () => parseLayoutXml('<report-layout><body><blink/></body></report-layout>'),
        throwsA(isA<LayoutException>()
            .having((e) => e.error, 'error', LayoutError.unknownElement)
            .having((e) => e.detail, 'detail', 'report-layout/body/blink')),
      );
      expect(errorOf('<report-layout><sidebar/></report-layout>'),
          LayoutError.unknownElement);
    });

    test('a bad enum, a bad bool, a bad unit, too many cells', () {
      expect(errorOf('<report-layout><body><text style="huge"/></body></report-layout>'),
          LayoutError.badAttribute);
      expect(errorOf('<report-layout><body><text bold="yes"/></body></report-layout>'),
          LayoutError.badAttribute);
      expect(errorOf('<report-layout><body><text x="3in"/></body></report-layout>'),
          LayoutError.badUnit);
      expect(errorOf('<report-layout><body><image/></body></report-layout>'),
          LayoutError.badAttribute, reason: 'an image needs a name');
      expect(errorOf('<report-layout page="Letter"/>'), LayoutError.badAttribute);
      expect(
        errorOf('<report-layout><body><table><col/><row><cell/><cell/></row>'
            '</table></body></report-layout>'),
        LayoutError.badAttribute,
        reason: 'a row wider than the declared columns',
      );
    });
  });

  test('the vocabulary constants are what the reader accepts', () {
    // `describe` and the how-to block print these; if the reader and the
    // list ever disagree, the documentation lies.
    for (final tag in LayoutXml.content) {
      final xml = switch (tag) {
        'image' => '<image name="x"/>',
        'table' => '<table/>',
        'columns' => '<columns/>',
        _ => '<$tag/>',
      };
      expect(() => parseLayoutXml('<report-layout><body>$xml</body></report-layout>'),
          returnsNormally,
          reason: tag);
    }
  });
}
