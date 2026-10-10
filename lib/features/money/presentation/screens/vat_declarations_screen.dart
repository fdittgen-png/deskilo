// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/files/file_saver.dart';
import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/vat_declaration.dart';
import '../../domain/vat_declaration_report.dart';
import '../invoice_documents.dart';
import '../report_layout_actions.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';
import '../../providers/vat_declaration_providers.dart';
import '../report_actions.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../vat_report_actions.dart';
import '../vat_tax_point_labels.dart';
import '../widgets/vat_tax_point_notice.dart';

/// Preparation of the VAT return (#534/0107, #2357/0402): the owner
/// picks a filing period (month or quarter), the SERVER computes the
/// return from the invoices, payments and tax points
/// (`compute_vat_return`), the app maps it onto the country's official
/// form boxes (CA3 / UStVA / generic) and produces the PDF and the
/// machine-readable XML. The owner files it with the authority (EFI,
/// ELSTER, an accountant) and records the receipt reference: draft →
/// prepared → filed. Nothing in the app transmits a return.
class VatDeclarationsScreen extends ConsumerStatefulWidget {
  const VatDeclarationsScreen({super.key});

  @override
  ConsumerState<VatDeclarationsScreen> createState() =>
      _VatDeclarationsScreenState();
}

class _VatDeclarationsScreenState
    extends ConsumerState<VatDeclarationsScreen> {
  int _periodIndex = 0;

  String _periodLabel(
      ({DateTime start, DateTime end, bool isQuarter}) period) {
    if (period.isQuarter) {
      final quarter = (period.start.month - 1) ~/ 3 + 1;
      return 'Q$quarter ${period.start.year}';
    }
    return DateFormat.yMMMM().format(period.start);
  }

  Future<void> _generate(
      ({DateTime start, DateTime end, bool isQuarter}) period) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'vat declaration generate failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        // #2357 — the server computes the return (0402: the tax points
        // of the accountant's view, settlements allocated to their
        // sources); the screen then shows the stored figures.
        await ref.read(vatDeclarationCommandProvider).declare(
              workspaceId: workspace.id,
              periodStart: period.start,
              periodEnd: period.end,
            );
      },
    );
    ref.invalidate(vatDeclarationsProvider);
  }

  /// #896 — one sentence naming the basis this workspace declares on.
  String _basisNote(AppLocalizations? l10n) {
    final workspace = ref.read(currentWorkspaceProvider).value;
    return vatTaxPointBasisNote(
        l10n,
        workspaceTaxPointBasis(
            workspace?.invoiceLegal ?? const {}, workspace?.countryCode ?? ''));
  }

  Map<String, Object?> _reportData(VatDeclaration declaration) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final dateFormat = DateFormat.yMMMd(l10n?.localeName);
    return vatDeclarationReportData(
      declaration: declaration,
      workspaceName: workspace?.name ?? '',
      vatId: workspace?.vatId ?? '',
      countryCode: workspace?.countryCode ?? '',
      disclaimer: '${_basisNote(l10n)} '
          '${l10n?.vatDeclDisclaimer ?? "Verify against your accounting before filing."}',
      statusLabel: _statusLabel(l10n, declaration),
      rate: (value) => '${NumberFormat.decimalPattern(l10n?.localeName).format(value)} %',
      money: moneyFormat(declaration.currency, locale: l10n?.localeName).formatMinor,
      date: dateFormat.format,
    );
  }

  Future<({Uint8List bytes, String fileName})> _buildPdf(
      VatDeclaration declaration) async {
    final l10n = AppLocalizations.of(context);
    final data = _reportData(declaration);
    final report = renderLetterDoc(context, ref,
        docId: 'vat_declaration', data: data);
    final pdf = await letterDocPdf(context, ref,
        title: l10n?.vatDeclTitle ?? 'VAT declaration',
        report: report, data: data,
        layoutXml: letterLayoutXml(ref, docId: 'vat_declaration', l10n: l10n));
    final start =
        declaration.periodStart.toIso8601String().substring(0, 10);
    return (bytes: pdf.bytes, fileName: 'vat-declaration-$start.pdf');
  }

  Future<void> _exportXml(VatDeclaration declaration) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    await runGuarded(
      context,
      domain: 'money',
      message: 'vat declaration xml export failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final xml = vatDeclarationXml(
          declaration: declaration,
          workspaceName: workspace?.name ?? '',
          vatId: workspace?.vatId ?? '',
          countryCode: workspace?.countryCode ?? '',
        );
        final start =
            declaration.periodStart.toIso8601String().substring(0, 10);
        final path = await ref.read(fileSaverProvider)(
          bytes: utf8.encode(xml),
          fileName: 'vat-declaration-$start.xml',
        );
        if (!mounted) return;
        AppSnack.success(
          context,
          l10n?.commonSavedTo(path ?? '') ?? 'Saved to $path',
          replace: true,
        );
      },
    );
  }

  String _statusLabel(AppLocalizations? l10n, VatDeclaration declaration) =>
      declaration.isFiled
          ? (l10n?.vatDeclFiled ?? 'Filed')
          : declaration.isPrepared
              ? (l10n?.vatDeclPrepared ?? 'Prepared')
              : (l10n?.vatDeclDraft ?? 'Draft');

  Future<void> _markFiled(VatDeclaration declaration) async {
    final l10n = AppLocalizations.of(context);
    // #2357 — filed with the authority's receipt reference, or not at all.
    final receipt = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _MarkFiledDialog(l10n: l10n),
    );
    if (receipt == null || receipt.trim().isEmpty || !mounted) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'vat declaration mark filed failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(vatDeclarationCommandProvider)
          .fileByHand(declaration.id, receipt: receipt.trim()),
    );
    ref.invalidate(vatDeclarationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final regime = vatRegimeFromWire(workspace?.vatRegime ?? '');
    final declarationsAsync = ref.watch(vatDeclarationsProvider);
    final now = ref.watch(clockProvider).now();
    final periods = vatFilingPeriods(now);
    final period = periods[_periodIndex.clamp(0, periods.length - 1)];
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(key: const ValueKey('vat-declarations-back-button'), onPressed: () => context.go('/money')),
        title: Text(l10n?.vatDeclScreenTitle ?? 'Preparation of the VAT return'),
      ),
      body: regime != VatRegime.vatRegistered
          ? Padding(
              padding: AppSpacing.lgAll,
              child: InlineBanner(
                key: const ValueKey('vat-decl-regime-gate'),
                icon: Icons.gavel_outlined,
                text: l10n?.vatDeclRegimeGate ??
                    'Declarations exist only under the VAT-registered '
                        'regime — configure it under VAT settings.',
              ),
            )
          : ListView(
              padding: AppSpacing.lgAll,
              children: [
                // #896 — which period a declaration covers depends on
                // the basis, so the basis is said before it is used.
                InlineBanner(
                  key: const ValueKey('vat-decl-basis'),
                  icon: Icons.event_available_outlined,
                  text: _basisNote(l10n),
                ),
                VatTaxPointNotice(
                  eligible: workspace != null &&
                      needsVatTaxPointNotice(
                        country: workspace.countryCode,
                        vatRegime: workspace.vatRegime,
                        invoiceLegal: workspace.invoiceLegal,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // New declaration: period + generate.
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: const ValueKey('vat-decl-period'),
                        initialValue: _periodIndex,
                        decoration: InputDecoration(
                          labelText: l10n?.vatDeclPeriod ?? 'Period',
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final (index, p) in periods.indexed)
                            DropdownMenuItem(
                              value: index,
                              child: Text(_periodLabel(p)),
                            ),
                        ],
                        onChanged: (value) => setState(
                            () => _periodIndex = value ?? 0),
                      ),
                    ),
                    HelpDot(l10n?.helpTopicVat ?? 'VAT',
                      anchor: HelpAnchor.moneyVatDeclaration,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton.icon(
                      key: const ValueKey('vat-decl-generate'),
                      onPressed: () => _generate(period),
                      icon: const Icon(Icons.calculate_outlined),
                      label: Text(
                          l10n?.vatDeclGenerate ?? 'Generate'),
                    ),
                  ],
                ),
                // #878 — the period's positions for the accountant, as
                // the letter and as a CSV, beside the declaration.
                if (ref
                    .watch(enabledFeaturesSyncProvider)
                    .contains(WorkspaceFeature.vatReport)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('vat-report-pdf'),
                        onPressed: () => showVatReport(context, ref,
                            start: period.start, end: period.end),
                        icon: const Icon(Icons.summarize_outlined),
                        label: Text(l10n?.vatReportPdf ?? 'VAT report (PDF)'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('vat-report-csv'),
                        onPressed: () => saveVatReportCsv(context, ref,
                            start: period.start, end: period.end),
                        icon: const Icon(Icons.table_view_outlined),
                        label: Text(l10n?.vatReportCsv ?? 'VAT report (CSV)'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                switch (declarationsAsync) {
                  AsyncData(value: final declarations)
                      when declarations.isEmpty =>
                    EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n?.vatDeclEmpty ??
                          'No declarations yet — pick a period and '
                              'generate the first one.',
                    ),
                  AsyncData(value: final declarations) => Column(
                      children: [
                        for (final declaration in declarations)
                          Card(
                            key: ValueKey(
                                'vat-decl-${declaration.id}'),
                            child: Padding(
                              padding: AppSpacing.lgAll,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${dateFormat.format(declaration.periodStart)}'
                                          ' – '
                                          '${dateFormat.format(declaration.periodEnd)}',
                                          style: theme
                                              .textTheme.titleMedium,
                                        ),
                                      ),
                                      Chip(
                                        key: ValueKey(
                                            'vat-decl-status-${declaration.id}'),
                                        label: Text(
                                          _statusLabel(l10n, declaration),
                                        ),
                                        visualDensity:
                                            VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  for (final line in declaration.lines)
                                    Text(
                                      '${_pctLabel(line.percent)}'
                                      '${line.category.isEmpty ? '' : ' ${line.category}'} · '
                                      '${l10n?.vatDeclNet ?? 'Net base'} '
                                      '${centsToMajor(line.netCents)} ${declaration.currency} · '
                                      '${l10n?.vatDeclVat ?? 'VAT'} '
                                      '${centsToMajor(line.vatCents)} ${declaration.currency}',
                                      style:
                                          theme.textTheme.bodySmall,
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${l10n?.vatDeclTotals ?? 'Totals'}: '
                                    '${centsToMajor(declaration.totalNetCents)} ${declaration.currency} · '
                                    '${l10n?.vatDeclVat ?? 'VAT'} '
                                    '${centsToMajor(declaration.totalVatCents)} ${declaration.currency} · '
                                    '${declaration.invoiceCount} '
                                    '${l10n?.vatDeclInvoices ?? 'Invoices'}',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            fontWeight:
                                                FontWeight.w600),
                                  ),
                                  if (declaration.isFiled)
                                    Text(
                                      '${declaration.number.isEmpty ? '' : '${declaration.number} · '}'
                                      '${declaration.submittedChannel}'
                                      '${declaration.submittedReceipt.isEmpty ? '' : ' · ${declaration.submittedReceipt}'}',
                                      style: theme.textTheme.bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      OutlinedButton.icon(
                                        key: ValueKey(
                                            'vat-decl-pdf-${declaration.id}'),
                                        icon: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                            size: 18),
                                        label: Text(
                                            l10n?.vatDeclPdf ?? 'PDF'),
                                        onPressed: () async {
                                          await warmLetterDocProviders(ref, 'vat_declaration');
                                          if (!context.mounted) return;
                                          await runReportActions(
                                          context,
                                          ref,
                                          keyPrefix: 'vat-decl',
                                          render: () => renderLetterDoc(context, ref,
                                              docId: 'vat_declaration', data: _reportData(declaration)),
                                          logMessage:
                                              'vat declaration pdf failed',
                                          buildPdf: () =>
                                              _buildPdf(declaration),
                                          );
                                        },
                                      ),
                                      OutlinedButton.icon(
                                        key: ValueKey(
                                            'vat-decl-xml-${declaration.id}'),
                                        icon: const Icon(
                                            Icons.code_outlined,
                                            size: 18),
                                        label: Text(l10n?.vatDeclXml ??
                                            'XML export'),
                                        onPressed: () =>
                                            _exportXml(declaration),
                                      ),
                                      if (declaration.isPrepared)
                                        OutlinedButton.icon(
                                          key: ValueKey(
                                              'vat-decl-filed-${declaration.id}'),
                                          icon: const Icon(
                                              Icons.task_alt_outlined,
                                              size: 18),
                                          label: Text(
                                              l10n?.vatDeclMarkFiled ??
                                                  'Mark as filed'),
                                          onPressed: () =>
                                              _markFiled(declaration),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  AsyncError() => Text(
                      l10n?.workspaceGenericError ??
                          'Something went wrong. Please try again.',
                    ),
                  _ => const LoadingView(),
                },
              ],
            ),
    );
  }
}

String _pctLabel(double percent) => percent == percent.roundToDouble()
    ? '${percent.toStringAsFixed(0)} %'
    : '$percent %';

/// #2357 — the mark-as-filed dialog: the owner confirms and types the
/// receipt reference the authority gave; the button waits for it.
class _MarkFiledDialog extends StatefulWidget {
  const _MarkFiledDialog({required this.l10n});

  final AppLocalizations? l10n;

  @override
  State<_MarkFiledDialog> createState() => _MarkFiledDialogState();
}

class _MarkFiledDialogState extends State<_MarkFiledDialog> {
  final _receipt = TextEditingController();

  @override
  void dispose() {
    _receipt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n?.vatDeclMarkFiled ?? 'Mark as filed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n?.vatDeclMarkFiledConfirm ??
              'Confirm that you filed this return yourself with the tax '
                  'authority and enter the receipt reference it gave you.'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            key: const ValueKey('vat-decl-receipt'),
            controller: _receipt,
            autofocus: true,
            label: l10n?.vatDeclReceipt ??
                'Receipt reference from the tax authority',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('vat-declarations-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('vat-decl-filed-confirm'),
          onPressed: _receipt.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_receipt.text.trim()),
          child: Text(l10n?.vatDeclMarkFiled ?? 'Mark as filed'),
        ),
      ],
    );
  }
}
