// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/share/file_sharer.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../providers/money_providers.dart';
import '../../domain/dunning.dart';
import '../../../../core/files/file_names.dart';
import '../../../../core/time/clock.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/invoice_pdf.dart';
import '../../domain/invoice_report.dart';
import '../invoice_actions.dart';
import '../report_defaults.dart';
import 'report_preview.dart';
import 'report_visual_editor.dart';

/// The invoice REPORT editor (#454, rebuilt as a banded reporting tool
/// in #470): three Liquid bands — header, body with the lines, footer —
/// with a syntax cheat-sheet, a reset to the built-in layout as a
/// working starting point, and a live preview (rendered as a COPY of
/// the newest invoice through the UNSAVED bands). The sheet says the
/// one thing an owner must never misread: this edits the PDF only,
/// never the legal XML.
Future<void> showInvoiceTemplateSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final template = await ref.read(invoicePdfTemplateProvider.future);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _TemplateSheet(initial: template),
  );
}

class _TemplateSheet extends ConsumerStatefulWidget {
  const _TemplateSheet({required this.initial});

  final InvoicePdfTemplate initial;

  @override
  ConsumerState<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends ConsumerState<_TemplateSheet> {
  late final TextEditingController _header;
  late final TextEditingController _body;
  late final TextEditingController _footer;
  bool _busy = false;

  /// The document being edited (#472/#476): 'invoice', 'proforma',
  /// 'statement', or 'rN' for reminder level N — every one its own
  /// report.
  String _doc = 'invoice';

  /// #488 — WYSIWYG mode: the bands as typed, reorderable rows instead
  /// of raw markup. Both modes edit the SAME controllers.
  bool _visual = false;

  /// Bumped whenever the controllers change from OUTSIDE the visual
  /// editors (doc switch, preset, reset, image insert) — recreates them
  /// so they re-seed from the new text.
  int _visualEpoch = 0;

  /// Unsaved edits per document, so switching documents loses nothing.
  final Map<String, ReportBands> _drafts = {};

  @override
  void initState() {
    super.initState();
    _header = TextEditingController(text: widget.initial.header);
    _body = TextEditingController(text: widget.initial.body);
    _footer = TextEditingController(text: widget.initial.footer);
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

  /// The stored bands of document [doc], before any unsaved edit.
  ReportBands _storedBands(String doc) => switch (doc) {
        'invoice' => widget.initial.invoiceBands,
        'proforma' => widget.initial.proforma,
        'statement' => widget.initial.statement,
        _ => widget.initial
                .reminderBands(int.tryParse(doc.substring(1)) ?? 1) ??
            ReportBands.empty,
      };

  void _switchDoc(String doc) {
    if (doc == _doc) return;
    setState(() {
      _drafts[_doc] = _currentBands;
      _doc = doc;
      final bands = _drafts[doc] ?? _storedBands(doc);
      _header.text = bands.header;
      _body.text = bands.body;
      _footer.text = bands.footer;
      _visualEpoch++;
    });
  }

  /// The full template with every unsaved edit folded in.
  InvoicePdfTemplate _assemble(int maxLevels) {
    _drafts[_doc] = _currentBands;
    final invoice = _drafts['invoice'] ?? widget.initial.invoiceBands;
    var template = InvoicePdfTemplate(
      header: invoice.header,
      body: invoice.body,
      footer: invoice.footer,
      reminders: widget.initial.reminders,
      proforma: _drafts['proforma'] ?? widget.initial.proforma,
      statement: _drafts['statement'] ?? widget.initial.statement,
    );
    for (var level = 1; level <= maxLevels; level++) {
      final bands = _drafts['r$level'];
      if (bands != null) template = template.withReminder(level, bands);
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
    Navigator.of(context).pop();
    AppSnack.info(
      context,
      l10n?.invoiceTemplateSaved ?? 'Invoice template saved.',
      replace: true,
    );
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
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
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
      } else if (_doc == 'statement') {
        // The statement letter: my own statement, or the sample.
        final data = _liveData() ?? sampleReportData(l10nSync);
        final bands = _currentBands.hasBands
            ? _currentBands
            : defaultStatementBands(l10nSync);
        final report = renderReportBands(bands: bands, data: data) ??
            renderReportBands(
                bands: defaultStatementBands(l10nSync), data: data)!;
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
        ':::  left column  |||  right column  :::   ![image]';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.invoiceTemplateTitle ?? 'Invoice PDF template',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n?.invoiceTemplateHint ??
                  'Three report bands rendered on the PDF — the e-invoice '
                      'XML is never touched. Liquid conditions and loops, '
                      'then line markup:',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '$fieldsLine\n$syntaxLines',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // #472: one report per DOCUMENT — the invoice, and every
            // reminder level of the dunning rules.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final (doc, label) in [
                  (
                    'invoice',
                    l10n?.invoiceTemplateDocInvoice ?? 'Invoice'
                  ),
                  ('proforma', l10n?.invoicePdfProforma ?? 'Proforma'),
                  (
                    'statement',
                    l10n?.invoiceTemplateDocStatement ?? 'Statement'
                  ),
                  for (var level = 1;
                      level <=
                          (ref.watch(dunningRulesProvider).value ??
                                  DunningRules.defaults)
                              .levels;
                      level++)
                    (
                      'r$level',
                      l10n?.invoiceTemplateDocReminder(level) ??
                          'Reminder $level'
                    ),
                ])
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
            ),
            const SizedBox(height: AppSpacing.sm),
            // #488 — markup or WYSIWYG, same underlying bands.
            SegmentedButton<bool>(
              key: const ValueKey('invoice-template-mode'),
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.code),
                  label:
                      Text(l10n?.reportEditorMarkup ?? 'Markup'),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.design_services_outlined),
                  label:
                      Text(l10n?.reportEditorVisual ?? 'Visual'),
                ),
              ],
              selected: {_visual},
              onSelectionChanged: (selection) => setState(() {
                _visual = selection.first;
                _visualEpoch++;
              }),
            ),
            if (_visual) ...[
              ReportVisualEditor(
                key: ValueKey('visual-header-$_doc-$_visualEpoch'),
                controller: _header,
                label:
                    l10n?.invoiceTemplateHeaderLabel ?? 'Header band',
                bandKey: 'visual-header',
              ),
              ReportVisualEditor(
                key: ValueKey('visual-body-$_doc-$_visualEpoch'),
                controller: _body,
                label: l10n?.invoiceTemplateBodyLabel ??
                    'Body band (the invoice lines)',
                bandKey: 'visual-body',
              ),
              ReportVisualEditor(
                key: ValueKey('visual-footer-$_doc-$_visualEpoch'),
                controller: _footer,
                label: l10n?.invoiceTemplateFooterLabel ??
                    'Footer band (payment terms, legal mentions)',
                bandKey: 'visual-footer',
              ),
            ] else ...[
              _bandField(
                _header,
                l10n?.invoiceTemplateHeaderLabel ?? 'Header band',
                key: 'invoice-template-header',
              ),
              _bandField(
                _body,
                l10n?.invoiceTemplateBodyLabel ??
                    'Body band (the invoice lines)',
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
            const SizedBox(height: AppSpacing.md),
            // #474: pick a ready-made report, see it INSTANTLY, then
            // download or share the PDF — or save the bands.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PopupMenuButton<ReportPreset>(
                  key: const ValueKey('invoice-template-presets'),
                  enabled: !_busy,
                  onSelected: (preset) => setState(() {
                    _header.text = preset.bands.header;
                    _body.text = preset.bands.body;
                    _footer.text = preset.bands.footer;
                    _visualEpoch++;
                  }),
                  itemBuilder: (context) => [
                    for (final preset in presetsForDoc(_doc, l10n))
                      PopupMenuItem(
                        key: ValueKey(
                            'invoice-template-preset-${preset.id}'),
                        value: preset,
                        child: Text(preset.name),
                      ),
                  ],
                  child: TextButton.icon(
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                        l10n?.invoiceTemplatePresets ?? 'Templates'),
                    // The menu opens from the surrounding button.
                    onPressed: null,
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('invoice-template-image'),
                  icon: const Icon(Icons.image_outlined),
                  label:
                      Text(l10n?.reportInsertImage ?? 'Insert image'),
                  onPressed: _busy
                      ? null
                      : () async {
                          final name =
                              await showReportImagePicker(context, ref);
                          if (name == null || !mounted) return;
                          // Appended to the band a logo most likely
                          // belongs to; move it anywhere afterwards.
                          setState(() {
                            _header.text = _header.text.isEmpty
                                ? '![$name]'
                                : '${_header.text}\n![$name]';
                            _visualEpoch++;
                          });
                        },
                ),
                OutlinedButton.icon(
                  key: const ValueKey('invoice-template-quick-preview'),
                  icon: const Icon(Icons.bolt_outlined),
                  label: Text(l10n?.invoiceTemplateQuickPreview ??
                      'Quick preview'),
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
                      child: Text(l10n?.invoiceTemplateDownload ??
                          'Download PDF'),
                    ),
                    PopupMenuItem(
                      key: const ValueKey('invoice-template-share'),
                      value: false,
                      child: Text(
                          l10n?.invoiceTemplateShare ?? 'Share PDF'),
                    ),
                  ],
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                        l10n?.invoiceTemplatePreview ?? 'Preview'),
                    onPressed: null,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('invoice-template-reset'),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(
                      l10n?.invoiceTemplateReset ?? 'Reset to default'),
                  onPressed: _busy
                      ? null
                      : () {
                          final d = defaultBandsForDoc(_doc, l10n);
                          setState(() {
                            _visualEpoch++;
                            _header.text = d.header;
                            _body.text = d.body;
                            _footer.text = d.footer;
                          });
                        },
                ),
                FilledButton(
                  key: const ValueKey('invoice-template-save'),
                  onPressed: _busy ? null : _save,
                  child: Text(l10n?.commonSave ?? 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
