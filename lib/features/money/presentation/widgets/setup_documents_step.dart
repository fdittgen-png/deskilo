// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "invoice look": which design the invoices print with,
// the shipped looks to start from (saved through [SaveInvoiceLook], after
// the same "replace your design?" question the designer asks), and the
// designer one tap away. The preview is a sample invoice rendered through
// the report engine with the workspace's own design and letterhead (or the
// look being tried), marked as a sample and never numbered.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/save_invoice_look.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../providers/money_providers.dart';
import '../report_defaults.dart';
import 'report_editor_dialogs.dart';
import 'setup_sample_invoice.dart';

/// The report kind the step designs.
const _invoiceDoc = 'invoice';

class SetupDocumentsStep extends ConsumerWidget {
  const SetupDocumentsStep({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The sample's line is taxed at the default rate: read before drawing.
    final rates = ref.watch(vatRatesProvider);
    return switch (ref.watch(invoicePdfTemplateProvider)) {
      AsyncValue(hasValue: true, :final value)
          when rates.hasValue || rates.hasError =>
        _DocumentsPage(
          workspaceId: workspaceId,
          stored: value ?? InvoicePdfTemplate.empty,
        ),
      AsyncError() => Padding(
        padding: AppSpacing.lgAll,
        child: InlineBanner(
          key: const ValueKey('setup-documents-failed'),
          icon: Icons.error_outline,
          text: context.l10n.setupStepLoadFailed,
        ),
      ),
      _ => const LoadingView(),
    };
  }
}

class _DocumentsPage extends ConsumerStatefulWidget {
  const _DocumentsPage({required this.workspaceId, required this.stored});

  final String workspaceId;

  /// The template as stored: what a save writes back around the look.
  final InvoicePdfTemplate stored;

  @override
  ConsumerState<_DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<_DocumentsPage> {
  /// The id of the look being tried; null shows the stored design.
  final _look = ValueNotifier<String?>(null);
  final _busy = ValueNotifier<bool>(false);
  late final _changes = Listenable.merge([_look, _busy]);

  @override
  void dispose() {
    _look.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _apply(ReportPreset look) async {
    if (widget.stored.invoiceBands.hasBands &&
        !await confirmReportReplace(context)) {
      return;
    }
    if (!mounted) return;
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'setup invoice look failed',
      errorText: l10n.setupGrowSaveFailed,
      action: () => ref
          .read(saveInvoiceLookProvider)
          .apply(widget.workspaceId, widget.stored, look.bands),
    );
    ref.invalidate(invoicePdfTemplateProvider);
    if (!mounted) return;
    _busy.value = false;
    if (!ok) return;
    _look.value = null;
    AppSnack.success(context, l10n.setupGrowDocumentsSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final looks = presetsForDoc(_invoiceDoc, l10n);
    final own = widget.stored.invoiceBands.hasBands;
    return SetupStepLayout(
      form: ListenableBuilder(
        listenable: _changes,
        builder: (context, _) {
          final tried = looks.where((l) => l.id == _look.value).firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.setupStepHint('documents')),
              const FormGap.large(),
              Text(
                own
                    ? l10n.setupGrowDocumentsOwn
                    : l10n.setupGrowDocumentsBuiltIn,
                key: own
                    ? const ValueKey('setup-documents-own')
                    : const ValueKey('setup-documents-built-in'),
              ),
              if (widget.stored.layoutFor(_invoiceDoc) != null) ...[
                const FormGap(),
                InlineBanner(
                  key: const ValueKey('setup-documents-layout'),
                  icon: Icons.info_outline,
                  severity: InlineBannerSeverity.info,
                  text: l10n.setupGrowDocumentsLayout,
                ),
              ],
              const FormGap(),
              Text(l10n.setupGrowDocumentsChoose),
              const FormGap.small(),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final look in looks)
                    ChoiceChip(
                      key: ValueKey('setup-documents-look-${look.id}'),
                      label: Text(look.name),
                      selected: look.id == _look.value,
                      onSelected: _busy.value
                          ? null
                          : (on) => _look.value = on ? look.id : null,
                    ),
                ],
              ),
              if (own) ...[
                const FormGap.small(),
                Text(
                  l10n.setupGrowDocumentsReplaces,
                  key: const ValueKey('setup-documents-replaces'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const FormGap(),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  key: const ValueKey('setup-documents-apply'),
                  onPressed: tried == null || _busy.value
                      ? null
                      : () => _apply(tried),
                  child: Text(l10n.setupGrowDocumentsApply),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('setup-documents-open-designer'),
                  onPressed: () => context.push('/reports?section=documents'),
                  child: Text(l10n.setupGrowDocumentsOpenDesigner),
                ),
              ),
            ],
          );
        },
      ),
      preview: ValueListenableBuilder<String?>(
        valueListenable: _look,
        builder: (context, id, _) => SetupSampleSheet(
          key: const ValueKey('setup-documents-preview'),
          report: setupSampleReport(
            context,
            ref,
            look: looks.where((l) => l.id == id).firstOrNull?.bands,
          ),
        ),
      ),
    );
  }
}
