// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/file_names.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/page_spec.dart';
import '../../../../core/share/file_sharer.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/dunning.dart';
import '../../domain/invoice_pdf.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/invoice_report.dart';
import '../../domain/report_kind.dart';
import '../../domain/report_template_assembly.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../invoice_documents.dart';
import '../report_defaults.dart';
import '../report_design_actions.dart';
import '../report_edit_history.dart';
import '../report_kind_labels.dart';
import '../report_layout_design_actions.dart';
import '../screens/report_editor_screen.dart';
import 'report_editor_dialogs.dart';
import 'report_history_controls.dart';
import 'report_image_picker.dart';
import 'report_layout_panel.dart';
import 'report_layout_preview_dialog.dart';
import 'report_markup_guide.dart';
import 'report_page_designer.dart';
import 'report_preview.dart';
import 'report_template_toolbar.dart';
import 'report_texts_panel.dart';
import 'template_live_data.dart';

part 'invoice_template_sheet_part1.dart';

/// The invoice REPORT editor (#454, rebuilt as a banded reporting tool
/// in #470): three Liquid bands — header, body with the lines, footer —
/// with a syntax cheat-sheet, a reset to the built-in layout as a
/// working starting point, and a live preview (rendered as a COPY of
/// the newest invoice through the UNSAVED bands). The sheet says the
/// one thing an owner must never misread: this edits the PDF only,
/// never the legal XML.
///
/// #822 — with `reportDesigner` on, the editor is a full-screen ROUTE
/// (`/report-editor`) rather than a sheet; the same widget serves both.
Future<void> showInvoiceTemplateSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  if (ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.reportDesigner)) {
    // The route when a router is there (deep-linkable); the same page
    // where the editor is hosted without one.
    await openLocation<void>(
      context,
      '/report-editor',
      orBuild: (_) => const ReportEditorScreen(),
    );
    return;
  }
  final template = await ref.read(invoicePdfTemplateProvider.future);
  if (!context.mounted) return;
  await showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ReportTemplateEditor(initial: template),
  );
}

/// The template editor itself — the sheet's content, or (#822) the
/// whole page with a toolbar, undo/redo, a discard guard and, on a wide
/// screen, design and preview side by side.
class ReportTemplateEditor extends ConsumerStatefulWidget {
  const ReportTemplateEditor({
    super.key,
    required this.initial,
    this.asPage = false,
  });

  final InvoicePdfTemplate initial;
  final bool asPage;

  @override
  ConsumerState<ReportTemplateEditor> createState() =>
      _ReportTemplateEditorState();
}

class _ReportTemplateEditorState extends ConsumerState<ReportTemplateEditor> {
  late final TextEditingController _header;
  late final TextEditingController _body;
  late final TextEditingController _footer;
  bool _busy = false;

  /// The document being edited (#472/#476): 'invoice', 'proforma',
  /// 'statement', or 'rN' for reminder level N — every one its own
  /// report.
  String _doc = 'invoice';

  /// #488 — WYSIWYG mode: the bands as typed, reorderable rows instead
  /// of raw markup. Both modes edit the SAME controllers. #822 — the
  /// page opens in it.
  late bool _visual = widget.asPage;

  /// Bumped whenever the controllers change from OUTSIDE the visual
  /// editors (doc switch, preset, reset, undo) — recreates them so
  /// they re-seed from the new text.
  int _visualEpoch = 0;

  /// The TEMPLATE language being edited (#496): '' = the default
  /// template every language falls back to; a language code edits that
  /// language's overlay (empty bands = inherit the default).
  String _lang = '';

  /// Unsaved edits per language|document, so switching loses nothing.
  final Map<String, ReportBands> _drafts = {};

  /// #875 — positioned layouts edited this session, by kind id; ''
  /// means "remove, fall back to the bands". Saved with the bands.
  final Map<String, String> _layoutDrafts = {};

  /// #880 — the owner's texts per language ('' = the default language),
  /// edited in the Texts panel; absent = untouched, read from the
  /// stored template.
  final Map<String, Map<String, String>> _textDrafts = {};

  /// #822 — one undo history per language|document.
  final Map<String, ReportEditHistory> _histories = {};

  /// True while undo/redo/switch writes the controllers, so the
  /// listener does not record the restore as an edit.
  bool _restoring = false;

  /// #822 — whether anything changed since open or the last save.
  bool _dirty = false;

  /// Renewed with every epoch: a fresh key makes the designer (and its
  /// band editors) re-seed from the controllers after a reset, preset,
  /// undo or switch — a kept GlobalKey would carry the old state over.
  var _designerKey = GlobalKey<ReportPageDesignerState>();

  @override
  void initState() {
    super.initState();
    _header = TextEditingController(text: widget.initial.header);
    _body = TextEditingController(text: widget.initial.body);
    _footer = TextEditingController(text: widget.initial.footer);
    for (final c in [_header, _body, _footer]) {
      c.addListener(_record);
    }
  }

  @override
  void dispose() {
    _header.dispose();
    _body.dispose();
    _footer.dispose();
    super.dispose();
  }

  /// #966 — the band last edited, where the guide inserts; the header
  /// until one is touched.
  TextEditingController? _focusedBand;

  /// What `{{ text.<key> }}` resolves to in the language being edited:
  /// the default language's texts, the overlay's non-empty ones on top.
  Map<String, String> get _currentTexts => {
        ..._textsFor(''),
        if (_lang.isNotEmpty)
          for (final e in _textsFor(_lang).entries)
            if (e.value.isNotEmpty) e.key: e.value,
      };

  String? get _layoutOfDoc {
    final draft = _layoutDrafts[_doc];
    if (draft != null) return draft.isEmpty ? null : draft;
    return widget.initial.layoutFor(_doc);
  }

  ReportBands get _currentBands => ReportBands(
        header: _header.text.trim(),
        body: _body.text.trim(),
        footer: _footer.text.trim(),
      );

  ReportEditHistory get _history => _histories.putIfAbsent(
        reportDraftKey(_lang, _doc),
        () => ReportEditHistory(_storedBands(_doc)),
      );

  /// The reminder levels this workspace has configured; 0 when dunning
  /// is off, and then the reminder kinds simply do not exist.
  int get _reminderLevels =>
      ref.read(enabledFeaturesSyncProvider).contains(WorkspaceFeature.dunning)
          ? (ref.read(dunningRulesProvider).value ?? DunningRules.defaults)
              .levels
          : 0;

  // #2386 — the operations; each body is in a part file.
  @override Widget build(BuildContext context) => _buildImpl(context);

  /// Lets the section extensions rebuild (setState is protected).
  void _update(VoidCallback fn) => setState(fn);

  Widget _buildImpl(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final wide = widget.asPage && MediaQuery.sizeOf(context).width >= 1000;
    final designExchange = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.reportDesignExchange);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.asPage)
          Row(
            children: [
              Text(
                l10n.invoiceTemplateTitle,
                style: theme.textTheme.titleMedium,
              ),
              HelpDot(l10n.helpTopicReportEditor,
                anchor: HelpAnchor.reportsInvoiceTemplate,
              ),
            ],
          ),
        const SizedBox(height: 4),
        // #966 — the markup mode's guide: grouped fields with their
        // meaning, the line markup one sign per row, three ready-made
        // pieces, everything inserted at the caret. Collapsed until
        // asked for; the designer carries the fields in its own picker.
        if (!_visual)
          ReportMarkupGuide(
            textKeys: _currentTexts.keys.toList(),
            onInsert: _insertMarkup,
          ),
        const SizedBox(height: AppSpacing.sm),
        // #496 — one template per LANGUAGE: the default, plus an
        // overlay per language for readers in that language.
        ReportTemplateLanguageChips(
          selected: _lang,
          overridden: _overridden,
          canClear: _currentBands.hasBands,
          onSelect: _switchLang,
          onClear: () => _apply(ReportBands.empty),
        ),
        const SizedBox(height: AppSpacing.xs),
        // #472: one report per DOCUMENT — the invoice, and every
        // reminder level of the dunning rules.
        ReportTemplateDocChips(
          docs: _docs(l10n),
          selected: _doc,
          onSelect: _switchDoc,
        ),
        const SizedBox(height: AppSpacing.sm),
        // #488 — markup or WYSIWYG, same underlying bands.
        SegmentedButton<bool>(
          key: const ValueKey('invoice-template-mode'),
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.code),
              label: Text(l10n.reportEditorMarkup),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.design_services_outlined),
              label: Text(l10n.reportEditorVisual),
            ),
          ],
          selected: {_visual},
          onSelectionChanged: (selection) => _update(() {
            _visual = selection.first;
            _bumpEpoch();
          }),
        ),
        _editorArea(l10n, sideBySide: wide),
        const SizedBox(height: AppSpacing.md),
        // #474: pick a ready-made report, see it INSTANTLY, then
        // download or share the PDF — or save the bands.
        ReportTemplateActions(
          doc: _doc,
          busy: _busy,
          showSave: !widget.asPage,
          onPreset: (preset) async {
            if (!await _confirmReplace() || !mounted) return;
            _apply(preset.bands);
          },
          onInsertImage: _insertImage,
          onQuickPreview: _quickPreview,
          onPdf: (download) => _pdf(download: download),
          onReset: () async {
            if (!await _confirmReplace() || !mounted) return;
            _apply(defaultBandsForDoc(
                _doc, _lang.isEmpty ? l10n : l10nForLanguage(_lang)));
          },
          onSave: _save,
          // #864 — the design exchange, when the workspace has it.
          onExportDesign: designExchange ? _exportDesign : null,
          onImportDesign: designExchange ? _importDesign : null,
        ),
        // #875 — last in the column on purpose: the panel adds height
        // below every existing control, and moves none of them.
        if (ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.reportLayouts)) ...[
          const SizedBox(height: AppSpacing.sm),
          ReportLayoutPanel(
            hasLayout: _layoutOfDoc != null,
            busy: _busy,
            onExport: _exportLayout,
            onImport: _importLayout,
            onRemove: () => _update(() => _layoutDrafts[_doc] = ''),
            onPreview: _previewLayout,
          ),
        ],
        // #880 — the owner's texts, after the layout panel for the same
        // reason: nothing above moves.
        if (ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.reportTexts)) ...[
          const SizedBox(height: AppSpacing.sm),
          ReportTextsPanel(
            key: ValueKey('report-texts-$_lang'),
            language: _lang,
            texts: _textsFor(_lang),
            inherited: _lang.isEmpty ? const {} : _textsFor(''),
            onChanged: _setTexts,
          ),
        ],
      ],
    );
    if (!widget.asPage) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: content,
        ),
      );
    }
    // #822 — the page: a toolbar with undo / redo / save, the same
    // content underneath, and a guard on the way out.
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmReportDiscard(context);
        if (leave && mounted) Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          // #1180 — the screen's own name was cut to "Report e…". The
          // help symbol sat INSIDE the title, taking 48 dp of it plus the
          // title's leading spacing, while every other screen puts its
          // help dot in the actions. Moved there, the title has room and
          // the app is one shape less inconsistent.
          title: Text(l10n.reportEditorTitle,
              overflow: TextOverflow.ellipsis),
          actions: [
            HelpDot(l10n.helpTopicReportEditor,
              anchor: HelpAnchor.reportsEditor,
            ),
            ReportHistoryControls(
              canUndo: _history.canUndo && !_busy,
              canRedo: _history.canRedo && !_busy,
              onUndo: _undo,
              onRedo: _redo,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: FilledButton(
                key: const ValueKey('invoice-template-save'),
                onPressed: _busy ? null : _save,
                child: Text(l10n.commonSave),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.sm,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
