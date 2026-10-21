// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'report_visual_editor.dart';

// #2386 — part 1 of ReportVisualEditorState, split out of report_visual_editor.dart so no
// file holds the whole class.
extension _ReportVisualEditorStatePart1 on ReportVisualEditorState {

  /// #822 — whether an element is selected here (the host inserts an
  /// image after the selection of the band that has one).
  bool get _hasSelectionImpl => _editing != null;

  /// #822 — inserts [line] after the selection, or at the end.
  void _insertLineImpl(ReportVisualLine line) {
    _mutate(() {
      _adopt(_edit.insertAfterSelection(line));
      _editController.text = line.content;
    });
  }

  /// The elements and the selection as the package's value.
  ElementEdit<ReportVisualLine> get _edit =>
      ElementEdit(_lines, selected: _editing);

  /// Takes the package's result as this editor's lines and selection.
  void _adopt(ElementEdit<ReportVisualLine> next) {
    _lines = List.of(next.items);
    _editing = next.selected;
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
    _update(() {
      _commitEditing();
      _editing = index;
      _editController.text = _lines[index].content;
    });
  }

  void _deselect() {
    _update(() {
      _commitEditing();
      _editing = null;
    });
  }

  void _mutate(void Function() change) {
    _update(() {
      _commitEditing();
      change();
    });
    _sync();
  }

  void _move(int index, int delta) {
    final next = _edit.moveBy(index, delta);
    if (identical(next, _edit)) return;
    _mutate(() {
      _adopt(next);
      _editController.text = _lines[next.selected!].content;
    });
  }

  /// #822 — a drag: the element at [from] lands BEFORE the element at
  /// [before] (the drop target).
  void _moveBefore(int from, int before) {
    final next = _edit.moveBefore(from, before);
    if (identical(next, _edit)) return;
    _mutate(() {
      _adopt(next);
      _editController.text = _lines[next.selected!].content;
    });
  }

  void _insertBelow(int index, ReportLineKind kind) {
    _mutate(() {
      _adopt(_edit.insertBelow(index, ReportVisualLine(kind, '')));
      _editController.text = '';
    });
  }

  void _delete(int index) {
    _mutate(() => _adopt(_edit.remove(index)));
  }

  void _sendTo(int index, String band) {
    final line = _lines[index];
    _mutate(() => _adopt(_edit.remove(index)));
    widget.onMoveToBand?.call(line, band);
  }

  /// Inserts [token] at the cursor of the active editor.
  void _insertToken(String token) {
    final selection = _editController.selection;
    final inserted = insertTokenAt(
      _editController.text,
      token,
      caret: selection.isValid ? selection.start : null,
    );
    _editController.text = inserted.text;
    _editController.selection =
        TextSelection.collapsed(offset: inserted.caret);
    _commitEditing();
    _update(() {});
  }

  Future<void> _pickField() async {
    final markup =
        await showReportFieldPicker(context, textKeys: widget.textKeys);
    if (markup == null || !mounted) return;
    _insertToken(markup);
  }

  /// Groups the flat line list into render segments; a `:::` fence
  /// opens a column group, `|||` starts the next column.
  List<ReportSegment> _segments() {
    final segments = <ReportSegment>[];
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
        segments.add(ReportGroupSegment(open, columns, close));
        i = close == null ? _lines.length : close + 1;
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
                if (c == 0) Expanded(
                        child:
                            Text.rich(_tokenized(cells[c].trim(), style))) else Flexible(
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
  Widget _imageControls(int index, ReportVisualLine line) {
    final l10n = context.l10n;
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
  Widget _kindMenu({
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
