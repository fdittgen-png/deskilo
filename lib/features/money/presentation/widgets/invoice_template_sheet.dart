// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/page_spec.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/report_template_assembly.dart';
import '../../providers/money_providers.dart';
import '../invoice_documents.dart';
import '../report_defaults.dart';
import '../report_edit_history.dart';
import '../screens/report_editor_screen.dart';
import 'invoice_template_editor_actions.dart';
import 'report_editor_dialogs.dart';
import 'report_history_controls.dart';
import 'report_layout_panel.dart';
import 'report_markup_guide.dart';
import 'report_page_designer.dart';
import 'report_template_toolbar.dart';
import 'report_texts_panel.dart';


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

class _ReportTemplateEditorState extends ConsumerState<ReportTemplateEditor>
    with ReportTemplateEditorActions {
  @override
  late final TextEditingController editorHeader;
  @override
  late final TextEditingController editorBody;
  @override
  late final TextEditingController editorFooter;
  @override
  bool editorBusy = false;

  /// The document being edited (#472/#476): 'invoice', 'proforma',
  /// 'statement', or 'rN' for reminder level N — every one its own
  /// report.
  @override
  String editorDoc = 'invoice';

  /// #488 — WYSIWYG mode: the bands as typed, reorderable rows instead
  /// of raw markup. Both modes edit the SAME controllers. #822 — the
  /// page opens in it.
  @override
  late bool editorVisual = widget.asPage;

  /// Bumped whenever the controllers change from OUTSIDE the visual
  /// editors (doc switch, preset, reset, undo) — recreates them so
  /// they re-seed from the new text.
  @override
  int editorVisualEpoch = 0;

  /// The TEMPLATE language being edited (#496): '' = the default
  /// template every language falls back to; a language code edits that
  /// language's overlay (empty bands = inherit the default).
  @override
  String editorLang = '';

  /// Unsaved edits per language|document, so switching loses nothing.
  @override
  final Map<String, ReportBands> editorDrafts = {};

  /// #875 — positioned layouts edited this session, by kind id; ''
  /// means "remove, fall back to the bands". Saved with the bands.
  @override
  final Map<String, String> editorLayoutDrafts = {};

  /// #880 — the owner's texts per language ('' = the default language),
  /// edited in the Texts panel; absent = untouched, read from the
  /// stored template.
  @override
  final Map<String, Map<String, String>> editorTextDrafts = {};

  /// #822 — one undo history per language|document.
  final Map<String, ReportEditHistory> _histories = {};

  /// True while undo/redo/switch writes the controllers, so the
  /// listener does not record the restore as an edit.
  @override
  bool editorRestoring = false;

  /// #822 — whether anything changed since open or the last save.
  @override
  bool editorDirty = false;

  /// Renewed with every epoch: a fresh key makes the designer (and its
  /// band editors) re-seed from the controllers after a reset, preset,
  /// undo or switch — a kept GlobalKey would carry the old state over.
  @override
  GlobalKey<ReportPageDesignerState> editorDesignerKey =
      GlobalKey<ReportPageDesignerState>();

  @override
  void initState() {
    super.initState();
    editorHeader = TextEditingController(text: widget.initial.header);
    editorBody = TextEditingController(text: widget.initial.body);
    editorFooter = TextEditingController(text: widget.initial.footer);
    for (final c in [editorHeader, editorBody, editorFooter]) {
      c.addListener(editorRecord);
    }
  }

  @override
  void dispose() {
    editorHeader.dispose();
    editorBody.dispose();
    editorFooter.dispose();
    super.dispose();
  }

  /// #966 — the band last edited, where the guide inserts; the header
  /// until one is touched.
  @override
  TextEditingController? editorFocusedBand;

  /// What `{{ text.<key> }}` resolves to in the language being edited:
  /// the default language's texts, the overlay's non-empty ones on top.
  @override
  Map<String, String> get editorCurrentTexts => {
        ...editorTextsFor(''),
        if (editorLang.isNotEmpty)
          for (final e in editorTextsFor(editorLang).entries)
            if (e.value.isNotEmpty) e.key: e.value,
      };

  @override
  String? get editorLayoutOfDoc {
    final draft = editorLayoutDrafts[editorDoc];
    if (draft != null) return draft.isEmpty ? null : draft;
    return widget.initial.layoutFor(editorDoc);
  }

  @override
  ReportBands get editorCurrentBands => ReportBands(
        header: editorHeader.text.trim(),
        body: editorBody.text.trim(),
        footer: editorFooter.text.trim(),
      );

  @override
  ReportEditHistory get editorHistory => _histories.putIfAbsent(
        reportDraftKey(editorLang, editorDoc),
        () => ReportEditHistory(editorStoredBands(editorDoc)),
      );

  /// The reminder levels this workspace has configured; 0 when dunning
  /// is off, and then the reminder kinds simply do not exist.
  @override
  int get editorReminderLevels =>
      ref.read(enabledFeaturesSyncProvider).contains(WorkspaceFeature.dunning)
          ? ref.read(dunningRulesProvider).requireValue.levels
          : 0;

  /// Lets the section extensions rebuild (setState is protected).
  @override
  void editorUpdate(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
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
    return _page(context, content);
  }

  /// The editor itself, the same in the sheet and on the page.
  Widget _content(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final wide = widget.asPage && MediaQuery.sizeOf(context).width >= 1000;
    return Column(
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
        if (!editorVisual)
          ReportMarkupGuide(
            textKeys: editorCurrentTexts.keys.toList(),
            onInsert: editorInsertMarkup,
          ),
        const SizedBox(height: AppSpacing.sm),
        // #496 — one template per LANGUAGE: the default, plus an
        // overlay per language for readers in that language.
        ReportTemplateLanguageChips(
          selected: editorLang,
          overridden: editorOverridden,
          canClear: editorCurrentBands.hasBands,
          onSelect: editorSwitchLang,
          onClear: () => editorApply(ReportBands.empty),
        ),
        const SizedBox(height: AppSpacing.xs),
        // #472: one report per DOCUMENT — the invoice, and every
        // reminder level of the dunning rules.
        ReportTemplateDocChips(
          docs: editorDocs(l10n),
          selected: editorDoc,
          onSelect: editorSwitchDoc,
        ),
        const SizedBox(height: AppSpacing.sm),
        // #488 — markup or WYSIWYG, same underlying bands.
        _modeButton(l10n),
        editorEditorArea(l10n, sideBySide: wide),
        const SizedBox(height: AppSpacing.md),
        ..._actionsAndPanels(l10n),
      ],
    );
  }

  Widget _modeButton(AppLocalizations l10n) =>
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
        selected: {editorVisual},
        onSelectionChanged: (selection) => editorUpdate(() {
          editorVisual = selection.first;
          editorBumpEpoch();
        }),
      );

  /// The ready-made reports and the PDF, then the layout and texts panels
  /// where the workspace has them.
  List<Widget> _actionsAndPanels(AppLocalizations l10n) {
    final features = ref.watch(enabledFeaturesSyncProvider);
    final designExchange =
        features.contains(WorkspaceFeature.reportDesignExchange);
    return [
      // #474: pick a ready-made report, see it INSTANTLY, then
      // download or share the PDF — or save the bands.
      ReportTemplateActions(
        doc: editorDoc,
        busy: editorBusy,
        showSave: !widget.asPage,
        onPreset: (preset) async {
          if (!await editorConfirmReplace() || !mounted) return;
          editorApply(preset.bands);
        },
        onInsertImage: editorInsertImage,
        onQuickPreview: editorQuickPreview,
        onPdf: (download) => editorPdf(download: download),
        onReset: () async {
          if (!await editorConfirmReplace() || !mounted) return;
          editorApply(defaultBandsForDoc(
              editorDoc, editorLang.isEmpty ? l10n : l10nForLanguage(editorLang)));
        },
        onSave: editorSave,
        // #864 — the design exchange, when the workspace has it.
        onExportDesign: designExchange ? editorExportDesign : null,
        onImportDesign: designExchange ? editorImportDesign : null,
      ),
      // #875 — last in the column on purpose: the panel adds height
      // below every existing control, and moves none of them.
      if (features.contains(WorkspaceFeature.reportLayouts)) ...[
        const SizedBox(height: AppSpacing.sm),
        ReportLayoutPanel(
          hasLayout: editorLayoutOfDoc != null,
          busy: editorBusy,
          onExport: editorExportLayout,
          onImport: editorImportLayout,
          onRemove: () => editorUpdate(() => editorLayoutDrafts[editorDoc] = ''),
          onPreview: editorPreviewLayout,
        ),
      ],
      // #880 — the owner's texts, after the layout panel for the same
      // reason: nothing above moves.
      if (features.contains(WorkspaceFeature.reportTexts)) ...[
        const SizedBox(height: AppSpacing.sm),
        ReportTextsPanel(
          key: ValueKey('report-texts-$editorLang'),
          language: editorLang,
          texts: editorTextsFor(editorLang),
          inherited: editorLang.isEmpty ? const {} : editorTextsFor(''),
          onChanged: editorSetTexts,
        ),
      ],
    ];
  }

  Widget _page(BuildContext context, Widget content) {
    final l10n = context.l10n;
    // #822 — the page: a toolbar with undo / redo / save, the same
    // content underneath, and a guard on the way out.
    return PopScope(
      canPop: !editorDirty,
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
              canUndo: editorHistory.canUndo && !editorBusy,
              canRedo: editorHistory.canRedo && !editorBusy,
              onUndo: editorUndo,
              onRedo: editorRedo,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: FilledButton(
                key: const ValueKey('invoice-template-save'),
                onPressed: editorBusy ? null : editorSave,
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
