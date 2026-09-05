// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/file_saver.dart';
import '../../../../core/format/cents.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/einvoice_gateway.dart';
import '../../domain/vat_declaration.dart';
import '../../domain/vat_declaration_pdf.dart';
import '../../domain/vat_regime.dart';
import '../../domain/accounting_view.dart';
import '../../providers/money_providers.dart';
import '../../providers/vat_declaration_providers.dart';
import '../report_actions.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../vat_report_actions.dart';

/// Periodic VAT declarations (#534/0107): the owner picks a filing
/// period (month or quarter), the app aggregates the period's issued
/// invoices per rate WITH THE INVOICES' OWN vatSplit arithmetic, maps
/// the result onto the country's official form boxes (CA3 / UStVA /
/// generic), and produces the PDF + machine-readable XML. Transmission:
/// through the configured e-invoicing platform channel when one exists,
/// or exported/keyed into the authority's portal (EFI, ELSTER) and
/// marked as filed — every path lands in the same submitted state with
/// its channel and receipt on record.
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
        // #831 — declared from the accountant's view: no settlement.
        final invoices = accountingView(
          await ref.read(invoicesProvider.future),
          ref.read(invoiceMatchesProvider).value ?? const {},
        ).invoices;
        final lines =
            computeVatDeclarationLines(invoices, period.start, period.end);
        var net = 0;
        var vat = 0;
        final ids = <String>{};
        for (final line in lines) {
          net += line.netCents;
          vat += line.vatCents;
        }
        for (final invoice in invoices) {
          if (invoice.voidedAt == null &&
              !invoice.issuedAt.isBefore(period.start) &&
              invoice.issuedAt
                  .isBefore(period.end.add(const Duration(days: 1)))) {
            ids.add(invoice.id);
          }
        }
        await ref.read(moneyRepositoryProvider).saveVatDeclaration(
              workspaceId: workspace.id,
              periodStart: period.start,
              periodEnd: period.end,
              lines: lines,
              totalNetCents: net,
              totalVatCents: vat,
              currency: workspace.currencyCode,
              invoiceCount: ids.length,
            );
      },
    );
    ref.invalidate(vatDeclarationsProvider);
  }

  Future<({Uint8List bytes, String fileName})> _buildPdf(
      VatDeclaration declaration) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    Future<pw.Font> font(String asset) async =>
        pw.Font.ttf(await rootBundle.load(asset));
    final dateFormat = DateFormat.yMMMd();
    final bytes = await buildVatDeclarationPdf(
      strings: VatDeclarationPdfStrings(
        title: l10n?.vatDeclTitle ?? 'VAT declaration',
        period: l10n?.vatDeclPeriod ?? 'Period',
        seller: l10n?.vatDeclSeller ?? 'Seller',
        vatIdLabel: l10n?.vatDeclVatId ?? 'VAT ID',
        colRate: l10n?.vatDeclRate ?? 'Rate',
        colNet: l10n?.vatDeclNet ?? 'Net base',
        colVat: l10n?.vatDeclVat ?? 'VAT',
        colInvoices: l10n?.vatDeclInvoices ?? 'Invoices',
        totals: l10n?.vatDeclTotals ?? 'Totals',
        boxesTitle: l10n?.vatDeclBoxes ?? 'Official form lines',
        colBox: l10n?.vatDeclBox ?? 'Box',
        statusLabel: l10n?.vatDeclStatus ?? 'Status',
        disclaimer: l10n?.vatDeclDisclaimer ??
            'Generated from the period\'s issued invoices. Verify against '
                'your accounting before filing — this is a filing aid, '
                'not tax advice.',
      ),
      declaration: declaration,
      workspaceName: workspace?.name ?? '',
      vatId: workspace?.vatId ?? '',
      countryCode: workspace?.countryCode ?? '',
      money: (cents) =>
          '${centsToMajor(cents)} ${declaration.currency}',
      date: dateFormat.format,
      baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
      boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
    );
    final start =
        declaration.periodStart.toIso8601String().substring(0, 10);
    return (bytes: bytes, fileName: 'vat-declaration-$start.pdf');
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

  Future<void> _transmit(VatDeclaration declaration) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'vat declaration transmit failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final pdf = await _buildPdf(declaration);
        final submission =
            await ref.read(moneyRepositoryProvider).sendVatDeclaration(
                  workspaceId: workspace.id,
                  declarationId: declaration.id,
                  fileName: pdf.fileName,
                  mimeType: 'application/pdf',
                  bytes: pdf.bytes,
                );
        if (!mounted) return;
        if (submission.status == EInvoiceSubmissionStatus.accepted) {
          AppSnack.success(
            context,
            l10n?.vatDeclSent ?? 'Declaration transmitted.',
            replace: true,
          );
        } else {
          AppSnack.error(
            context,
            '${l10n?.vatDeclRejected ?? 'The platform refused the declaration.'} '
            '${submission.detail}',
            replace: true,
          );
        }
      },
    );
    ref.invalidate(vatDeclarationsProvider);
  }

  Future<void> _markFiled(VatDeclaration declaration) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.vatDeclMarkFiled ?? 'Mark as filed'),
        content: Text(l10n?.vatDeclMarkFiledConfirm ??
            'Confirm you filed this declaration yourself (tax-office '
                'portal or your accountant). It becomes immutable.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('vat-decl-filed-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n?.vatDeclMarkFiled ?? 'Mark as filed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'vat declaration mark filed failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(moneyRepositoryProvider)
          .markVatDeclarationSubmitted(
              declarationId: declaration.id, channel: 'manual'),
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
    final gateway = ref.watch(eInvoiceGatewayProvider).value;
    final now = ref.watch(clockProvider).now();
    final periods = vatFilingPeriods(now);
    final period = periods[_periodIndex.clamp(0, periods.length - 1)];
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/money')),
        title: Text(l10n?.vatDeclTitle ?? 'VAT declaration'),
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
                    HelpDot(l10n?.helpTopicVat ?? 'VAT'),
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
                                          declaration.isSubmitted
                                              ? (l10n?.vatDeclSubmitted ??
                                                  'Submitted')
                                              : (l10n?.vatDeclDraft ??
                                                  'Draft'),
                                        ),
                                        visualDensity:
                                            VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  for (final line in declaration.lines)
                                    Text(
                                      '${_pctLabel(line.percent)} · '
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
                                  if (declaration.isSubmitted)
                                    Text(
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
                                        onPressed: () =>
                                            runReportActions(
                                          context,
                                          ref,
                                          keyPrefix: 'vat-decl',
                                          logMessage:
                                              'vat declaration pdf failed',
                                          buildPdf: () =>
                                              _buildPdf(declaration),
                                        ),
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
                                      if (!declaration.isSubmitted &&
                                          (gateway?.configured ??
                                              false))
                                        FilledButton.icon(
                                          key: ValueKey(
                                              'vat-decl-send-${declaration.id}'),
                                          icon: const Icon(
                                              Icons.cloud_upload_outlined,
                                              size: 18),
                                          label: Text(
                                              l10n?.vatDeclTransmit ??
                                                  'Transmit'),
                                          onPressed: () =>
                                              _transmit(declaration),
                                        ),
                                      if (!declaration.isSubmitted)
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
