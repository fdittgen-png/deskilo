// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the actions of the invoice report editor: undo/redo, document and
// language switching, layout and design files, save, preview and PDF, the
// markup and image inserts. Split out of invoice_template_sheet.dart (was a
// part file with an extension on the state); the state keeps the controllers
// and the drafts and says so here as abstract members.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/file_names.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/share/file_sharer.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
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
import 'invoice_template_sheet.dart' show ReportTemplateEditor;
import 'report_editor_dialogs.dart';
import 'report_image_picker.dart';
import 'report_layout_preview_dialog.dart';
import 'report_markup_guide.dart';
import 'report_page_designer.dart';
import 'report_preview.dart';
import 'report_template_toolbar.dart';
import 'template_live_data.dart';

mixin ReportTemplateEditorActions on ConsumerState<ReportTemplateEditor> {
  TextEditingController get editorHeader;
  TextEditingController get editorBody;
  TextEditingController get editorFooter;
  abstract bool editorBusy;
  ReportBands get editorCurrentBands;
  Map<String, String> get editorCurrentTexts;
  abstract GlobalKey<ReportPageDesignerState> editorDesignerKey;
  abstract bool editorDirty;
  abstract String editorDoc;
  Map<String, ReportBands> get editorDrafts;
  abstract TextEditingController? editorFocusedBand;
  ReportEditHistory get editorHistory;
  abstract String editorLang;
  Map<String, String> get editorLayoutDrafts;
  String? get editorLayoutOfDoc;
  int get editorReminderLevels;
  abstract bool editorRestoring;
  Map<String, Map<String, String>> get editorTextDrafts;
  void editorUpdate(VoidCallback fn);
  bool get editorVisual;
  abstract int editorVisualEpoch;


  Map<String, String> editorTextsFor(String lang) =>
      editorTextDrafts[lang] ??
      (lang.isEmpty
          ? widget.initial.texts
          : widget.initial.translations[lang]?.texts ?? const {});

  void editorSetTexts(Map<String, String> texts) => editorUpdate(() {
        editorTextDrafts[editorLang] = texts;
        editorDirty = true;
        editorBumpEpoch();
      });

  void editorBumpEpoch() {
    editorVisualEpoch++;
    editorDesignerKey = GlobalKey<ReportPageDesignerState>();
  }

  /// #822 — every controller change lands in the history (typing
  /// coalesces there); a structural change records as its own step.
  void editorRecord({bool step = false}) {
    if (editorRestoring) return;
    final before = editorHistory.length;
    editorHistory.push(editorCurrentBands, at: ref.read(clockProvider).now(), step: step);
    if (editorHistory.length != before || step) editorDirty = true;
    if (mounted) editorUpdate(() {});
  }

  void editorApply(ReportBands bands, {bool step = true}) {
    editorRestoring = true;
    editorHeader.text = bands.header;
    editorBody.text = bands.body;
    editorFooter.text = bands.footer;
    editorRestoring = false;
    editorUpdate(editorBumpEpoch);
    if (step) editorRecord(step: true);
  }

  void editorUndo() {
    if (!editorHistory.canUndo) return;
    final bands = editorHistory.undo();
    editorDirty = true;
    editorApply(bands, step: false);
  }

  void editorRedo() {
    if (!editorHistory.canRedo) return;
    final bands = editorHistory.redo();
    editorDirty = true;
    editorApply(bands, step: false);
  }


  /// The stored bands of document [doc] in the edited LANGUAGE, before
  /// any unsaved edit. In a language overlay, empty = inherits default.
  ReportBands editorStoredBands(String doc, {String? lang}) => editorStoredBandsOf(
      (lang ?? editorLang).isEmpty
          ? widget.initial
          : (widget.initial.translations[lang ?? editorLang] ??
              InvoicePdfTemplate.empty),
      doc);

  /// #864 — one registry answers this now. The switch this replaces
  /// fell through to "then it must be a reminder", so an unknown id
  /// silently edited level 1 instead of failing.
  ReportBands editorStoredBandsOf(InvoicePdfTemplate template, String doc) {
    final kind = reportKindById(doc, reminderLevels: editorReminderLevels);
    return kind == null ? ReportBands.empty : bandsOf(template, kind);
  }

  /// #822 — whether language [lang] carries its OWN bands for the
  /// current document (unsaved edits included).
  bool editorOverridden(String lang) => lang == editorLang
      ? editorCurrentBands.hasBands
      : (editorDrafts[reportDraftKey(lang, editorDoc)] ?? editorStoredBands(editorDoc, lang: lang))
          .hasBands;

  void editorSwitchDoc(String doc) {
    if (doc == editorDoc) return;
    editorDrafts[reportDraftKey(editorLang, editorDoc)] = editorCurrentBands;
    editorDoc = doc;
    editorApply(editorDrafts[reportDraftKey(editorLang, doc)] ?? editorStoredBands(doc), step: false);
  }

  /// #496 — switch the edited template LANGUAGE, keeping the document.
  void editorSwitchLang(String lang) {
    if (lang == editorLang) return;
    editorDrafts[reportDraftKey(editorLang, editorDoc)] = editorCurrentBands;
    editorLang = lang;
    editorApply(editorDrafts[reportDraftKey(lang, editorDoc)] ?? editorStoredBands(editorDoc),
        step: false);
  }

  /// The full template with every unsaved edit folded in (#496).
  InvoicePdfTemplate editorAssemble(int maxLevels) {
    editorDrafts[reportDraftKey(editorLang, editorDoc)] = editorCurrentBands;
    return assembleReportTemplate(
      stored: widget.initial,
      drafts: editorDrafts,
      layoutDrafts: editorLayoutDrafts,
      textDrafts: editorTextDrafts,
      reminderLevels: maxLevels,
    );
  }

  /// #864 — write the open design out. The file names the report it
  /// belongs to, so importing it into another one is refused rather
  /// than silently retargeted.
  Future<void> editorExportLayout() async {
    final kind = reportKindById(editorDoc, reminderLevels: editorReminderLevels);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final xml = editorLayoutOfDoc;
    if (kind == null || workspace == null || xml == null) return;
    await exportReportLayout(context, ref,
        kind: kind,
        language: editorLang,
        workspaceName: workspace.name,
        layoutXml: xml,
        texts: editorCurrentTexts,
        exportedAt: ref.read(clockProvider).now());
  }

  Future<void> editorImportLayout() async {
    final kind = reportKindById(editorDoc, reminderLevels: editorReminderLevels);
    if (kind == null) return;
    final file = await importReportLayout(context, ref,
        kind: kind, reminderLevels: editorReminderLevels);
    if (file == null || !mounted) return;
    editorUpdate(() {
      editorLayoutDrafts[editorDoc] = file.layoutXml;
      // #880 — the file's texts land on the language being edited.
      if (file.texts.isNotEmpty) {
        editorTextDrafts[editorLang] = {...editorTextsFor(editorLang), ...file.texts};
      }
    });
    AppSnack.success(context,
        context.l10n.reportLayoutImported);
  }

  Future<void> editorPreviewLayout() async {
    final xml = editorLayoutOfDoc;
    if (xml == null) return;
    await showLayoutQuickPreview(context, ref,
        layoutXml: xml,
        data: withOwnerTexts(
            liveReportData(context, ref, editorDoc) ?? sampleReportData(context.l10n),
            editorCurrentTexts));
  }

  Future<void> editorExportDesign() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    final kind = reportKindById(editorDoc, reminderLevels: editorReminderLevels);
    if (workspace == null || kind == null) return;
    await exportReportDesign(
      context,
      ref,
      kind: kind,
      language: editorLang,
      workspaceName: workspace.name,
      bands: editorCurrentBands,
      exportedAt: ref.read(clockProvider).now(),
    );
  }

  /// #864 — read one back into the document being edited. It lands in
  /// the editor, not in the workspace: nothing is stored until Save,
  /// which is what makes an import reviewable before it counts.
  Future<void> editorImportDesign() async {
    final l10n = context.l10n;
    final kind = reportKindById(editorDoc, reminderLevels: editorReminderLevels);
    if (kind == null) return;
    if (!await editorConfirmReplace() || !mounted) return;
    final bands = await importReportDesign(
      context,
      ref,
      kind: kind,
      reminderLevels: editorReminderLevels,
    );
    if (bands == null || !mounted) return;
    editorApply(bands);
    AppSnack.info(
        context,
        l10n.reportDesignImported);
  }

  Future<void> editorSave() async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final levels =
        (ref.read(dunningRulesProvider).value ?? DunningRules.defaults)
            .levels;
    editorUpdate(() => editorBusy = true);
    try {
      await ref
          .read(reportTemplateRepositoryProvider)
          .setInvoicePdfTemplate(workspace.id, editorAssemble(levels));
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'set invoice template failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      editorUpdate(() => editorBusy = false);
      AppSnack.error(
        context,
        l10n.workspaceGenericError,
      );
      return;
    }
    ref.invalidate(invoicePdfTemplateProvider);
    if (!mounted) return;
    editorDirty = false;
    Navigator.of(context).pop();
    AppSnack.info(
      context,
      l10n.invoiceTemplateSaved,
      replace: true,
    );
  }

  /// #822 — presets and reset REPLACE a layout: ask when there is one.
  Future<bool> editorConfirmReplace() async =>
      !editorCurrentBands.hasBands || await confirmReportReplace(context);

  /// INSTANT preview (#474): the report engine's output rendered as
  /// widgets — real newest-invoice data when one exists, simulated
  /// sample data otherwise. No PDF round-trip.

  Future<void> editorQuickPreview() async {
    final l10n = context.l10n;
    final live = liveReportData(context, ref, editorDoc);
    final simulated = live == null;
    final data = withOwnerTexts(live ?? sampleReportData(l10n), editorCurrentTexts);
    final bands = editorCurrentBands.hasBands
        ? editorCurrentBands
        : defaultBandsForDoc(editorDoc, l10n);
    final report = renderReportBands(bands: bands, data: data);
    final images = await resolveReportImages(ref, report);
    if (!mounted) return;
    if (report == null) {
      // #822 — the engine's own message, not a generic shrug.
      final why = reportBandsError(bands: bands, data: data) ?? '';
      AppSnack.error(
        context,
        l10n.reportDesignerError(why),
      );
      return;
    }
    await showReportQuickPreview(context,
        report: report, simulated: simulated, images: images);
  }

  /// Renders the selected DOCUMENT through the UNSAVED bands as a PDF —
  /// the invoice as a watermarked copy, a reminder as its letter — and
  /// either DOWNLOADS it or hands it to the share sheet (#474).
  Future<void> editorPdf({required bool download}) async {
    final l10n = context.l10n;
    final invoices = await ref.read(invoicesProvider.future);
    if (!mounted) return;
    if (invoices.isEmpty) {
      AppSnack.info(
        context,
        l10n.invoiceTemplateNoPreview,
        replace: true,
      );
      return;
    }
    final reference = workspaceTaxReference(ref);
    if (reference == null) {
      AppSnack.error(context, l10n.workspaceTaxContextNotReady, replace: true);
      return;
    }
    editorUpdate(() => editorBusy = true);
    try {
      final l10nSync = context.l10n;
      final ({List<int> bytes, String fileName}) pdf;
      if (editorDoc == 'invoice' || editorDoc == 'proforma') {
        final invoicePdf = await buildInvoicePdfFile(
          context,
          invoices.first, InvoicePdfFileOptions(reference: reference, proforma: editorDoc == 'proforma',
          copy: true,
          template: editorDoc == 'proforma'
              ? InvoicePdfTemplate(proforma: editorCurrentBands)
              : InvoicePdfTemplate(
                  header: editorCurrentBands.header,
                  body: editorCurrentBands.body,
                  footer: editorCurrentBands.footer,
                  // #872 — or the preview drops the page-2 strip.
                  continuation: editorCurrentBands.continuation,
                ),
          workspace: ref.read(currentWorkspaceProvider).value,
          reportImage: (name) =>
              ref.read(reportImageBytesProvider(name).future)));
        pdf = (bytes: invoicePdf.bytes, fileName: invoicePdf.fileName);
      } else if (editorDoc == 'statement' ||
          reportKindById(editorDoc, reminderLevels: editorReminderLevels)?.slot
              is ReportDocSlot) {
        // The letter documents: my own live data, or the sample.
        final data = withOwnerTexts(
            liveReportData(context, ref, editorDoc) ?? sampleReportData(l10nSync), editorCurrentTexts);
        final bands = editorCurrentBands.hasBands
            ? editorCurrentBands
            : defaultBandsForDoc(editorDoc, l10nSync);
        final report = renderReportBands(bands: bands, data: data) ??
            renderReportBands(
                bands: defaultBandsForDoc(editorDoc, l10nSync), data: data)!;
        Future<pw.Font> font(String asset) async =>
            pw.Font.ttf(await rootBundle.load(asset));
        final bytes = await buildBandedLetterPdf(
          report: report,
          reportImages: await resolveReportImages(ref, report),
          pageLabel: l10nSync.invoicePdfPage,
          documentTitle: l10nSync.billPdfTitle,
          baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
          boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
        );
        pdf = (
          bytes: bytes,
          fileName:
              '${safeFileSlug(l10nSync.billPdfTitle)}.pdf',
        );
      } else {
        final letter = await buildReminderPdfFile(
          context,
          ref,
          invoices.first,
          level: int.tryParse(editorDoc.substring(1)) ?? 1,
          draftBands: editorCurrentBands,
          reference: reference,
        );
        pdf = (bytes: letter.bytes, fileName: letter.fileName);
      }
      if (!mounted) return;
      if (download) {
        await savePdfToDownloads(
          context,
          ref,
          bytes: Uint8List.fromList(pdf.bytes),
          fileName: pdf.fileName,
        );
      } else {
        await ref.read(fileSharerProvider)(
          bytes: Uint8List.fromList(pdf.bytes),
          fileName: pdf.fileName,
          mimeType: 'application/pdf',
        );
      }
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'template pdf failed',
          error: e, stackTrace: st);
      if (mounted) {
        AppSnack.error(
          context,
          l10n.workspaceGenericError,
        );
      }
    } finally {
      if (mounted) editorUpdate(() => editorBusy = false);
    }
  }

  Future<void> editorInsertImage() async {
    final name = await showReportImagePicker(context, ref);
    if (name == null || !mounted) return;
    final designer = editorDesignerKey.currentState;
    if (editorVisual && designer != null) {
      // #822 — after the selected element, or at the header's end.
      designer.insertImage(name);
      return;
    }
    // Appended to the band a logo most likely belongs to; move it
    // anywhere afterwards.
    editorHeader.text =
        editorHeader.text.isEmpty ? '![$name]' : '${editorHeader.text}\n![$name]';
    editorUpdate(editorBumpEpoch);
  }

  void editorInsertMarkup(String markup) {
    final controller = editorFocusedBand ?? editorHeader;
    controller.value = insertMarkupAt(controller.value, markup);
  }

  /// #864 — the chips come from the registry, so a report kind added
  /// there appears here without this list being remembered.
  List<(String, String)> editorDocs(AppLocalizations l10n) => [
        for (final kind in reportKinds(reminderLevels: editorReminderLevels))
          (kind.id, reportKindLabel(l10n, kind)),
      ];

  Widget editorEditorArea(AppLocalizations l10n, {required bool sideBySide}) {
    if (editorVisual) {
      // #548 — the page-true design surface: one A4 page, the
      // document's margins, band strips, page-break guides, zoom, and
      // a Design ↔ Preview toggle (or both pages at once — #822).
      return ReportPageDesigner(
        key: editorDesignerKey,
        header: editorHeader,
        body: editorBody,
        footer: editorFooter,
        headerLabel: l10n.invoiceTemplateHeaderLabel,
        bodyLabel: l10n.invoiceTemplateBodyLabel,
        footerLabel: l10n.invoiceTemplateFooterLabel,
        editorKeyPrefix: 'visual-$editorDoc-$editorVisualEpoch',
        previewData: () =>
            withOwnerTexts(liveReportData(context, ref, editorDoc) ?? sampleReportData(l10n), editorCurrentTexts),
        textKeys: editorCurrentTexts.keys.toList(),
        sideBySide: sideBySide,
      );
    }
    return ReportMarkupBands(
      header: editorHeader,
      body: editorBody,
      footer: editorFooter,
      onFocus: (band) => editorFocusedBand = band,
    );
  }
}
