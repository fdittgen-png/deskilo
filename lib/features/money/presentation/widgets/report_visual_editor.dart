// SPDX-License-Identifier: 0BSD
import 'package:file_selector/file_selector.dart' show XTypeGroup;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_picker.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/money_providers.dart';

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

/// The VISUAL band editor (#488): the band's markup as a reorderable
/// list of typed rows — change a row's type from its icon, edit its
/// text inline, drag to reorder, delete, add. Every change serializes
/// straight back into [controller], so save/preview/PDF and the markup
/// mode all see the same text.
class ReportVisualEditor extends StatefulWidget {
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
  State<ReportVisualEditor> createState() => _ReportVisualEditorState();
}

class _ReportVisualEditorState extends State<ReportVisualEditor> {
  late List<ReportVisualLine> _lines;
  final List<TextEditingController> _rowControllers = [];

  @override
  void initState() {
    super.initState();
    _lines = widget.controller.text.isEmpty
        ? []
        : widget.controller.text
            .split('\n')
            .map(ReportVisualLine.parse)
            .toList();
    _rebuildControllers();
  }

  void _rebuildControllers() {
    for (final c in _rowControllers) {
      c.dispose();
    }
    _rowControllers
      ..clear()
      ..addAll(
          [for (final line in _lines) TextEditingController(text: line.content)]);
  }

  @override
  void dispose() {
    for (final c in _rowControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync() {
    for (var i = 0; i < _lines.length; i++) {
      _lines[i].content = _rowControllers[i].text;
    }
    widget.controller.text =
        _lines.map((line) => line.serialize()).join('\n');
  }

  void _mutate(void Function() change) {
    // Capture the typed text FIRST — a reorder/delete must not lose it.
    for (var i = 0; i < _lines.length; i++) {
      _lines[i].content = _rowControllers[i].text;
    }
    setState(() {
      change();
      _rebuildControllers();
    });
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        padding: AppSpacing.smAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.label, style: theme.textTheme.labelMedium),
            ReorderableListView.builder(
              key: ValueKey('${widget.bandKey}-list'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _lines.length,
              onReorder: (from, to) => _mutate(() {
                final line = _lines.removeAt(from);
                _lines.insert(to > from ? to - 1 : to, line);
              }),
              itemBuilder: (context, index) {
                final line = _lines[index];
                return Padding(
                  key: ValueKey('${widget.bandKey}-row-$index'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      // The row's TYPE — tap to change it.
                      PopupMenuButton<ReportLineKind>(
                        key: ValueKey('${widget.bandKey}-type-$index'),
                        tooltip: reportLineName(line.kind, l10n),
                        onSelected: (kind) =>
                            _mutate(() => line.kind = kind),
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
                            size: 20,
                            color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: line.hasContent
                            ? TextField(
                                key: ValueKey(
                                    '${widget.bandKey}-field-$index'),
                                controller: _rowControllers[index],
                                onChanged: (_) => _sync(),
                                style: theme.textTheme.bodySmall,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                              )
                            : Text(
                                reportLineName(line.kind, l10n),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                      ),
                      IconButton(
                        key: ValueKey('${widget.bandKey}-delete-$index'),
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _mutate(() => _lines.removeAt(index)),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle, size: 20),
                      ),
                    ],
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('${widget.bandKey}-add'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n?.reportVisualAddLine ?? 'Add line'),
                onPressed: () => _mutate(() =>
                    _lines.add(ReportVisualLine(ReportLineKind.text, ''))),
              ),
            ),
          ],
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
