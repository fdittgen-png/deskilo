// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

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
import '../invoice_actions.dart';
import '../report_defaults.dart';

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

  /// The document being edited: 0 = the invoice, n = reminder level n
  /// (#472 — every level is its own report).
  int _doc = 0;

  /// Unsaved edits per document, so switching documents loses nothing.
  final Map<int, ReportBands> _drafts = {};

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
  ReportBands _storedBands(int doc) => doc == 0
      ? widget.initial.invoiceBands
      : widget.initial.reminderBands(doc) ?? ReportBands.empty;

  void _switchDoc(int doc) {
    if (doc == _doc) return;
    setState(() {
      _drafts[_doc] = _currentBands;
      _doc = doc;
      final bands = _drafts[doc] ?? _storedBands(doc);
      _header.text = bands.header;
      _body.text = bands.body;
      _footer.text = bands.footer;
    });
  }

  /// The full template with every unsaved edit folded in.
  InvoicePdfTemplate _assemble(int maxLevels) {
    _drafts[_doc] = _currentBands;
    final invoice = _drafts[0] ?? widget.initial.invoiceBands;
    var template = InvoicePdfTemplate(
      header: invoice.header,
      body: invoice.body,
      footer: invoice.footer,
      reminders: widget.initial.reminders,
    );
    for (var level = 1; level <= maxLevels; level++) {
      final bands = _drafts[level];
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

  /// Renders the NEWEST invoice as a watermarked COPY through the
  /// UNSAVED bands and hands it to the share sheet — the reporting
  /// tool's preview loop.
  Future<void> _preview() async {
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
      // #472: the selected DOCUMENT previews — the invoice as a
      // watermarked copy, a reminder as its letter at that level.
      final ({List<int> bytes, String fileName}) pdf;
      if (_doc == 0) {
        final invoicePdf = await buildInvoicePdfFile(
          context,
          invoices.first,
          copy: true,
          template: InvoicePdfTemplate(
            header: _currentBands.header,
            body: _currentBands.body,
            footer: _currentBands.footer,
          ),
        );
        pdf = (bytes: invoicePdf.bytes, fileName: invoicePdf.fileName);
      } else {
        final letter = await buildReminderPdfFile(
          context,
          ref,
          invoices.first,
          level: _doc,
          draftBands: _currentBands,
        );
        pdf = (bytes: letter.bytes, fileName: letter.fileName);
      }
      await ref.read(fileSharerProvider)(
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
        mimeType: 'application/pdf',
      );
    } catch (e, st) {
      TraceLogger.instance.error('money', 'template preview failed',
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
        '# title   ## section   > small   ---   a | b   = bold | row';
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
                for (var doc = 0;
                    doc <=
                        (ref.watch(dunningRulesProvider).value ??
                                DunningRules.defaults)
                            .levels;
                    doc++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('invoice-template-doc-$doc'),
                      label: Text(doc == 0
                          ? (l10n?.invoiceTemplateDocInvoice ?? 'Invoice')
                          : (l10n?.invoiceTemplateDocReminder(doc) ??
                              'Reminder $doc')),
                      selected: _doc == doc,
                      onSelected: (_) => _switchDoc(doc),
                    ),
                  ),
              ]),
            ),
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
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                TextButton.icon(
                  key: const ValueKey('invoice-template-reset'),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(
                      l10n?.invoiceTemplateReset ?? 'Reset to default'),
                  onPressed: _busy
                      ? null
                      : () {
                          final d = _doc == 0
                              ? defaultInvoiceTemplate(l10n).invoiceBands
                              : defaultReminderBands(_doc, l10n);
                          setState(() {
                            _header.text = d.header;
                            _body.text = d.body;
                            _footer.text = d.footer;
                          });
                        },
                ),
                const Spacer(),
                OutlinedButton.icon(
                  key: const ValueKey('invoice-template-preview'),
                  icon: const Icon(Icons.visibility_outlined),
                  label:
                      Text(l10n?.invoiceTemplatePreview ?? 'Preview'),
                  onPressed: _busy ? null : _preview,
                ),
                const SizedBox(width: AppSpacing.sm),
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
