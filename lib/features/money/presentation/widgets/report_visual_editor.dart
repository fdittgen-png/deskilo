// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/edge_fade_scroll.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/invoice_report.dart';
import '../../providers/money_providers.dart';
import 'report_field_picker.dart';
import 'report_page_style.dart';

part 'report_visual_editor_part1.dart';
part 'report_visual_editor_part2.dart';

part 'report_visual_editor_part3.dart';


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

}
