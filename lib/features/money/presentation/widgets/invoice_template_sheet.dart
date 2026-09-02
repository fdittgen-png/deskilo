// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_dot.dart';
import '../../../../core/share/file_sharer.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/files/file_names.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/dunning.dart';
import '../../domain/invoice_pdf.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/invoice_report.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../report_defaults.dart';
import '../report_edit_history.dart';
import '../screens/report_editor_screen.dart';
import 'report_image_picker.dart';
import 'report_page_designer.dart';
import 'report_preview.dart';

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
    // The route when a router is there (deep-linkable); a plain page
    // push where the editor is hosted without one.
    if (GoRouter.maybeOf(context) != null) {
      await context.push('/report-editor');
    } else {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const ReportEditorScreen(),
      ));
    }
    return;
  }
  final template = await ref.read(invoicePdfTemplateProvider.future);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
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

  static const List<String> _templateLanguages = [
    'en',
    'fr',
    'de',
    'es',
    'it',
  ];

  /// Unsaved edits per language|document, so switching loses nothing.
  final Map<String, ReportBands> _drafts = {};

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

  void _bumpEpoch() {
    _visualEpoch++;
    _designerKey = GlobalKey<ReportPageDesignerState>();
  }

  String _draftKey(String lang, String doc) =>
      lang.isEmpty ? doc : '$lang|$doc';

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

  ReportBands get _currentBands => ReportBands(
        header: _header.text.trim(),
        body: _body.text.trim(),
        footer: _footer.text.trim(),
      );

  ReportEditHistory get _history => _histories.putIfAbsent(
        _draftKey(_lang, _doc),
        () => ReportEditHistory(_storedBands(_doc)),
      );

  /// #822 — every controller change lands in the history (typing
  /// coalesces there); a structural change records as its own step.
  void _record({bool step = false}) {
    if (_restoring) return;
    final before = _history.length;
    _history.push(_currentBands, at: ref.read(clockProvider).now(), step: step);
    if (_history.length != before || step) _dirty = true;
    if (mounted) setState(() {});
  }

  void _apply(ReportBands bands, {bool step = true}) {
    _restoring = true;
    _header.text = bands.header;
    _body.text = bands.body;
    _footer.text = bands.footer;
    _restoring = false;
    setState(_bumpEpoch);
    if (step) _record(step: true);
  }

  void _undo() {
    if (!_history.canUndo) return;
    final bands = _history.undo();
    _dirty = true;
    _apply(bands, step: false);
  }

  void _redo() {
    if (!_history.canRedo) return;
    final bands = _history.redo();
    _dirty = true;
    _apply(bands, step: false);
  }

  /// The extra documents the editor offers beside the classics (#494).
  static const List<String> _extraDocs = [
    'agreement',
    'payments',
    'workspace',
    // #672 — the chart-of-accounts PREVIEW. A report rather than a
    // screen, so the owner can hand the printed page to their
    // accountant and ask "is this your chart?".
    'coa',
    // #672 — batch prints join report management instead of living as
    // two hard-coded PDFs: badges and space QR cards are documents the
    // owner prints repeatedly, so they belong where every other
    // printable is edited.
    'badges',
    'space_codes',
  ];

  /// The stored bands of document [doc] in the edited LANGUAGE, before
  /// any unsaved edit. In a language overlay, empty = inherits default.
  ReportBands _storedBands(String doc, {String? lang}) => _storedBandsOf(
      (lang ?? _lang).isEmpty
          ? widget.initial
          : (widget.initial.translations[lang ?? _lang] ??
              InvoicePdfTemplate.empty),
      doc);

  ReportBands _storedBandsOf(InvoicePdfTemplate template, String doc) =>
      switch (doc) {
        'invoice' => template.invoiceBands,
        'proforma' => template.proforma,
        'statement' => template.statement,
        'agreement' ||
        'payments' ||
        'workspace' ||
        'coa' ||
        'badges' ||
        'space_codes' =>
          template.extraDocs[doc] ?? ReportBands.empty,
        _ => template
                .reminderBands(int.tryParse(doc.substring(1)) ?? 1) ??
            ReportBands.empty,
      };

  /// #822 — whether language [lang] carries its OWN bands for the
  /// current document (unsaved edits included).
  bool _overridden(String lang) => lang == _lang
      ? _currentBands.hasBands
      : (_drafts[_draftKey(lang, _doc)] ?? _storedBands(_doc, lang: lang))
          .hasBands;

  void _switchDoc(String doc) {
    if (doc == _doc) return;
    _drafts[_draftKey(_lang, _doc)] = _currentBands;
    _doc = doc;
    _apply(_drafts[_draftKey(_lang, doc)] ?? _storedBands(doc), step: false);
  }

  /// #496 — switch the edited template LANGUAGE, keeping the document.
  void _switchLang(String lang) {
    if (lang == _lang) return;
    _drafts[_draftKey(_lang, _doc)] = _currentBands;
    _lang = lang;
    _apply(_drafts[_draftKey(lang, _doc)] ?? _storedBands(_doc),
        step: false);
  }

  /// The full template with every unsaved edit folded in — the default
  /// bands plus one overlay per edited language (#496).
  InvoicePdfTemplate _assemble(int maxLevels) {
    _drafts[_draftKey(_lang, _doc)] = _currentBands;
    final invoice = _drafts['invoice'] ?? widget.initial.invoiceBands;
    var template = InvoicePdfTemplate(
      header: invoice.header,
      body: invoice.body,
      footer: invoice.footer,
      reminders: widget.initial.reminders,
      proforma: _drafts['proforma'] ?? widget.initial.proforma,
      statement: _drafts['statement'] ?? widget.initial.statement,
      extraDocs: widget.initial.extraDocs,
    );
    for (var level = 1; level <= maxLevels; level++) {
      final bands = _drafts['r$level'];
      if (bands != null) template = template.withReminder(level, bands);
    }
    for (final doc in _extraDocs) {
      final bands = _drafts[doc];
      if (bands != null) template = template.withDoc(doc, bands);
    }
    // #496 — fold every edited language overlay in.
    for (final lang in _templateLanguages) {
      var overlay =
          widget.initial.translations[lang] ?? InvoicePdfTemplate.empty;
      var touched = widget.initial.translations.containsKey(lang);
      void apply(String doc, ReportBands bands) {
        touched = true;
        overlay = switch (doc) {
          'invoice' => overlay.copyWith(invoice: bands),
          'proforma' => overlay.copyWith(proforma: bands),
          'statement' => overlay.copyWith(statement: bands),
          'agreement' ||
          'payments' ||
          'workspace' ||
          'coa' ||
          'badges' ||
          'space_codes' =>
            overlay.withDoc(doc, bands),
          _ => overlay.withReminder(
              int.tryParse(doc.substring(1)) ?? 1, bands),
        };
      }

      for (final entry in _drafts.entries) {
        if (entry.key.startsWith('$lang|')) {
          apply(entry.key.substring(lang.length + 1), entry.value);
        }
      }
      if (touched) {
        template = template.withTranslation(lang, overlay);
      }
    }
    return template;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final levels =
        (ref.read(dunningRulesProvider).value ?? DunningRules.defaults)
            .levels;
    setState(() => _busy = true);
    try {
      await ref
          .read(moneyRepositoryProvider)
          .setInvoicePdfTemplate(workspace.id, _assemble(levels));
    } catch (e, st) {
      TraceLogger.instance.error('money', 'set invoice template failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    ref.invalidate(invoicePdfTemplateProvider);
    if (!mounted) return;
    _dirty = false;
    Navigator.of(context).pop();
    AppSnack.info(
      context,
      l10n?.invoiceTemplateSaved ?? 'Invoice template saved.',
      replace: true,
    );
  }

  /// #822 — presets and reset REPLACE a layout: ask when there is one.
  Future<bool> _confirmReplace() async {
    if (!_currentBands.hasBands) return true;
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.reportDesignerReplaceTitle ??
            'Replace the current layout?'),
        content: Text(l10n?.reportDesignerReplaceBody ??
            'The bands of this document are replaced. Undo brings them back.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('report-designer-replace-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.reportDesignerReplace ?? 'Replace'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// #822 — leaving with unsaved work asks first.
  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.reportDesignerDiscardTitle ??
            'Leave without saving?'),
        content: Text(l10n?.reportDesignerDiscardBody ??
            'Your changes to the templates are not saved.'),
        actions: [
          TextButton(
            key: const ValueKey('report-designer-keep-editing'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.reportDesignerKeepEditing ?? 'Keep editing'),
          ),
          FilledButton(
            key: const ValueKey('report-designer-discard'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n?.reportDesignerDiscard ?? 'Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  /// INSTANT preview (#474): the report engine's output rendered as
  /// widgets — real newest-invoice data when one exists, simulated
  /// sample data otherwise. No PDF round-trip.
  /// The live data for the SELECTED document, or null when the app has
  /// none yet (→ simulated sample data).
  Map<String, Object?>? _liveData() {
    final invoices = ref.read(invoicesProvider).value ?? const [];
    final liveWorkspace = ref.read(currentWorkspaceProvider).value;
    switch (_doc) {
      case 'invoice':
        if (invoices.isEmpty) return null;
        return invoiceReportData(context, invoices.first,
            proforma: false, copy: false, workspace: liveWorkspace);
      case 'proforma':
        if (invoices.isEmpty) return null;
        return invoiceReportData(context, invoices.first,
            proforma: true, copy: false, workspace: liveWorkspace);
      case 'statement':
        final now = ref.read(clockProvider).now();
        final period =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final statement =
            ref.read(myStatementProvider(period)).value;
        final workspace = ref.read(currentWorkspaceProvider).value;
        final me = ref.read(myMemberProvider).value;
        final names = ref.read(memberNamesProvider).value ?? const {};
        if (statement == null || workspace == null) return null;
        return statementReportData(
          context,
          statement: statement,
          workspaceName: workspace.name,
          memberName: names[me?.id] ?? '',
          periodLabel: statement.period,
          currencyCode: workspace.currencyCode,
          workspace: workspace,
        );
      case 'agreement':
        final me = ref.read(myMemberProvider).value;
        final names = ref.read(memberNamesProvider).value ?? const {};
        if (me == null) return null;
        return agreementReportData(context, ref,
            memberName: names[me.id] ?? '',
            subscriptionPct: me.subscriptionPct);
      case 'payments':
        final me = ref.read(myMemberProvider).value;
        final names = ref.read(memberNamesProvider).value ?? const {};
        final now = ref.read(clockProvider).now();
        final period =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        if (me == null) return null;
        return paymentsReportData(context, ref,
            period: period, memberName: names[me.id] ?? '');
      case 'workspace':
        return workspaceReportData(context, ref);
      case 'coa':
      case 'badges':
      case 'space_codes':
        return null;
      default:
        if (invoices.isEmpty) return null;
        return reminderReportData(context, ref, invoices.first,
            level: int.tryParse(_doc.substring(1)) ?? 1);
    }
  }

  Future<void> _quickPreview() async {
    final l10n = AppLocalizations.of(context);
    final live = _liveData();
    final simulated = live == null;
    final data = live ?? sampleReportData(l10n);
    final bands = _currentBands.hasBands
        ? _currentBands
        : defaultBandsForDoc(_doc, l10n);
    final report = renderReportBands(bands: bands, data: data);
    final images = await resolveReportImages(ref, report);
    if (!mounted) return;
    if (report == null) {
      // #822 — the engine's own message, not a generic shrug.
      final why = reportBandsError(bands: bands, data: data) ?? '';
      AppSnack.error(
        context,
        l10n?.reportDesignerError(why) ??
            'The template does not render — $why',
      );
      return;
    }
    await showReportQuickPreview(context,
        report: report, simulated: simulated, images: images);
  }

  /// Renders the selected DOCUMENT through the UNSAVED bands as a PDF —
  /// the invoice as a watermarked copy, a reminder as its letter — and
  /// either DOWNLOADS it or hands it to the share sheet (#474).
  Future<void> _pdf({required bool download}) async {
    final l10n = AppLocalizations.of(context);
    final invoices = ref.read(invoicesProvider).value ?? const [];
    if (invoices.isEmpty) {
      AppSnack.info(
        context,
        l10n?.invoiceTemplateNoPreview ??
            'Issue an invoice first — the preview renders your newest one.',
        replace: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final l10nSync = AppLocalizations.of(context);
      final ({List<int> bytes, String fileName}) pdf;
      if (_doc == 'invoice' || _doc == 'proforma') {
        final invoicePdf = await buildInvoicePdfFile(
          context,
          invoices.first,
          proforma: _doc == 'proforma',
          copy: true,
          template: _doc == 'proforma'
              ? InvoicePdfTemplate(proforma: _currentBands)
              : InvoicePdfTemplate(
                  header: _currentBands.header,
                  body: _currentBands.body,
                  footer: _currentBands.footer,
                ),
          workspace: ref.read(currentWorkspaceProvider).value,
          reportImage: (name) =>
              ref.read(reportImageBytesProvider(name).future),
        );
        pdf = (bytes: invoicePdf.bytes, fileName: invoicePdf.fileName);
      } else if (_doc == 'statement' ||
          _extraDocs.contains(_doc)) {
        // The letter documents: my own live data, or the sample.
        final data = _liveData() ?? sampleReportData(l10nSync);
        final bands = _currentBands.hasBands
            ? _currentBands
            : defaultBandsForDoc(_doc, l10nSync);
        final report = renderReportBands(bands: bands, data: data) ??
            renderReportBands(
                bands: defaultBandsForDoc(_doc, l10nSync), data: data)!;
        Future<pw.Font> font(String asset) async =>
            pw.Font.ttf(await rootBundle.load(asset));
        final bytes = await buildBandedLetterPdf(
          report: report,
          reportImages: await resolveReportImages(ref, report),
          pageLabel: l10nSync?.invoicePdfPage ?? 'Page',
          documentTitle: l10nSync?.billPdfTitle ?? 'Monthly bill',
          baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
          boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
        );
        pdf = (
          bytes: bytes,
          fileName:
              '${safeFileSlug(l10nSync?.billPdfTitle ?? 'statement')}.pdf',
        );
      } else {
        final letter = await buildReminderPdfFile(
          context,
          ref,
          invoices.first,
          level: int.tryParse(_doc.substring(1)) ?? 1,
          draftBands: _currentBands,
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
    } catch (e, st) {
      TraceLogger.instance.error('money', 'template pdf failed',
          error: e, stackTrace: st);
      if (mounted) {
        AppSnack.error(
          context,
          l10n?.workspaceGenericError ??
              'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _insertImage() async {
    final name = await showReportImagePicker(context, ref);
    if (name == null || !mounted) return;
    final designer = _designerKey.currentState;
    if (_visual && designer != null) {
      // #822 — after the selected element, or at the header's end.
      designer.insertImage(name);
      return;
    }
    // Appended to the band a logo most likely belongs to; move it
    // anywhere afterwards.
    _header.text =
        _header.text.isEmpty ? '![$name]' : '${_header.text}\n![$name]';
    setState(_bumpEpoch);
  }

  Widget _bandField(
    TextEditingController controller,
    String label, {
    required String key,
    int minLines = 3,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: TextField(
          key: ValueKey(key),
          controller: controller,
          minLines: minLines,
          maxLines: 14,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  List<(String, String)> _docs(AppLocalizations? l10n) => [
        ('invoice', l10n?.invoiceTemplateDocInvoice ?? 'Invoice'),
        ('proforma', l10n?.invoicePdfProforma ?? 'Proforma'),
        ('statement', l10n?.invoiceTemplateDocStatement ?? 'Statement'),
        // #494 — the further documents.
        ('agreement', l10n?.reportDocAgreement ?? 'Financial agreement'),
        ('payments', l10n?.reportDocPayments ?? 'Payments report'),
        ('workspace', l10n?.reportDocWorkspace ?? 'Workspace report'),
        // #822 — the three structural documents, until now editable
        // yet unlisted.
        ('coa', l10n?.reportDocCoa ?? 'Chart of accounts'),
        ('badges', l10n?.reportDocBadges ?? 'Member badges'),
        ('space_codes', l10n?.reportDocSpaceCodes ?? 'Space QR cards'),
        if (ref
            .watch(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.dunning))
          for (var level = 1;
              level <=
                  (ref.watch(dunningRulesProvider).value ??
                          DunningRules.defaults)
                      .levels;
              level++)
            (
              'r$level',
              l10n?.invoiceTemplateDocReminder(level) ?? 'Reminder $level'
            ),
      ];

  Widget _langChips(AppLocalizations? l10n) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: const ValueKey('invoice-template-lang-default'),
              label: Text(l10n?.reportTemplateLangDefault ??
                  'Default (all languages)'),
              selected: _lang.isEmpty,
              onSelected: (_) => _switchLang(''),
            ),
          ),
          for (final lang in _templateLanguages)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('invoice-template-lang-$lang'),
                // #822 — a dot says "this language has its own".
                avatar: _overridden(lang)
                    ? Icon(Icons.circle,
                        key: ValueKey('invoice-template-lang-own-$lang'),
                        size: 10,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                tooltip: _overridden(lang)
                    ? (l10n?.reportTemplateLangOverridden ?? 'Own template')
                    : (l10n?.reportTemplateLangInherits ??
                        'Inherits the default'),
                label: Text(lang.toUpperCase()),
                selected: _lang == lang,
                onSelected: (_) => _switchLang(lang),
              ),
            ),
          if (_lang.isNotEmpty && _currentBands.hasBands)
            TextButton.icon(
              key: const ValueKey('invoice-template-clear-overlay'),
              icon: const Icon(Icons.layers_clear_outlined, size: 18),
              label: Text(l10n?.reportTemplateClearOverlay ??
                  'Use the default for this language'),
              onPressed: () => _apply(ReportBands.empty),
            ),
        ]),
      );

  Widget _docChips(AppLocalizations? l10n) => SingleChildScrollView(
        key: const ValueKey('invoice-template-docs'),
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (doc, label) in _docs(l10n))
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('invoice-template-doc-$doc'),
                label: Text(label),
                selected: _doc == doc,
                onSelected: (_) => _switchDoc(doc),
              ),
            ),
        ]),
      );

  Widget _actions(AppLocalizations? l10n) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PopupMenuButton<ReportPreset>(
            key: const ValueKey('invoice-template-presets'),
            enabled: !_busy,
            onSelected: (preset) async {
              if (!await _confirmReplace() || !mounted) return;
              _apply(preset.bands);
            },
            itemBuilder: (context) => [
              for (final preset in presetsForDoc(_doc, l10n))
                PopupMenuItem(
                  key: ValueKey('invoice-template-preset-${preset.id}'),
                  value: preset,
                  child: Text(preset.name),
                ),
            ],
            child: TextButton.icon(
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(l10n?.invoiceTemplatePresets ?? 'Templates'),
              // The menu opens from the surrounding button.
              onPressed: null,
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('invoice-template-image'),
            icon: const Icon(Icons.image_outlined),
            label: Text(l10n?.reportInsertImage ?? 'Insert image'),
            onPressed: _busy ? null : _insertImage,
          ),
          OutlinedButton.icon(
            key: const ValueKey('invoice-template-quick-preview'),
            icon: const Icon(Icons.bolt_outlined),
            label: Text(
                l10n?.invoiceTemplateQuickPreview ?? 'Quick preview'),
            onPressed: _busy ? null : _quickPreview,
          ),
          PopupMenuButton<bool>(
            key: const ValueKey('invoice-template-pdf'),
            enabled: !_busy,
            onSelected: (download) => _pdf(download: download),
            itemBuilder: (context) => [
              PopupMenuItem(
                key: const ValueKey('invoice-template-download'),
                value: true,
                child:
                    Text(l10n?.invoiceTemplateDownload ?? 'Download PDF'),
              ),
              PopupMenuItem(
                key: const ValueKey('invoice-template-share'),
                value: false,
                child: Text(l10n?.invoiceTemplateShare ?? 'Share PDF'),
              ),
            ],
            child: OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(l10n?.invoiceTemplatePreview ?? 'Preview'),
              onPressed: null,
            ),
          ),
          TextButton.icon(
            key: const ValueKey('invoice-template-reset'),
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n?.invoiceTemplateReset ?? 'Reset to default'),
            onPressed: _busy
                ? null
                : () async {
                    if (!await _confirmReplace() || !mounted) return;
                    _apply(defaultBandsForDoc(
                        _doc,
                        _lang.isEmpty ? l10n : l10nForLanguage(_lang)));
                  },
          ),
          if (!widget.asPage)
            FilledButton(
              key: const ValueKey('invoice-template-save'),
              onPressed: _busy ? null : _save,
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
        ],
      );

  Widget _editorArea(AppLocalizations? l10n, {required bool sideBySide}) {
    if (_visual) {
      // #548 — the page-true design surface: one A4 page, the
      // document's margins, band strips, page-break guides, zoom, and
      // a Design ↔ Preview toggle (or both pages at once — #822).
      return ReportPageDesigner(
        key: _designerKey,
        header: _header,
        body: _body,
        footer: _footer,
        headerLabel: l10n?.invoiceTemplateHeaderLabel ?? 'Header band',
        bodyLabel: l10n?.invoiceTemplateBodyLabel ??
            'Body band (the invoice lines)',
        footerLabel: l10n?.invoiceTemplateFooterLabel ??
            'Footer band (payment terms, legal mentions)',
        editorKeyPrefix: 'visual-$_doc-$_visualEpoch',
        previewData: () => _liveData() ?? sampleReportData(l10n),
        sideBySide: sideBySide,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _bandField(
          _header,
          l10n?.invoiceTemplateHeaderLabel ?? 'Header band',
          key: 'invoice-template-header',
        ),
        _bandField(
          _body,
          l10n?.invoiceTemplateBodyLabel ?? 'Body band (the invoice lines)',
          key: 'invoice-template-body',
          minLines: 5,
        ),
        _bandField(
          _footer,
          l10n?.invoiceTemplateFooterLabel ??
              'Footer band (payment terms, legal mentions)',
          key: 'invoice-template-footer',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The cheat-sheet is SYNTAX, not copy (HARD RULE #1): field names,
    // Liquid keywords and the line markup are language, identical in
    // every locale.
    final fieldsLine =
        InvoicePdfTemplate.placeholders.map((p) => '{{ $p }}').join('  ');
    const syntaxLines =
        '{% if voided %} … {% else %} … {% endif %}   '
        '{% for line in lines %} {{ line.label }} | {{ line.amount }} {% endfor %}\n'
        '# title   ## section   > small   ---   a | b   = bold | row\n'
        ':::  left column  |||  right column  :::   ![image|m|center]';
    final wide = widget.asPage && MediaQuery.sizeOf(context).width >= 1000;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.asPage)
          Row(
            children: [
              Text(
                l10n?.invoiceTemplateTitle ?? 'Invoice PDF template',
                style: theme.textTheme.titleMedium,
              ),
              HelpDot(l10n?.helpTopicReportEditor ?? 'report editor'),
            ],
          ),
        const SizedBox(height: 4),
        Text(
          l10n?.invoiceTemplateHint ??
              'Three report bands rendered on the PDF — the e-invoice '
                  'XML is never touched. Liquid conditions and loops, '
                  'then line markup:',
          style: theme.textTheme.bodySmall,
        ),
        // #822 — the syntax sheet stays for the markup mode; the
        // designer carries the fields in its own picker.
        if (!_visual)
          Text(
            '$fieldsLine\n$syntaxLines',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.primary,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        // #496 — one template per LANGUAGE: the default, plus an
        // overlay per language for readers in that language.
        _langChips(l10n),
        const SizedBox(height: AppSpacing.xs),
        // #472: one report per DOCUMENT — the invoice, and every
        // reminder level of the dunning rules.
        _docChips(l10n),
        const SizedBox(height: AppSpacing.sm),
        // #488 — markup or WYSIWYG, same underlying bands.
        SegmentedButton<bool>(
          key: const ValueKey('invoice-template-mode'),
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.code),
              label: Text(l10n?.reportEditorMarkup ?? 'Markup'),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.design_services_outlined),
              label: Text(l10n?.reportEditorVisual ?? 'Visual'),
            ),
          ],
          selected: {_visual},
          onSelectionChanged: (selection) => setState(() {
            _visual = selection.first;
            _bumpEpoch();
          }),
        ),
        _editorArea(l10n, sideBySide: wide),
        const SizedBox(height: AppSpacing.md),
        // #474: pick a ready-made report, see it INSTANTLY, then
        // download or share the PDF — or save the bands.
        _actions(l10n),
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
        final leave = await _confirmDiscard();
        if (leave && mounted) Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Flexible(
              child: Text(l10n?.reportEditorTitle ?? 'Report editor',
                  overflow: TextOverflow.ellipsis),
            ),
            HelpDot(l10n?.helpTopicReportEditor ?? 'report editor'),
          ]),
          actions: [
            IconButton(
              key: const ValueKey('report-designer-undo'),
              icon: const Icon(Icons.undo),
              tooltip: l10n?.reportDesignerUndo ?? 'Undo',
              onPressed: _history.canUndo && !_busy ? _undo : null,
            ),
            IconButton(
              key: const ValueKey('report-designer-redo'),
              icon: const Icon(Icons.redo),
              tooltip: l10n?.reportDesignerRedo ?? 'Redo',
              onPressed: _history.canRedo && !_busy ? _redo : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: FilledButton(
                key: const ValueKey('invoice-template-save'),
                onPressed: _busy ? null : _save,
                child: Text(l10n?.commonSave ?? 'Save'),
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
