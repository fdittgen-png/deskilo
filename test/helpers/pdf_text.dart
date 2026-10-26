// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The words a PDF actually prints, read back out of the file: every text
// run of every page, decoded through its font's ToUnicode map. A test then
// asserts on what a reader of the PDF sees, not on the widget tree that
// was meant to produce it.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The text runs of each page of [bytes], in page and drawing order. Runs
/// are what the PDF writer emitted (a word, a number); join them with a
/// space to search a sentence.
List<List<String>> pdfPageTexts(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  final objects = <int, ({String text, int start})>{};
  for (final m in RegExp(
    r'(\d+) 0 obj(.*?)endobj',
    dotAll: true,
  ).allMatches(raw)) {
    objects[int.parse(m.group(1)!)] = (
      text: m.group(2)!,
      start: m.start + m.group(1)!.length + ' 0 obj'.length,
    );
  }
  String streamOf(int id) {
    final o = objects[id]!;
    final at = RegExp(r'stream\r?\n').firstMatch(o.text);
    if (at == null) return '';
    final start = o.start + at.end;
    final data = bytes.sublist(start, raw.indexOf('endstream', start));
    try {
      return latin1.decode(zlib.decode(data));
    } on FormatException {
      return latin1.decode(data);
    }
  }

  int ref(String text, String key) => int.parse(
    RegExp('/$key\\s+(\\d+)\\s+0\\s+R').firstMatch(text)!.group(1)!,
  );

  // Each font object's glyph -> text map, from its ToUnicode CMap.
  final cmaps = <int, Map<int, String>>{};
  for (final e in objects.entries) {
    if (!e.value.text.contains('/ToUnicode')) continue;
    final map = <int, String>{};
    final cmap = streamOf(ref(e.value.text, 'ToUnicode'));
    for (final m in RegExp(
      r'<([0-9A-Fa-f]{4})>\s*<([0-9A-Fa-f]+)>',
    ).allMatches(cmap)) {
      final hex = m.group(2)!;
      map[int.parse(m.group(1)!, radix: 16)] = String.fromCharCodes([
        for (var i = 0; i + 4 <= hex.length; i += 4)
          int.parse(hex.substring(i, i + 4), radix: 16),
      ]);
    }
    cmaps[e.key] = map;
  }
  final fonts = <String, int>{
    for (final m in RegExp(r'/(F\d+)\s+(\d+)\s+0\s+R').allMatches(raw))
      m.group(1)!: int.parse(m.group(2)!),
  };
  final tree = objects.values.firstWhere(
    (o) => RegExp(r'/Type\s*/Pages\b').hasMatch(o.text),
  );
  final kids = RegExp(r'(\d+)\s+0\s+R').allMatches(
    RegExp(r'/Kids\s*\[([^\]]*)\]').firstMatch(tree.text)!.group(1)!,
  );
  return [
    for (final kid in kids)
      _runs(
        streamOf(ref(objects[int.parse(kid.group(1)!)]!.text, 'Contents')),
        (name) => cmaps[fonts[name]] ?? const {},
      ),
  ];
}

List<String> _runs(
  String content,
  Map<int, String> Function(String font) cmapOf,
) {
  final runs = <String>[];
  var cmap = const <int, String>{};
  final token = RegExp(
    r'/(F\d+)\s+[\d.]+\s+Tf|\[((?:<[0-9A-Fa-f]*>|[^\]])*)\]\s*TJ|<([0-9A-Fa-f]*)>\s*Tj',
  );
  for (final m in token.allMatches(content)) {
    if (m.group(1) != null) {
      cmap = cmapOf(m.group(1)!);
      continue;
    }
    final hexes = m.group(2) != null
        ? RegExp(r'<([0-9A-Fa-f]*)>')
              .allMatches(m.group(2)!)
              .map((h) => h.group(1)!)
        : [m.group(3)!];
    final text = StringBuffer();
    for (final hex in hexes) {
      for (var i = 0; i + 4 <= hex.length; i += 4) {
        text.write(cmap[int.parse(hex.substring(i, i + 4), radix: 16)] ?? '');
      }
    }
    if (text.isNotEmpty) runs.add(text.toString());
  }
  return runs;
}

/// Every page's runs joined by spaces.
List<String> pdfPageLines(Uint8List bytes) => [
  for (final page in pdfPageTexts(bytes)) page.join(' '),
];

/// The size of each page in points, from its MediaBox.
List<({double width, double height})> pdfPageSizes(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  return [
    for (final m in RegExp(
      r'/MediaBox\s*\[\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\]',
    ).allMatches(raw))
      (
        width: double.parse(m.group(3)!) - double.parse(m.group(1)!),
        height: double.parse(m.group(4)!) - double.parse(m.group(2)!),
      ),
  ];
}
