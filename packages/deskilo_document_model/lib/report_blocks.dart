// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4160 -- the generic report blocks and the rendered bands, in the neutral
// document model. They were parsed first in the invoice engine (#470), but a
// band's text is not invoice data and a workspace report draws the same
// blocks. A rendered text maps line-by-line onto blocks through a small
// markup:
//
//   `# text`   → document title        `## text` → section heading
//   `> text`   → small muted text      `---`     → accent divider
//   `a | b`    → table row, cells after the first right-aligned
//   `= a | b`  → bold table row (headers, totals)
//   blank line → vertical spacing      anything else → body text
//   `![name]` → an image from the workspace's report-image library
//   (#488) — the logo, a stamp, a signature scan; unresolved names
//   render as nothing. `![name|size|align]` (#822) sizes it S/M/L and
//   aligns it left/center/right; a bare `![name]` stays medium, left.
//   XL (#2898) is a picture the page is about — a level's plan.
//   `:::` … `|||` … `:::` → side-by-side columns (#482): the fenced
//   region is split at `|||` into equal-width columns, each parsed with
//   the same markup. An empty first column pushes the second to the
//   right — the classic seller-left/client-right address row and the
//   right-aligned totals block of a French facture.
//
// No template language, tracing, report-kind registry or application type is
// here: the host expands its own template and hands over the rendered text, or
// the finished bands.
import 'paper.dart';

/// One renderable block of a band.
sealed class ReportBlock {
  const ReportBlock();
}

class ReportHeading extends ReportBlock {
  const ReportHeading(this.text);
  final String text;
}

class ReportSubheading extends ReportBlock {
  const ReportSubheading(this.text);
  final String text;
}

class ReportText extends ReportBlock {
  const ReportText(this.text);
  final String text;
}

class ReportMuted extends ReportBlock {
  const ReportMuted(this.text);
  final String text;
}

class ReportDivider extends ReportBlock {
  const ReportDivider();
}

class ReportSpacer extends ReportBlock {
  const ReportSpacer();
}

class ReportTableRow extends ReportBlock {
  const ReportTableRow(this.cells, {this.bold = false});
  final List<String> cells;
  final bool bold;
}

/// An image reference (#488): `![name]` names a file in the workspace's
/// report-image library. The renderers resolve it to bytes; an unknown
/// name renders as nothing — a template must never break on a deleted
/// image.
class ReportImage extends ReportBlock {
  const ReportImage(
    this.name, {
    this.size = ReportImageSize.medium,
    this.align = ReportImageAlign.left,
  });

  /// `![name|size|align]` (#822) — the size and alignment are optional
  /// and order-free after the name; unknown words are ignored.
  factory ReportImage.parse(String inner) {
    final parts = inner.split('|').map((p) => p.trim()).toList();
    var size = ReportImageSize.medium;
    var align = ReportImageAlign.left;
    for (final part in parts.skip(1)) {
      size = ReportImageSize.values
              .where((v) => v.code == part.toLowerCase())
              .firstOrNull ??
          size;
      align = ReportImageAlign.values
              .where((v) => v.name == part.toLowerCase())
              .firstOrNull ??
          align;
    }
    return ReportImage(parts.first, size: size, align: align);
  }

  final String name;
  final ReportImageSize size;
  final ReportImageAlign align;

  /// The inner markup (`name|size|align`), the defaults left out so a
  /// plain `![logo]` round-trips as itself.
  String get markup => [
        name,
        if (size != ReportImageSize.medium) size.code,
        if (align != ReportImageAlign.left) align.name,
      ].join('|');
}

/// The image sizes a band can ask for (#822) — heights in points.
enum ReportImageSize {
  small('s', 40),
  medium('m', 64),
  large('l', 96),

  /// #2898 — a picture the page is about, at the height the data report
  /// prints a level's plan; a wide one is held to the page width.
  extraLarge('xl', 300);

  const ReportImageSize(this.code, this.height);
  final String code;
  final double height;
}

/// Where an image sits on its line (#822).
enum ReportImageAlign { left, center, right }

/// Side-by-side columns (#482) — each an independently parsed block
/// list, rendered equal-width. Nesting is not supported: an inner `:::`
/// simply closes the group.
class ReportColumns extends ReportBlock {
  const ReportColumns(this.columns);
  final List<List<ReportBlock>> columns;
}

/// The rendered bands of one document: what a host hands the PDF renderer
/// after it has expanded its template, whatever the document is (an invoice, a
/// letter, a workspace report).
class RenderedReport {
  const RenderedReport({
    required this.header,
    required this.body,
    required this.footer,
    this.continuation = const [],
    this.numberFirstPage = false,
    this.paper = Paper.a4,
  });

  final List<ReportBlock> header;
  final List<ReportBlock> body;
  final List<ReportBlock> footer;

  /// #872 — the header pages 2+ carry instead of the letterhead. Empty
  /// means the document draws its built-in identification strip.
  final List<ReportBlock> continuation;

  /// #2862 — whether page 1 carries its number too: a report's pages are
  /// counted from the first, a letter's from the second. The host decides
  /// (per document kind) and passes the answer.
  final bool numberFirstPage;

  /// #3852 — the paper the report is printed on.
  final Paper paper;

  /// This report with page 1 numbered or not, as the host resolved it.
  RenderedReport withNumberFirstPage(bool numbered) =>
      numbered == numberFirstPage
      ? this
      : _with(numberFirstPage: numbered, paper: paper);

  /// #3852 — this report printed on [on]; null keeps its own paper.
  RenderedReport onPaper(Paper? on) => on == null || on == paper
      ? this
      : _with(numberFirstPage: numberFirstPage, paper: on);

  RenderedReport _with({required bool numberFirstPage, required Paper paper}) =>
      RenderedReport(
        header: header,
        body: body,
        footer: footer,
        continuation: continuation,
        numberFirstPage: numberFirstPage,
        paper: paper,
      );
}

/// Every image name a rendered report references (#488) — what the
/// PDF builders must resolve to bytes before rendering.
Set<String> reportImageRefs(RenderedReport report) {
  final refs = <String>{};
  void walk(List<ReportBlock> blocks) {
    for (final block in blocks) {
      if (block is ReportImage) refs.add(block.name);
      if (block is ReportColumns) block.columns.forEach(walk);
    }
  }

  walk(report.header);
  walk(report.body);
  walk(report.footer);
  return refs;
}

/// Line-by-line markup → blocks; see the header comment for the rules.
List<ReportBlock> parseReportMarkup(String rendered) =>
    _parseLines(rendered.split('\n'));

List<ReportBlock> _parseLines(List<String> lines) {
  final blocks = <ReportBlock>[];
  var pendingSpace = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimRight();
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      // Collapse runs of blank lines into ONE spacer, and never lead
      // with one.
      pendingSpace = blocks.isNotEmpty;
      continue;
    }
    if (pendingSpace) {
      blocks.add(const ReportSpacer());
      pendingSpace = false;
    }
    if (trimmed == ':::') {
      // Column group (#482): collect to the closing fence, split at
      // `|||`, parse each column with the same rules.
      final columns = <List<String>>[[]];
      var j = i + 1;
      for (; j < lines.length && lines[j].trim() != ':::'; j++) {
        if (lines[j].trim() == '|||') {
          columns.add([]);
        } else {
          columns.last.add(lines[j]);
        }
      }
      i = j;
      blocks.add(ReportColumns(
        [for (final column in columns) _parseLines(column)],
      ));
      continue;
    }
    if (trimmed.startsWith('![') && trimmed.endsWith(']')) {
      blocks.add(ReportImage.parse(
          trimmed.substring(2, trimmed.length - 1).trim()));
      continue;
    }
    if (trimmed == '---') {
      blocks.add(const ReportDivider());
    } else if (trimmed.startsWith('## ')) {
      blocks.add(ReportSubheading(trimmed.substring(3).trim()));
    } else if (trimmed.startsWith('# ')) {
      blocks.add(ReportHeading(trimmed.substring(2).trim()));
    } else if (trimmed.startsWith('> ')) {
      blocks.add(ReportMuted(trimmed.substring(2).trim()));
    } else if (trimmed.contains('|')) {
      final bold = trimmed.startsWith('= ');
      final rowText = bold ? trimmed.substring(2) : trimmed;
      blocks.add(ReportTableRow(
        [for (final cell in rowText.split('|')) cell.trim()],
        bold: bold,
      ));
    } else {
      blocks.add(ReportText(trimmed));
    }
  }
  return blocks;
}
