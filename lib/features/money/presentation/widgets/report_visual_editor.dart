// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_document_editor/deskilo_document_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/edge_fade_scroll.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/invoice_report.dart';
import '../../providers/money_providers.dart';
import 'report_field_picker.dart';
import 'report_image_notice.dart';
import 'report_page_style.dart';
import 'report_visual_line.dart';

export 'report_visual_line.dart' show ReportLineKind, ReportVisualLine;

part 'report_visual_editor_part1.dart';


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
    this.textKeys = const [],
  });

  final TextEditingController controller;
  final String label;
  final String bandKey;

  /// #822 — the OTHER bands (key → label) an element can be sent to.
  final Map<String, String> bandChoices;

  /// #880 — the owner's text keys the field picker offers.
  final List<String> textKeys;

  /// #822 — called when an element leaves for [bandChoices]' band; the
  /// host appends it there.
  final void Function(ReportVisualLine line, String targetBand)?
      onMoveToBand;

  @override
  ConsumerState<ReportVisualEditor> createState() =>
      ReportVisualEditorState();
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

  // #2386 — the operations; each body is in a part file.
  bool get hasSelection => _hasSelectionImpl;
  void insertLine(ReportVisualLine line) => _insertLineImpl(line);
  @override Widget build(BuildContext context) => _buildImpl(context);

  /// Lets the section extensions rebuild (setState is protected).
  void _update(VoidCallback fn) => setState(fn);

  /// The active element: the in-place editor + its toolbar. Designer
  /// CHROME on the paper — deliberately styled as tooling, so the
  /// document content around it keeps reading like the document.
  Widget _editor(int index) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final line = _lines[index];
    return Container(
      decoration: BoxDecoration(
        color: ReportPage.backdrop.withValues(alpha: .6),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: theme.colorScheme.primary),
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
              tooltip: l10n.a11yMoveUp,
              key: ValueKey('${widget.bandKey}-up-$index'),
              icon: const Icon(Icons.arrow_upward, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => _move(index, -1),
            ),
            IconButton(
              tooltip: l10n.a11yMoveDown,
              key: ValueKey('${widget.bandKey}-down-$index'),
              icon: const Icon(Icons.arrow_downward, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => _move(index, 1),
            ),
            // #822 — insert a TYPED element below.
            _kindMenu(
              key: ValueKey('${widget.bandKey}-insert-$index'),
              tooltip: l10n.reportDesignerInsert,
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
                tooltip: l10n.reportDesignerFields,
                visualDensity: VisualDensity.compact,
                onPressed: _pickField,
              ),
            if (widget.bandChoices.isNotEmpty)
              PopupMenuButton<String>(
                key: ValueKey('${widget.bandKey}-moveto-$index'),
                tooltip: l10n.reportDesignerMoveTo,
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
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              key: ValueKey('${widget.bandKey}-delete-$index'),
              icon: const Icon(Icons.delete_outline, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => _delete(index),
            ),
            IconButton(
              tooltip: l10n.a11yFinishEditing,
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return DragTarget<int>(
      key: ValueKey('${widget.bandKey}-drop-$index'),
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => _moveBefore(d.data, index),
      builder: (context, candidates, _) => DecoratedBox(
        decoration: candidates.isEmpty
            ? const BoxDecoration()
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
            message: l10n.reportDesignerDrag,
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

  Widget _buildImpl(BuildContext context) {
    final l10n = context.l10n;
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
            child: EdgeFadeScroll.around(
              builder: (context, controller) => ListView(
              key: ValueKey('${widget.bandKey}-palette'),
              controller: controller,
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
          ),
        if (_lines.isEmpty)
          Text(
            l10n.reportDesignEmpty,
            style:
                const TextStyle(fontSize: 9, color: ReportPage.chrome),
          ),
        for (final segment in segments)
          switch (segment) {
            ReportLineSegment(:final index) => _lineWidget(index),
            ReportGroupSegment(
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
            tooltip: l10n.reportDesignerInsert,
            onSelected: (kind) => _mutate(() {
              _adopt(_edit.insertBelow(
                  _lines.length - 1, ReportVisualLine(kind, '')));
              _editController.text = '';
            }),
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.reportVisualAddLine),
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
