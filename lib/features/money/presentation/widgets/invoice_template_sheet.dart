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
import '../invoice_actions.dart';

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

/// The default bands — the built-in layout expressed in the template
/// language, so "Reset" hands the owner a WORKING example to customize
/// instead of an empty page.
InvoicePdfTemplate defaultInvoiceTemplate(AppLocalizations? l10n) {
  final header = '''
# {% if proforma %}${l10n?.invoicePdfProforma ?? 'Proforma'}{% else %}${l10n?.invoicePdfTitle ?? 'Invoice'} {{ number }}{% endif %}
{{ workspace }}
> {{ workspace_address }}
> ${l10n?.invoicePdfIssuedOn ?? 'Issued on'} {{ issued }} · ${l10n?.invoicePdfIssuedBy ?? 'Issued by'} {{ issued_by }}
{% if replaces != "" %}> ${l10n?.invoicePdfReplaces ?? 'Replaces'} {{ replaces }}{% endif %}
---''';
  final body = '''
## ${l10n?.invoicePdfBilledTo ?? 'Billed to'}
{{ member }}
> {{ period }}

## ${l10n?.invoicePdfDescription ?? 'Description'}
{% for line in lines %}{{ line.label }} | {{ line.amount }}
{% endfor %}---
{% if has_vat %}{% for v in vat %}> ${l10n?.vatPdfNet ?? 'Net'} {{ v.net }} · ${l10n?.vatPdfVat ?? 'VAT'} {{ v.rate }} : {{ v.amount }}
{% endfor %}{% endif %}= ${l10n?.invoiceBalance ?? 'Balance due'} | {{ total }}''';
  return InvoicePdfTemplate(header: header, body: body, footer: '');
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

  InvoicePdfTemplate get _draft => InvoicePdfTemplate(
        header: _header.text.trim(),
        body: _body.text.trim(),
        footer: _footer.text.trim(),
      );

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(moneyRepositoryProvider)
          .setInvoicePdfTemplate(workspace.id, _draft);
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
      final pdf = await buildInvoicePdfFile(
        context,
        invoices.first,
        copy: true,
        template: _draft,
      );
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
                          final d = defaultInvoiceTemplate(l10n);
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
