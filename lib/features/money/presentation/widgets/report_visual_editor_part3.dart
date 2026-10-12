// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'report_visual_editor.dart';


/// The kinds a visual line can be (#488) — one per markup prefix. The
/// visual editor is WYSIWYG over the SAME markup the text mode edits:
/// every row serializes back to exactly one line, so the two modes
/// round-trip losslessly.
enum ReportLineKind {
  title,
  section,
  text,
  small,
  row,
  boldRow,
  divider,
  spacer,
  image,
  columnsFence,
  columnsSplit,
  logic,
}

/// One editable line: its kind and its content (without the prefix).
class ReportVisualLine {
  ReportVisualLine(this.kind, this.content);

  ReportLineKind kind;
  String content;

  /// Parses one raw markup line.
  factory ReportVisualLine.parse(String raw) {
    final line = raw.trimRight();
    final trimmed = line.trim();
    if (trimmed.isEmpty) return ReportVisualLine(ReportLineKind.spacer, '');
    if (trimmed == '---') {
      return ReportVisualLine(ReportLineKind.divider, '');
    }
    if (trimmed == ':::') {
      return ReportVisualLine(ReportLineKind.columnsFence, '');
    }
    if (trimmed == '|||') {
      return ReportVisualLine(ReportLineKind.columnsSplit, '');
    }
    if (trimmed.startsWith('## ')) {
      return ReportVisualLine(
          ReportLineKind.section, trimmed.substring(3).trim());
    }
    if (trimmed.startsWith('# ')) {
      return ReportVisualLine(
          ReportLineKind.title, trimmed.substring(2).trim());
    }
    if (trimmed.startsWith('> ')) {
      return ReportVisualLine(
          ReportLineKind.small, trimmed.substring(2).trim());
    }
    if (trimmed.startsWith('![') && trimmed.endsWith(']')) {
      return ReportVisualLine(ReportLineKind.image,
          trimmed.substring(2, trimmed.length - 1).trim());
    }
    if (trimmed.startsWith('{%')) {
      return ReportVisualLine(ReportLineKind.logic, trimmed);
    }
    if (trimmed.startsWith('= ')) {
      return ReportVisualLine(
          ReportLineKind.boldRow, trimmed.substring(2));
    }
    if (trimmed.contains('|')) {
      return ReportVisualLine(ReportLineKind.row, trimmed);
    }
    return ReportVisualLine(ReportLineKind.text, trimmed);
  }

  /// The markup line this row stands for.
  String serialize() => switch (kind) {
        ReportLineKind.title => '# $content',
        ReportLineKind.section => '## $content',
        ReportLineKind.small => '> $content',
        ReportLineKind.divider => '---',
        ReportLineKind.spacer => '',
        ReportLineKind.image => '![$content]',
        ReportLineKind.columnsFence => ':::',
        ReportLineKind.columnsSplit => '|||',
        ReportLineKind.boldRow => '= $content',
        ReportLineKind.row || ReportLineKind.logic || ReportLineKind.text =>
          content,
      };

  /// Whether the row carries editable text at all.
  bool get hasContent => switch (kind) {
        ReportLineKind.divider ||
        ReportLineKind.spacer ||
        ReportLineKind.columnsFence ||
        ReportLineKind.columnsSplit =>
          false,
        _ => true,
      };

  /// #822 — an image line's `name|size|align` read as a block.
  ReportImage get image => ReportImage.parse(content);
}

IconData _reportLineIcon(ReportLineKind kind) => switch (kind) {
      ReportLineKind.title => Icons.title,
      ReportLineKind.section => Icons.short_text,
      ReportLineKind.text => Icons.notes,
      ReportLineKind.small => Icons.text_decrease,
      ReportLineKind.row => Icons.table_rows_outlined,
      ReportLineKind.boldRow => Icons.format_bold,
      ReportLineKind.divider => Icons.horizontal_rule,
      ReportLineKind.spacer => Icons.height,
      ReportLineKind.image => Icons.image_outlined,
      ReportLineKind.columnsFence => Icons.view_column_outlined,
      ReportLineKind.columnsSplit => Icons.vertical_split_outlined,
      ReportLineKind.logic => Icons.code,
    };

String _reportLineName(ReportLineKind kind, AppLocalizations l10n) =>
    switch (kind) {
      ReportLineKind.title => l10n.reportLineTitle,
      ReportLineKind.section => l10n.reportLineSection,
      ReportLineKind.text => l10n.reportLineText,
      ReportLineKind.small => l10n.reportLineSmall,
      ReportLineKind.row => l10n.reportLineRow,
      ReportLineKind.boldRow => l10n.reportLineBoldRow,
      ReportLineKind.divider => l10n.reportLineDivider,
      ReportLineKind.spacer => l10n.reportLineSpacer,
      ReportLineKind.image => l10n.reportLineImage,
      ReportLineKind.columnsFence =>
        l10n.reportLineColumns,
      ReportLineKind.columnsSplit =>
        l10n.reportLineColumnsSplit,
      ReportLineKind.logic => l10n.reportLineLogic,
    };

/// #822 — the text style an element is EDITED in: the same one it
/// prints in, so the in-place field is the element, not a form about
/// it. Logic keeps the designer's monospace — it never prints.
TextStyle _reportLineEditStyle(ReportLineKind kind) => switch (kind) {
      ReportLineKind.title => ReportPage.heading,
      ReportLineKind.section => ReportPage.subheading,
      ReportLineKind.small => ReportPage.small,
      ReportLineKind.boldRow => ReportPage.row(bold: true),
      ReportLineKind.row => ReportPage.row(bold: false),
      ReportLineKind.logic => const TextStyle(
          fontFamily: 'monospace', fontSize: 10, color: ReportPage.ink),
      _ => ReportPage.body,
    };

/// One render segment: a plain line, or a `:::` column group.
sealed class _Segment {
  const _Segment();
}

class _LineSegment extends _Segment {
  const _LineSegment(this.index);
  final int index;
}

class _GroupSegment extends _Segment {
  const _GroupSegment(this.openIndex, this.columns, this.closeIndex);

  final int openIndex;

  /// Per column: the indexes of its lines.
  final List<List<int>> columns;

  /// The closing fence index, or null when the fence never closed.
  final int? closeIndex;
}
