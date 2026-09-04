// SPDX-License-Identifier: 0BSD
//
// #869 — a printed invoice is folded into a window envelope, so the
// recipient has to land inside the window: a field 85 × 45 mm, 45 mm
// down from the top of the sheet, on the side the country's envelope
// stock is cut for. Those numbers are the contract — a layout change
// that moves them posts the address behind cardboard, and nothing else
// in the suite would notice.
import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// PostScript points per millimetre.
const double _mm = 72 / 25.4;

void main() {
  test('the address field is DIN 5008 form B, in both conventions', () {
    expect(addressWindowTop / _mm, closeTo(45, 0.001));
    expect(addressWindowWidth / _mm, closeTo(85, 0.001));
    expect(addressWindowHeight / _mm, closeTo(45, 0.001));
    // The document's own content may only resume below the field.
    expect(addressWindowBottom / _mm, closeTo(90, 0.001));
  });

  test('the side is the only thing the two conventions disagree on', () {
    expect(AddressWindow.left.leftEdge / _mm, closeTo(20, 0.001));
    expect(AddressWindow.right.leftEdge / _mm, closeTo(110, 0.001));
    // Both fields end inside a 210 mm sheet.
    for (final window in [AddressWindow.left, AddressWindow.right]) {
      expect((window.leftEdge + addressWindowWidth) / _mm, lessThan(210),
          reason: '${window.name} runs off the sheet');
    }
  });

  test('every country defaults to the left field — the side is the '
      'owner\'s to correct, not ours to guess', () {
    // The pilot workspace's own French envelope is a left-window one,
    // and the French guidance measures the field from the LEFT edge.
    // Right-window stock exists too, which is exactly why this is a
    // default with an override rather than a per-country table.
    for (final country in [
      'FR', 'fr', 'MC', 'DE', 'AT', 'CH', 'NL', 'US', 'CA', 'GB', ''
    ]) {
      expect(addressWindowForCountry(country), AddressWindow.left,
          reason: country.isEmpty ? '(no country)' : country);
    }
  });

  test('20 mm is the safe offset against a 15 mm aperture', () {
    // A block at 20 mm sits inside an aperture opening at 15 mm; a
    // block at 15 mm would be clipped by one opening at 20 mm. The
    // error only runs one way, so the larger offset wins.
    expect(AddressWindow.left.leftEdge / _mm, greaterThanOrEqualTo(15));
  });

  test('an unset choice stays unset — it must not be pinned to a side',
      () {
    // The two conventions are on OPPOSITE sides, so a default written
    // into storage would post half of everyone's invoices wrongly.
    expect(addressWindowFromWire(null), isNull);
    expect(addressWindowFromWire('nonsense'), isNull);
    expect(const InvoicePdfTemplate().addressWindow, isNull);
    expect(const InvoicePdfTemplate().toJson()
        .containsKey(InvoicePdfTemplate.keyAddressWindow), isFalse);
  });

  test('an explicit choice survives a save/load round trip, and every '
      'other edit to the template', () {
    for (final window in AddressWindow.values) {
      final saved = InvoicePdfTemplate(addressWindow: window).toJson();
      expect(saved[InvoicePdfTemplate.keyAddressWindow],
          addressWindowWire(window));
      expect(
          InvoicePdfTemplate.fromJson(saved.cast<String, dynamic>())
              .addressWindow,
          window);
    }
    // Editing the bands must not silently reset the envelope layout.
    const before = InvoicePdfTemplate(addressWindow: AddressWindow.right);
    expect(
      before.copyWith(invoice: const ReportBands(header: 'x')).addressWindow,
      AddressWindow.right,
    );
    expect(before.withReminder(1, const ReportBands()).addressWindow,
        AddressWindow.right);
  });
}
