// SPDX-License-Identifier: 0BSD
import 'package:file_selector/file_selector.dart' show XTypeGroup;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_picker.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../providers/money_providers.dart';
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

/// The DESIGN band editor (#498) — a real WYSIWYG surface in the
/// FastReport tradition: the band renders STYLED, exactly as the
/// document lays it out (title typography, small print, real
/// side-by-side columns, table rows, images), with `{{ field }}` and
/// `{% logic %}` shown as highlighted tokens the way report designers
/// show data fields. Tap any element to edit it in place; the toolbar
/// under the active element changes its type, moves it, inserts a
/// data field at the cursor, adds a line below, or deletes it. Every
/// change serializes straight back into [controller], so the markup
/// mode, save, preview and PDF always see the same bands.
class ReportVisualEditor extends ConsumerStatefulWidget {
  const ReportVisualEditor({
    super.key,
    required this.controller,
    required this.label,
    required this.bandKey,
  });

  final TextEditingController controller;
  final String label;
  final String bandKey;

  @override
  ConsumerState<ReportVisualEditor> createState() =>
      _ReportVisualEditorState();
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

class _ReportVisualEditorState extends ConsumerState<ReportVisualEditor> {
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

  void _insertBelow(int index) {
    _mutate(() {
      _lines.insert(
          index + 1, ReportVisualLine(ReportLineKind.text, ''));
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
                    : Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text.rich(
                            _tokenized(cells[c].trim(), style),
                            textAlign: TextAlign.right),
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
        final bytes =
            ref.watch(reportImageBytesProvider(line.content)).value;
        return bytes == null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.image_outlined,
                    size: 18, color: ReportPage.chrome),
                const SizedBox(width: 4),
                Text(line.content, style: ReportPage.small),
              ])
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child:
                      Image.memory(bytes, height: 64, fit: BoxFit.contain),
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
          if (line.hasContent)
            TextField(
              key: ValueKey('${widget.bandKey}-field-$index'),
              controller: _editController,
              autofocus: true,
              maxLines: null,
              onChanged: (_) => _commitEditing(),
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: ReportPage.ink),
              decoration: const InputDecoration(
                  isDense: true, border: InputBorder.none),
            )
          else
            Text(reportLineName(line.kind, l10n),
                style: const TextStyle(
                    fontSize: 11, color: ReportPage.chrome)),
          Row(children: [
            PopupMenuButton<ReportLineKind>(
              key: ValueKey('${widget.bandKey}-type-$index'),
              tooltip: reportLineName(line.kind, l10n),
              onSelected: (kind) => _mutate(() => line.kind = kind),
              itemBuilder: (context) => [
                for (final kind in ReportLineKind.values)
                  PopupMenuItem(
                    value: kind,
                    child: Row(children: [
                      Icon(reportLineIcon(kind), size: 18),
                      const SizedBox(width: 8),
                      Text(reportLineName(kind, l10n)),
                    ]),
                  ),
              ],
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
            IconButton(
              key: ValueKey('${widget.bandKey}-insert-$index'),
              icon: const Icon(Icons.add, size: 16),
              tooltip: l10n?.reportVisualAddLine ?? 'Add line',
              visualDensity: VisualDensity.compact,
              onPressed: () => _insertBelow(index),
            ),
            IconButton(
              key: ValueKey('${widget.bandKey}-delete-$index'),
              icon: const Icon(Icons.delete_outline, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () => _delete(index),
            ),
            const Spacer(),
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

  Widget _lineWidget(int index) {
    if (index == _editing) return _editor(index);
    final line = _lines[index];
    return InkWell(
      key: ValueKey('${widget.bandKey}-line-$index'),
      onTap: () => _select(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: _styledContent(line),
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
        if (_editing != null)
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
          child: TextButton.icon(
            key: ValueKey('${widget.bandKey}-add'),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n?.reportVisualAddLine ?? 'Add line'),
            style: TextButton.styleFrom(
              foregroundColor: ReportPage.chrome,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _mutate(() {
              _lines.add(ReportVisualLine(ReportLineKind.text, ''));
              _editing = _lines.length - 1;
              _editController.text = '';
            }),
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

/// The report-image LIBRARY picker (#488): the workspace's uploaded
/// images with an upload button. Pops with the chosen image's name, or
/// null when dismissed.
Future<String?> showReportImagePicker(
  BuildContext context,
  WidgetRef ref,
) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _ReportImageDialog(),
    );

class _ReportImageDialog extends ConsumerWidget {
  const _ReportImageDialog();

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final pick = ref.read(filePickerProvider);
    final file = await pick(XTypeGroup(
      label: l10n?.profilePhotoFileType ?? 'Image',
      extensions: const ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: const ['image/jpeg', 'image/png', 'image/webp'],
    ));
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'report image upload failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(moneyRepositoryProvider).uploadReportImage(
            workspace.id,
            name: safeFileSlug(file.name),
            bytes: bytes,
            contentType: file.mimeType ?? 'image/png',
          ),
    );
    ref.invalidate(reportImagesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final images = ref.watch(reportImagesProvider).value ?? const [];
    return AlertDialog(
      title: Text(l10n?.reportImagesTitle ?? 'Report images'),
      content: SizedBox(
        width: 360,
        child: images.isEmpty
            ? Text(l10n?.reportImagesEmpty ??
                'No image yet — upload your logo, a stamp or a '
                    'signature and reference it with ![name].')
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final name in images)
                    ListTile(
                      key: ValueKey('report-image-$name'),
                      leading: SizedBox(
                        width: 40,
                        height: 40,
                        child: ref
                                    .watch(reportImageBytesProvider(name))
                                    .value ==
                                null
                            ? const Icon(Icons.image_outlined)
                            : Image.memory(
                                ref
                                    .watch(reportImageBytesProvider(name))
                                    .value!,
                                fit: BoxFit.contain,
                              ),
                      ),
                      title: Text(name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.of(context).pop(name),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton.icon(
          key: const ValueKey('report-image-upload'),
          icon: const Icon(Icons.upload_outlined),
          label: Text(l10n?.reportImageUpload ?? 'Upload image'),
          onPressed: () => _upload(context, ref),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
      ],
    );
  }
}
