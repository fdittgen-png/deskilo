// SPDX-License-Identifier: 0BSD
//
// #873 — read a generated PDF back as MILLIMETRE positions.
//
// Every layout bug in this document has been invisible until something
// was printed and folded: an address 15 mm too high is behind cardboard,
// and nothing in a widget tree says so. So the conformance checks do not
// inspect widgets — they inflate the page's content stream, walk the
// drawing operators keeping the translation stack the way a viewer
// does, and report where ink actually landed on the sheet.
import 'dart:io';
import 'dart:typed_data';

/// PostScript points per millimetre.
const double mmPt = 72 / 25.4;

/// A4, in points.
const double a4WidthPt = 595.27559;
const double a4HeightPt = 841.88976;

/// One piece of ink, positioned from the TOP-LEFT of the sheet in mm —
/// the way a spec is written and a ruler is used, not the way PDF
/// stores it.
class InkAt {
  const InkAt({required this.xMm, required this.yMm, required this.page});

  final double xMm;
  final double yMm;
  final int page;

  @override
  String toString() =>
      'p$page (${xMm.toStringAsFixed(1)}, ${yMm.toStringAsFixed(1)}) mm';
}

/// Inflates every page content stream in [bytes], in page order.
List<String> pageStreams(Uint8List bytes) {
  final raw = String.fromCharCodes(bytes);
  final out = <String>[];
  for (final match in RegExp(r'stream\r?\n').allMatches(raw)) {
    final end = raw.indexOf('endstream', match.end);
    if (end < 0) continue;
    try {
      final text = String.fromCharCodes(
          zlib.decode(bytes.sublist(match.end, end)));
      // Content streams draw; font and metadata streams do not.
      if (text.contains('Td') || text.contains(' cm')) out.add(text);
    } catch (e, st) {
      // trace-exempt: a font program or an embedded file is not deflate
      // — an expected miss while walking every stream, not a failure.
      assert(st.toString().isNotEmpty);
      continue;
    }
  }
  return out;
}

/// Every text run in the document, as sheet coordinates.
///
/// Text is glyph-encoded by the embedded font, so the CONTENT cannot be
/// read back — only the position, which is the thing under test.
List<InkAt> textPositions(Uint8List bytes) {
  final found = <InkAt>[];
  final streams = pageStreams(bytes);
  for (var page = 0; page < streams.length; page++) {
    final stack = <List<double>>[];
    var tx = 0.0, ty = 0.0;
    final token = RegExp(
      r'(q)\b|(Q)\b|'
      r'([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+) cm|'
      r'([-\d.]+) ([-\d.]+) Td',
    );
    for (final m in token.allMatches(streams[page])) {
      if (m.group(1) != null) {
        stack.add([tx, ty]);
      } else if (m.group(2) != null) {
        if (stack.isNotEmpty) {
          final prev = stack.removeLast();
          tx = prev[0];
          ty = prev[1];
        }
      } else if (m.group(7) != null) {
        // Only translation is used by this document's layout.
        tx += double.parse(m.group(7)!);
        ty += double.parse(m.group(8)!);
      } else if (m.group(9) != null) {
        final x = tx + double.parse(m.group(9)!);
        final y = ty + double.parse(m.group(10)!);
        found.add(InkAt(
          xMm: x / mmPt,
          // PDF measures up from the bottom; a spec measures down.
          yMm: (a4HeightPt - y) / mmPt,
          page: page + 1,
        ));
      }
    }
  }
  return found;
}

/// Writes [bytes] beside the test run so a failure can be OPENED rather
/// than argued about, and returns the path.
String saveForInspection(Uint8List bytes, String name) {
  final dir = Directory('build/pdf-conformance')..createSync(recursive: true);
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(bytes);
  return file.path;
}

/// The pages on which the address field itself is painted.
///
/// The field is a positioned box, not text, so it is found by its exact
/// placement transform rather than by reading glyphs — which is also
/// the only way to tell "the recipient repeated" apart from "ordinary
/// content happens to sit at the same height".
List<int> addressFieldPages(
  Uint8List bytes, {
  required double leftEdgePt,
  required double topPt,
  required double heightPt,
}) {
  // A `Positioned(left:, top:)` becomes a translate measured from the
  // bottom of the sheet.
  final yPt = a4HeightPt - topPt - heightPt;
  final pages = <int>[];
  final streams = pageStreams(bytes);
  for (var page = 0; page < streams.length; page++) {
    for (final m in RegExp(r'1 0 0 1 ([-\d.]+) ([-\d.]+) cm')
        .allMatches(streams[page])) {
      final x = double.parse(m.group(1)!);
      final y = double.parse(m.group(2)!);
      if ((x - leftEdgePt).abs() < 0.5 && (y - yPt).abs() < 0.5) {
        pages.add(page + 1);
        break;
      }
    }
  }
  return pages;
}
