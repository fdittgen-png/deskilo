// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../providers/money_providers.dart';

/// Owner editor for the invoice-PDF template (#454): intro above the
/// billed-to block, footer under the totals, `{{placeholder}}`
/// substitution. PDF only — the sheet says so, because the one thing an
/// owner must never believe is that this edits the legal XML.
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
  late final TextEditingController _intro;
  late final TextEditingController _footer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _intro = TextEditingController(text: widget.initial.intro);
    _footer = TextEditingController(text: widget.initial.footer);
  }

  @override
  void dispose() {
    _intro.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(moneyRepositoryProvider).setInvoicePdfTemplate(
            workspace.id,
            InvoicePdfTemplate(
              intro: _intro.text.trim(),
              footer: _footer.text.trim(),
            ),
          );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Composed outside the widget tree (HARD RULE #1 lints inline
    // literals): the placeholder menu is data, not copy.
    final placeholderLine = [
      for (final name in InvoicePdfTemplate.placeholders) '{{$name}}',
    ].join('  ');
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n?.invoiceTemplateHint ??
                  'Free text on the rendered PDF — the e-invoice XML is '
                      'never touched. Placeholders:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              placeholderLine,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('invoice-template-intro'),
              controller: _intro,
              maxLines: 4,
              minLines: 2,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: l10n?.invoiceTemplateIntroLabel ??
                    'Intro (above the billed-to block)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('invoice-template-footer'),
              controller: _footer,
              maxLines: 6,
              minLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: l10n?.invoiceTemplateFooterLabel ??
                    'Footer (under the totals — payment terms, legal '
                        'mentions)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('invoice-template-save'),
              onPressed: _busy ? null : _save,
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
