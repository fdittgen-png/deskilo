// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — what the visual report editor does with its lines: select, move,
// insert, delete, tokens and the styled rendering of one line. Split out of
// report_visual_editor.dart (was a part file with an extension on the state);
// the state keeps the lines, the selection and the edit controller and says
// so here as abstract members.
import 'package:deskilo_document_editor/deskilo_document_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/invoice_report.dart';
import '../../providers/money_providers.dart';
import 'report_field_picker.dart';
import 'report_image_notice.dart';
import 'report_page_style.dart';
import 'report_visual_editor.dart' show ReportVisualEditor;
import 'report_visual_line.dart';

mixin ReportVisualEditorActions on ConsumerState<ReportVisualEditor> {
  abstract List<ReportVisualLine> visualLines;
  abstract int? visualEditing;
  TextEditingController get visualEditController;
  void visualUpdate(VoidCallback fn);


  /// #822 — whether an element is selected here (the host inserts an
  /// image after the selection of the band that has one).
  bool get visualHasSelectionImpl => visualEditing != null;

  /// #822 — inserts [line] after the selection, or at the end.
  void visualInsertLineImpl(ReportVisualLine line) {
    visualMutate(() {
      visualAdopt(visualEdit.insertAfterSelection(line));
      visualEditController.text = line.content;
    });
  }

  /// The elements and the selection as the package's value.
  ElementEdit<ReportVisualLine> get visualEdit =>
      ElementEdit(visualLines, selected: visualEditing);

  /// Takes the package's result as this editor's lines and selection.
  void visualAdopt(ElementEdit<ReportVisualLine> next) {
    visualLines = List.of(next.items);
    visualEditing = next.selected;
  }

  void visualSync() {
    widget.controller.text =
        visualLines.map((line) => line.serialize()).join('\n');
  }

  void visualCommitEditing() {
    final editing = visualEditing;
    if (editing == null) return;
    visualLines[editing].content = visualEditController.text;
    visualSync();
  }

  void visualSelect(int index) {
    visualUpdate(() {
      visualCommitEditing();
      visualEditing = index;
      visualEditController.text = visualLines[index].content;
    });
  }

  void visualDeselect() {
    visualUpdate(() {
      visualCommitEditing();
      visualEditing = null;
    });
  }

  void visualMutate(void Function() change) {
    visualUpdate(() {
      visualCommitEditing();
      change();
    });
    visualSync();
  }

  void visualMove(int index, int delta) {
    final next = visualEdit.moveBy(index, delta);
    if (identical(next, visualEdit)) return;
    visualMutate(() {
      visualAdopt(next);
      visualEditController.text = visualLines[next.selected!].content;
    });
  }

  /// #822 — a drag: the element at [from] lands BEFORE the element at
  /// [before] (the drop target).
  void visualMoveBefore(int from, int before) {
    final next = visualEdit.moveBefore(from, before);
    if (identical(next, visualEdit)) return;
    visualMutate(() {
      visualAdopt(next);
      visualEditController.text = visualLines[next.selected!].content;
    });
  }

  void visualInsertBelow(int index, ReportLineKind kind) {
    visualMutate(() {
      visualAdopt(visualEdit.insertBelow(index, ReportVisualLine(kind, '')));
      visualEditController.text = '';
    });
  }

  void visualDelete(int index) {
    visualMutate(() => visualAdopt(visualEdit.remove(index)));
  }

  void visualSendTo(int index, String band) {
    final line = visualLines[index];
    visualMutate(() => visualAdopt(visualEdit.remove(index)));
    widget.onMoveToBand?.call(line, band);
  }

  /// Inserts [token] at the cursor of the active editor.
  void visualInsertToken(String token) {
    final selection = visualEditController.selection;
    final inserted = insertTokenAt(
      visualEditController.text,
      token,
      caret: selection.isValid ? selection.start : null,
    );
    visualEditController.text = inserted.text;
    visualEditController.selection =
        TextSelection.collapsed(offset: inserted.caret);
    visualCommitEditing();
    visualUpdate(() {});
  }

  Future<void> visualPickField() async {
    final markup =
        await showReportFieldPicker(context, textKeys: widget.textKeys);
    if (markup == null || !mounted) return;
    visualInsertToken(markup);
  }

  /// Groups the flat line list into render segments; a `:::` fence
  /// opens a column group, `|||` starts the next column.
  List<ReportSegment> visualSegments() {
    final segments = <ReportSegment>[];
    var i = 0;
    while (i < visualLines.length) {
      if (visualLines[i].kind == ReportLineKind.columnsFence) {
        final open = i;
        final columns = <List<int>>[[]];
        var j = i + 1;
        int? close;
        for (; j < visualLines.length; j++) {
          if (visualLines[j].kind == ReportLineKind.columnsFence) {
            close = j;
            break;
          }
          if (visualLines[j].kind == ReportLineKind.columnsSplit) {
            columns.add([]);
          } else {
            columns.last.add(j);
          }
        }
        segments.add(ReportGroupSegment(open, columns, close));
        i = close == null ? visualLines.length : close + 1;
      } else {
        segments.add(ReportLineSegment(i));
        i++;
      }
    }
    return segments;
  }

  /// Text with `{{ field }}` / `{% logic %}` rendered as TOKENS — the
  /// designer idiom for data fields. The token chrome is the ONLY
  /// deviation from print (#548): the surrounding text keeps the
  /// document's exact style, so the line's metrics stay honest.
  InlineSpan visualTokenized(String text, TextStyle style) {
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
  Widget visualStyledContent(ReportVisualLine line) {
    switch (line.kind) {
      case ReportLineKind.title:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(visualTokenized(line.content, ReportPage.heading)),
        );
      case ReportLineKind.section:
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 3),
          child: Text.rich(visualTokenized(
              line.content.toUpperCase(), ReportPage.subheading)),
        );
      case ReportLineKind.text:
        return Text.rich(visualTokenized(line.content, ReportPage.body));
      case ReportLineKind.small:
        return Text.rich(visualTokenized(line.content, ReportPage.small));
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
                if (c == 0) Expanded(
                        child:
                            Text.rich(visualTokenized(cells[c].trim(), style))) else Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text.rich(
                              visualTokenized(cells[c].trim(), style),
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
        final loaded = ref.watch(reportImageBytesProvider(image.name));
        final bytes = loaded.value;
        // #2586 — a read that failed is not a deleted image: say why, retry.
        if (loaded.hasError) {
          return ReportImageNotice(
            name: image.name,
            error: loaded.error!,
            onRetry: () => ref.invalidate(reportImageBytesProvider(image.name)),
          );
        }
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
        return Text(reportLineName(line.kind, context.l10n),
            style: const TextStyle(
                fontSize: 10, color: ReportPage.chrome));
    }
  }

  /// #822 — the image element's own controls: size and alignment,
  /// written back as `name|size|align`.
  Widget visualImageControls(int index, ReportVisualLine line) {
    final l10n = context.l10n;
    final image = line.image;
    void set({ReportImageSize? size, ReportImageAlign? align}) {
      final next = ReportImage(image.name,
          size: size ?? image.size, align: align ?? image.align);
      visualEditController.text = next.markup;
      visualMutate(() => line.content = next.markup);
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
              label: Text(l10n.reportImageSizeSmall),
            ),
            ButtonSegment(
              value: ReportImageSize.medium,
              label: Text(l10n.reportImageSizeMedium),
            ),
            ButtonSegment(
              value: ReportImageSize.large,
              label: Text(l10n.reportImageSizeLarge),
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
  Widget visualKindMenu({
    required Key key,
    required Widget child,
    required ValueChanged<ReportLineKind> onSelected,
    String? tooltip,
  }) {
    final l10n = context.l10n;
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
}
