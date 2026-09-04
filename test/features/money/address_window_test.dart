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
  test('the address field matches the DL window-envelope spec', () {
    expect(addressWindowTop / _mm, closeTo(45, 0.001));
    expect(addressWindowTopLimit / _mm, closeTo(50, 0.001));
    expect(addressWindowWidth / _mm, closeTo(85, 0.001));
    expect(addressWindowHeight / _mm, closeTo(40, 0.001));
    // Content resumes below BOTH the field and the tolerance band.
    expect(addressWindowFlowResume / _mm, closeTo(90, 0.001));
    expect(addressWindowFlowResume,
        greaterThanOrEqualTo(addressWindowTopLimit + addressWindowHeight),
        reason: 'the body would collide with a field placed at 50 mm');
    // The sender block sits at the page margin, above the field.
    expect(pageMargin / _mm, closeTo(20, 0.001));
    expect(pageMargin, lessThan(addressWindowTop));
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

  test('France takes the right-hand aperture, the DIN world the left',
      () {
    for (final country in ['FR', 'fr', 'MC']) {
      expect(addressWindowForCountry(country), AddressWindow.right,
          reason: country);
    }
    for (final country in ['DE', 'AT', 'CH', 'NL', 'US', 'CA', 'GB', '']) {
      expect(addressWindowForCountry(country), AddressWindow.left,
          reason: country.isEmpty ? '(no country)' : country);
    }
  });


  test('the right-hand field is the 110 mm DL aperture', () {
    expect(AddressWindow.right.leftEdge / _mm, closeTo(110, 0.001));
    // 110 + 85 = 195 mm, inside a 210 mm sheet.
    expect((AddressWindow.right.leftEdge + addressWindowWidth) / _mm,
        lessThanOrEqualTo(210));
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
