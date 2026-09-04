// SPDX-License-Identifier: 0BSD
//
// #874 — the window-envelope layout spec, as data.
//
// These millimetres are not a style choice. An address 5 mm too high is
// behind cardboard; a footer that flows puts the account to pay into on
// a sheet the reader may not be holding; a missing recipient block is a
// missing mandatory mention on a French invoice. Every one of these has
// been wrong in a document that was actually printed.
//
// So the spec lives here, in one place, and BOTH the conformance test
// and the local report probe measure against these same numbers. A
// layout change that breaks one breaks the other.
import 'address_window.dart';

/// One rule the finished sheet has to satisfy.
class ReportZone {
  const ReportZone({
    required this.name,
    required this.topMm,
    required this.bottomMm,
    this.leftMm,
    this.widthMm,
    required this.why,
  });

  final String name;

  /// The band this zone owns, measured DOWN from the top of the sheet.
  final double topMm;
  final double bottomMm;

  /// Where the zone starts across the sheet, when it is pinned
  /// horizontally too (the address field is; the body is not).
  final double? leftMm;
  final double? widthMm;

  /// What goes wrong on paper when this is not respected — the reason
  /// the number is what it is, kept beside the number.
  final String why;

  bool containsY(double yMm) => yMm >= topMm && yMm <= bottomMm;
}

/// Millimetres per PostScript point, for turning the geometry constants
/// back into the units the spec is written in.
const double _perMm = 25.4 / 72;

/// The A4 window-envelope contract, in the order the eye reads it.
List<ReportZone> reportZones(AddressWindow window) => [
      const ReportZone(
        name: 'sender',
        topMm: pageMargin * _perMm,
        bottomMm: addressWindowTop * _perMm,
        leftMm: pageMargin * _perMm,
        why: 'the letterhead has only the 25 mm above the aperture; '
            'anything taller collides with the recipient',
      ),
      ReportZone(
        name: 'address field',
        topMm: addressWindowTop * _perMm,
        bottomMm: (addressWindowTop + addressWindowHeight) * _perMm,
        leftMm: window.isOn ? window.leftEdge * _perMm : null,
        widthMm: addressWindowWidth * _perMm,
        why: 'the envelope aperture: ink outside it is not visible '
            'without opening the envelope',
      ),
      const ReportZone(
        name: 'body',
        topMm: addressWindowFlowResume * _perMm,
        bottomMm: 297 - (pageMargin * _perMm),
        leftMm: pageMargin * _perMm,
        why: 'the identification block — the word Facture, the number '
            'and the dates — opens here, under the aperture and its '
            'tolerance band',
      ),
    ];

/// A finding from measuring a generated document.
class ConformanceIssue {
  const ConformanceIssue(this.zone, this.detail);
  final String zone;
  final String detail;

  @override
  String toString() => '$zone: $detail';
}
