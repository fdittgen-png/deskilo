// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/invoice_report.dart';
import '../../providers/money_providers.dart';
import 'report_field_picker.dart';
import 'report_page_style.dart';

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

IconData reportLineIcon(ReportLineKind kind) => switch (kind) {
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

String reportLineName(ReportLineKind kind, AppLocalizations? l10n) =>
    switch (kind) {
      ReportLineKind.title => l10n?.reportLineTitle ?? 'Title',
      ReportLineKind.section => l10n?.reportLineSection ?? 'Section',
      ReportLineKind.text => l10n?.reportLineText ?? 'Text',
      ReportLineKind.small => l10n?.reportLineSmall ?? 'Small print',
      ReportLineKind.row => l10n?.reportLineRow ?? 'Table row',
      ReportLineKind.boldRow => l10n?.reportLineBoldRow ?? 'Bold row',
      ReportLineKind.divider => l10n?.reportLineDivider ?? 'Divider',
      ReportLineKind.spacer => l10n?.reportLineSpacer ?? 'Spacing',
      ReportLineKind.image => l10n?.reportLineImage ?? 'Image',
      ReportLineKind.columnsFence =>
        l10n?.reportLineColumns ?? 'Columns start/end',
      ReportLineKind.columnsSplit =>
        l10n?.reportLineColumnsSplit ?? 'Column break',
      ReportLineKind.logic => l10n?.reportLineLogic ?? 'Logic',
    };

/// #822 — the text style an element is EDITED in: the same one it
/// prints in, so the in-place field is the element, not a form about
/// it. Logic keeps the designer's monospace — it never prints.
TextStyle reportLineEditStyle(ReportLineKind kind) => switch (kind) {
      ReportLineKind.title => ReportPage.heading,
      ReportLineKind.section => ReportPage.subheading,
      ReportLineKind.small => ReportPage.small,
      ReportLineKind.boldRow => ReportPage.row(bold: true),
      ReportLineKind.row => ReportPage.row(bold: false),
      ReportLineKind.logic => const TextStyle(
          fontFamily: 'monospace', fontSize: 10, color: ReportPage.ink),
      _ => ReportPage.body,
    };

/// The DESIGN band editor (#498) — a real WYSIWYG surface in the
/// FastReport tradition: the band renders STYLED, exactly as the
/// document lays it out (title typography, small print, real
/// side-by-side columns, table rows, images), with `{{ field }}` and
/// `{% logic %}` shown as highlighted tokens the way report designers
/// show data fields. Tap any element to edit it in place — in its own
/// typography (#822) — and the toolbar under the active element changes
/// its type, inserts a typed element below, moves it (or drags it —
/// #822), sends it to another band, inserts a data field at the
/// cursor, or deletes it. Every change serializes straight back into
/// [controller], so the markup mode, save, preview and PDF always see
/// the same bands.
class ReportVisualEditor extends ConsumerStatefulWidget {
  const ReportVisualEditor({
    super.key,
    required this.controller,
    required this.label,
    required this.bandKey,
    this.bandChoices = const {},
    this.onMoveToBand,
  });

  final TextEditingController controller;
  final String label;
  final String bandKey;

  /// #822 — the OTHER bands (key → label) an element can be sent to.
  final Map<String, String> bandChoices;

  /// #822 — called when an element leaves for [bandChoices]' band; the
  /// host appends it there.
  final void Function(ReportVisualLine line, String targetBand)?
      onMoveToBand;

  @override
  ConsumerState<ReportVisualEditor> createState() =>
      ReportVisualEditorState();
}

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

class ReportVisualEditorState extends ConsumerState<ReportVisualEditor> {
  late List<ReportVisualLine> _lines;
  int? _editing;
  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lines = widget.controller.text.isEmpty
        ? []
        : widget.controller.text
            .split('\n')
            .map(ReportVisualLine.parse)
            .toList();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  /// #822 — whether an element is selected here (the host inserts an
  /// image after the selection of the band that has one).
  bool get hasSelection => _editing != null;

  /// #822 — inserts [line] after the selection, or at the end.
  void insertLine(ReportVisualLine line) {
    _mutate(() {
      final at = _editing == null ? _lines.length : _editing! + 1;
      _lines.insert(at, line);
      _editing = at;
      _editController.text = line.content;
    });
  }

  void _sync() {
    widget.controller.text =
        _lines.map((line) => line.serialize()).join('\n');
  }

  void _commitEditing() {
    final editing = _editing;
    if (editing == null) return;
    _lines[editing].content = _editController.text;
    _sync();
  }

  void _select(int index) {
    setState(() {
      _commitEditing();
      _editing = index;
      _editController.text = _lines[index].content;
    });
  }

  void _deselect() {
    setState(() {
      _commitEditing();
      _editing = null;
    });
  }

  void _mutate(void Function() change) {
    setState(() {
      _commitEditing();
      change();
    });
    _sync();
  }

  void _move(int index, int delta) {
    final to = index + delta;
    if (to < 0 || to >= _lines.length) return;
    _mutate(() {
      final line = _lines.removeAt(index);
      _lines.insert(to, line);
      _editing = to;
      _editController.text = line.content;
    });
  }

  /// #822 — a drag: the element at [from] lands BEFORE the element at
  /// [before] (the drop target).
  void _moveBefore(int from, int before) {
    if (from == before) return;
    _mutate(() {
      final line = _lines.removeAt(from);
      final to = before > from ? before - 1 : before;
      _lines.insert(to, line);
      _editing = to;
      _editController.text = line.content;
    });
  }

  void _insertBelow(int index, ReportLineKind kind) {
    _mutate(() {
      _lines.insert(index + 1, ReportVisualLine(kind, ''));
      _editing = index + 1;
      _editController.text = '';
    });
  }

  void _delete(int index) {
    _mutate(() {
      _lines.removeAt(index);
      _editing = null;
    });
  }

  void _sendTo(int index, String band) {
    final line = _lines[index];
    _mutate(() {
      _lines.removeAt(index);
      _editing = null;
    });
    widget.onMoveToBand?.call(line, band);
  }

  /// Inserts [token] at the cursor of the active editor.
  void _insertToken(String token) {
    final selection = _editController.selection;
    final text = _editController.text;
    final at = selection.isValid ? selection.start : text.length;
    _editController.text =
        text.substring(0, at) + token + text.substring(at);
    _editController.selection =
        TextSelection.collapsed(offset: at + token.length);
    _commitEditing();
    setState(() {});
  }

  Future<void> _pickField() async {
    final markup = await showReportFieldPicker(context);
    if (markup == null || !mounted) return;
    _insertToken(markup);
  }

  /// Groups the flat line list into render segments; a `:::` fence
  /// opens a column group, `|||` starts the next column.
  List<_Segment> _segments() {
    final segments = <_Segment>[];
    var i = 0;
    while (i < _lines.length) {
      if (_lines[i].kind == ReportLineKind.columnsFence) {
        final open = i;
        final columns = <List<int>>[[]];
        var j = i + 1;
        int? close;
        for (; j < _lines.length; j++) {
          if (_lines[j].kind == ReportLineKind.columnsFence) {
            close = j;
            break;
          }
          if (_lines[j].kind == ReportLineKind.columnsSplit) {
            columns.add([]);
          } else {
            columns.last.add(j);
          }
        }
        segments.add(_GroupSegment(open, columns, close));
        i = close == null ? _lines.length : close + 1;
      } else {
        segments.add(_LineSegment(i));
        i++;
      }
    }
    return segments;
  }

  /// Text with `{{ field }}` / `{% logic %}` rendered as TOKENS — the
  /// designer idiom for data fields. The token chrome is the ONLY
  /// deviation from print (#548): the surrounding text keeps the
  /// document's exact style, so the line's metrics stay honest.
  InlineSpan _tokenized(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\{\{.*?\}\}|\{%.*?%\}');
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: style.copyWith(
          color: ReportPage.chrome,
          backgroundColor: ReportPage.backdrop,
          fontFamily: 'monospace',
          fontSize: (style.fontSize ?? 10) * .85,
        ),
      ));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: style, children: spans);
  }

  /// One line, styled EXACTLY as `invoice_pdf.dart` prints its block
  /// (#548) — sizes, paddings, alignment and colors from [ReportPage].
  Widget _styledContent(ReportVisualLine line) {
    switch (line.kind) {
      case ReportLineKind.title:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(_tokenized(line.content, ReportPage.heading)),
        );
      case ReportLineKind.section:
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 3),
          child: Text.rich(_tokenized(
              line.content.toUpperCase(), ReportPage.subheading)),
        );
      case ReportLineKind.text:
        return Text.rich(_tokenized(line.content, ReportPage.body));
      case ReportLineKind.small:
        return Text.rich(_tokenized(line.content, ReportPage.small));
      case ReportLineKind.row:
      case ReportLineKind.boldRow:
        final style =
            ReportPage.row(bold: line.kind == ReportLineKind.boldRow);
        final cells = line.content.split('|');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < cells.length; c++)
                c == 0
                    ? Expanded(
                        child:
                            Text.rich(_tokenized(cells[c].trim(), style)))
                    : Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text.rich(
                              _tokenized(cells[c].trim(), style),
                              textAlign: TextAlign.right),
                        ),
                      ),
            ],
          ),
        );
      case ReportLineKind.divider:
        return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 2,
            color: ReportPage.accent);
      case ReportLineKind.spacer:
        return Container(
          height: 8,
          alignment: Alignment.center,
          child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 48),
              color: ReportPage.backdrop),
        );
      case ReportLineKind.image:
        final image = line.image;
        final bytes =
            ref.watch(reportImageBytesProvider(image.name)).value;
        return bytes == null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.image_outlined,
                    size: 18, color: ReportPage.chrome),
                const SizedBox(width: 4),
                Text(image.name, style: ReportPage.small),
              ])
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Align(
                  // #822 — size and alignment as the PDF draws them.
                  alignment: reportImageAlignment(image.align),
                  child: Image.memory(bytes,
                      height: image.size.height, fit: BoxFit.contain),
                ),
              );
      case ReportLineKind.logic:
        // Logic never prints — pure designer chrome, kept visually
        // OUTSIDE the document's typography.
        return Row(children: [
          const Icon(Icons.code, size: 14, color: ReportPage.chrome),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              line.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: ReportPage.chrome,
                  fontFamily: 'monospace',
                  fontSize: 10),
            ),
          ),
        ]);
      case ReportLineKind.columnsFence:
      case ReportLineKind.columnsSplit:
        // Boundaries render as part of the group chrome; standalone
        // (orphaned) markers show as their name.
        return Text(reportLineName(line.kind, AppLocalizations.of(context)),
            style: const TextStyle(
                fontSize: 10, color: ReportPage.chrome));
    }
  }

  /// #822 — the image element's own controls: size and alignment,
  /// written back as `name|size|align`.
  Widget _imageControls(int index, ReportVisualLine line) {
    final l10n = AppLocalizations.of(context);
    final image = line.image;
    void set({ReportImageSize? size, ReportImageAlign? align}) {
      final next = ReportImage(image.name,
          size: size ?? image.size, align: align ?? image.align);
      _editController.text = next.markup;
      _mutate(() => line.content = next.markup);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(image.name,
            style: const TextStyle(fontSize: 11, color: ReportPage.ink)),
        SegmentedButton<ReportImageSize>(
          key: ValueKey('${widget.bandKey}-image-size-$index'),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(
              value: ReportImageSize.small,
              label: Text(l10n?.reportImageSizeSmall ?? 'Small'),
            ),
            ButtonSegment(
              value: ReportImageSize.medium,
              label: Text(l10n?.reportImageSizeMedium ?? 'Medium'),
            ),
            ButtonSegment(
              value: ReportImageSize.large,
              label: Text(l10n?.reportImageSizeLarge ?? 'Large'),
            ),
          ],
          selected: {image.size},
          onSelectionChanged: (s) => set(size: s.first),
        ),
        SegmentedButton<ReportImageAlign>(
          key: ValueKey('${widget.bandKey}-image-align-$index'),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(
              value: ReportImageAlign.left,
              icon: Icon(Icons.format_align_left, size: 16),
            ),
            ButtonSegment(
              value: ReportImageAlign.center,
              icon: Icon(Icons.format_align_center, size: 16),
            ),
            ButtonSegment(
              value: ReportImageAlign.right,
              icon: Icon(Icons.format_align_right, size: 16),
            ),
          ],
          selected: {image.align},
          onSelectionChanged: (s) => set(align: s.first),
        ),
      ],
    );
  }

  /// A menu of element kinds — the insert palette (#822).
  Widget _kindMenu({
    required Key key,
    required Widget child,
    required ValueChanged<ReportLineKind> onSelected,
    String? tooltip,
  }) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<ReportLineKind>(
      key: key,
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final kind in ReportLineKind.values)
          PopupMenuItem(
            key: ValueKey('${(key as ValueKey).value}-${kind.name}'),
            value: kind,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(reportLineIcon(kind), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(reportLineName(kind, l10n),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
      ],
      child: child,
    );
  }

  /// The active element: the in-place editor + its toolbar. Designer
  /// CHROME on the paper — deliberately styled as tooling, so the
  /// document content around it keeps reading like the document.
  Widget _editor(int index) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final line = _lines[index];
    return Container(
      decoration: BoxDecoration(
        color: ReportPage.backdrop.withValues(alpha: .6),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: theme.colorScheme.primary, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (line.kind == ReportLineKind.image)
            _imageControls(index, line)
          else if (line.hasContent)
            TextField(
              key: ValueKey('${widget.bandKey}-field-$index'),
              controller: _editController,
              autofocus: true,
              maxLines: null,
              onChanged: (_) => _commitEditing(),
              // #822 — edited in the element's OWN typography.
              style: reportLineEditStyle(line.kind),
              decoration: const InputDecoration(
                  isDense: true, border: InputBorder.none),
            )
          else
            Text(reportLineName(line.kind, l10n),
                style: const TextStyle(
                    fontSize: 11, color: ReportPage.chrome)),
          // A Wrap, not a Row: inside a column the toolbar is narrower
          // than its buttons, and a clipped Done button is no button.
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            _kindMenu(
              key: ValueKey('${widget.bandKey}-type-$index'),
              tooltip: reportLineName(line.kind, l10n),
              onSelected: (kind) => _mutate(() => line.kind = kind),
              child: Icon(reportLineIcon(line.kind),
                  size: 20, color: theme.colorScheme.primary),
            ),
            IconButton(
              key: ValueKey('${widget.bandKey}-up-$index'),
              icon: const Icon(Icons.arrow_upward, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => _move(index, -1),
            ),
            IconButton(
              key: ValueKey('${widget.bandKey}-down-$index'),
              icon: const Icon(Icons.arrow_downward, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => _move(index, 1),
            ),
            // #822 — insert a TYPED element below.
            _kindMenu(
              key: ValueKey('${widget.bandKey}-insert-$index'),
              tooltip: l10n?.reportDesignerInsert ?? 'Insert element',
              onSelected: (kind) => _insertBelow(index, kind),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.add, size: 16),
              ),
            ),
            if (line.hasContent && line.kind != ReportLineKind.image)
              IconButton(
                key: ValueKey('${widget.bandKey}-fields-$index'),
                icon: const Icon(Icons.data_object, size: 16),
                tooltip: l10n?.reportDesignerFields ?? 'Fields',
                visualDensity: VisualDensity.compact,
                onPressed: _pickField,
              ),
            if (widget.bandChoices.isNotEmpty)
              PopupMenuButton<String>(
                key: ValueKey('${widget.bandKey}-moveto-$index'),
                tooltip: l10n?.reportDesignerMoveTo ?? 'Move to band',
                onSelected: (band) => _sendTo(index, band),
                itemBuilder: (context) => [
                  for (final entry in widget.bandChoices.entries)
                    PopupMenuItem(
                      key: ValueKey(
                          '${widget.bandKey}-moveto-$index-${entry.key}'),
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.drive_file_move_outline, size: 16),
                ),
              ),
            IconButton(
              key: ValueKey('${widget.bandKey}-delete-$index'),
              icon: const Icon(Icons.delete_outline, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => _delete(index),
            ),
            IconButton(
              key: ValueKey('${widget.bandKey}-done-$index'),
              icon: const Icon(Icons.check, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: _deselect,
            ),
          ]),
        ],
      ),
    );
  }

  /// #822 — a line is a DRAG SOURCE (long-press) and a DROP TARGET: the
  /// dragged element lands before the one it is dropped on. A thin
  /// primary line above the target shows where.
  Widget _draggable(int index, Widget child) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return DragTarget<int>(
      key: ValueKey('${widget.bandKey}-drop-$index'),
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => _moveBefore(d.data, index),
      builder: (context, candidates, _) => Container(
        decoration: candidates.isEmpty
            ? null
            : BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: theme.colorScheme.primary, width: 2))),
        child: LongPressDraggable<int>(
          data: index,
          axis: Axis.vertical,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: .85,
              child: Container(
                width: ReportPage.width - ReportPage.margins.horizontal,
                color: ReportPage.paper,
                padding: const EdgeInsets.all(2),
                child: _styledContent(_lines[index]),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: .3, child: child),
          child: Tooltip(
            message: l10n?.reportDesignerDrag ?? 'Drag to reorder',
            waitDuration: const Duration(seconds: 1),
            // Hover only: a long-press tooltip would win the long press
            // the drag needs.
            triggerMode: TooltipTriggerMode.manual,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _lineWidget(int index) {
    if (index == _editing) return _editor(index);
    final line = _lines[index];
    return _draggable(
      index,
      InkWell(
        key: ValueKey('${widget.bandKey}-line-$index'),
        onTap: () => _select(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: _styledContent(line),
        ),
      ),
    );
  }

  /// A tappable dashed group boundary (the `:::` / `|||` markers) —
  /// designer chrome, never printed.
  Widget _boundary(int index, {required bool split}) {
    if (index == _editing) return _editor(index);
    return InkWell(
      key: ValueKey('${widget.bandKey}-line-$index'),
      onTap: () => _select(index),
      child: Container(
        height: 10,
        alignment: Alignment.center,
        child: Row(children: [
          Expanded(
            child: Container(
              height: 1,
              color: ReportPage.chrome.withValues(alpha: .5),
            ),
          ),
          Icon(
              split
                  ? Icons.vertical_split_outlined
                  : Icons.view_column_outlined,
              size: 10,
              color: ReportPage.chrome),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final segments = _segments();
    // #548 — the band renders DIRECTLY on the page the designer
    // provides: no paper of its own, no theme colors. The strip above
    // it is the banded-designer idiom (DevExpress/Crystal): a labeled
    // chrome separator marking where the band begins.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: ReportPage.backdrop,
          child: Text(
            widget.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
              color: ReportPage.chrome,
            ),
          ),
        ),
        // #498 — the data-field palette: tap to insert at the cursor
        // of the active element (the designer idiom).
        if (_editing != null &&
            _lines[_editing!].hasContent &&
            _lines[_editing!].kind != ReportLineKind.image)
          SizedBox(
            height: 34,
            child: ListView(
              key: ValueKey('${widget.bandKey}-palette'),
              scrollDirection: Axis.horizontal,
              children: [
                for (final field in InvoicePdfTemplate.placeholders)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ActionChip(
                      key: ValueKey('${widget.bandKey}-token-$field'),
                      visualDensity: VisualDensity.compact,
                      label: Text(field,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 10)),
                      onPressed: () => _insertToken('{{ $field }}'),
                    ),
                  ),
              ],
            ),
          ),
        if (_lines.isEmpty)
          Text(
            l10n?.reportDesignEmpty ??
                'Empty band — add an element below.',
            style:
                const TextStyle(fontSize: 9, color: ReportPage.chrome),
          ),
        for (final segment in segments)
          switch (segment) {
            _LineSegment(:final index) => _lineWidget(index),
            _GroupSegment(
              :final openIndex,
              :final columns,
              :final closeIndex,
            ) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _boundary(openIndex, split: false),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < columns.length; c++) ...[
                        if (c > 0) _splitHandle(columns, c),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              for (final index in columns[c])
                                _lineWidget(index),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (closeIndex != null)
                    _boundary(closeIndex, split: false),
                ],
              ),
          },
        Align(
          alignment: Alignment.centerLeft,
          // #822 — the band's own insert palette: a TYPED element at
          // the end, not always a text line to retype.
          child: _kindMenu(
            key: ValueKey('${widget.bandKey}-add'),
            tooltip: l10n?.reportDesignerInsert ?? 'Insert element',
            onSelected: (kind) => _mutate(() {
              _lines.add(ReportVisualLine(kind, ''));
              _editing = _lines.length - 1;
              _editController.text = '';
            }),
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n?.reportVisualAddLine ?? 'Add line'),
              style: TextButton.styleFrom(
                foregroundColor: ReportPage.chrome,
                visualDensity: VisualDensity.compact,
              ),
              // The menu opens from the surrounding button.
              onPressed: null,
            ),
          ),
        ),
      ],
    );
  }

  /// The vertical `|||` handle between two columns — 16 wide, the
  /// PDF's column gutter, so column widths read true (#548).
  Widget _splitHandle(List<List<int>> columns, int column) {
    // The split marker sits right before this column's first line (or
    // right after the previous column's last line).
    final before = columns[column].isNotEmpty
        ? columns[column].first - 1
        : (columns[column - 1].isNotEmpty
            ? columns[column - 1].last + 1
            : null);
    return InkWell(
      key: before == null
          ? null
          : ValueKey('${widget.bandKey}-line-$before'),
      onTap: before == null ? null : () => _select(before),
      child: Container(
        width: 16,
        constraints: const BoxConstraints(minHeight: 24),
        alignment: Alignment.center,
        child: Container(
          width: 1,
          height: 24,
          color: ReportPage.chrome.withValues(alpha: .5),
        ),
      ),
    );
  }
}
