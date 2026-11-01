// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/files/file_saver.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/calendar_days.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/vat_declaration_rows.dart';
import '../../domain/invoice_legal.dart';
import '../../domain/vat_declaration.dart';
import '../../domain/vat_declaration_period.dart';
import '../../domain/vat_declaration_report.dart';
import '../../domain/vat_regime.dart';
import '../../providers/money_providers.dart';
import '../../providers/vat_declaration_providers.dart';
import '../invoice_documents.dart';
import '../recapitulative_actions.dart';
import '../report_actions.dart';
import '../report_layout_actions.dart';
import '../sales_tax_worksheet_actions.dart';
import '../vat_filing_file_actions.dart';
import '../vat_register_actions.dart';
import '../vat_report_actions.dart';
import '../vat_tax_point_labels.dart';
import '../widgets/vat_declaration_card.dart';
import '../widgets/vat_declaration_period_field.dart';
import '../widgets/vat_mark_filed_dialog.dart';
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

  Future<void> _generate(VatFilingPeriod period) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'vat declaration generate failed',
      errorText: l10n.workspaceGenericError,
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
  String _basisNote(AppLocalizations l10n) {
    final workspace = ref.read(currentWorkspaceProvider).value;
    return vatTaxPointBasisNote(
        l10n,
        workspaceTaxPointBasis(
            workspace?.invoiceLegal ?? const {}, workspace?.countryCode ?? ''));
  }

  Map<String, Object?> _reportData(VatDeclaration declaration) {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    return vatDeclarationReportData(
      declaration: declaration,
      workspaceName: workspace?.name ?? '',
      vatId: workspace?.vatId ?? '',
      countryCode: workspace?.countryCode ?? '',
      disclaimer: '${_basisNote(l10n)} '
          '${l10n.vatDeclDisclaimer}',
      statusLabel: _statusLabel(l10n, declaration),
      rate: (value) => '${NumberFormat.decimalPattern(l10n.localeName).format(value)} %',
      lineNote: (line) => _lineNote(l10n, line),
      money: moneyFormat(declaration.currency, locale: l10n.localeName).formatMinor,
      date: dateFormat.format,
    );
  }

  Future<({Uint8List bytes, String fileName})> _buildPdf(
      VatDeclaration declaration) async {
    final l10n = context.l10n;
    final data = _reportData(declaration);
    final report = renderLetterDoc(context, ref,
        docId: 'vat_declaration', data: data);
    final pdf = await letterDocPdf(context, ref,
        title: l10n.vatDeclTitle,
        report: report, data: data,
        layoutXml: letterLayoutXml(ref, docId: 'vat_declaration', l10n: l10n));
    final start =
        declaration.periodStart.toIso8601String().substring(0, 10);
    return (bytes: pdf.bytes, fileName: 'vat-declaration-$start.pdf');
  }

  Future<void> _exportXml(VatDeclaration declaration) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    await runGuarded(
      context,
      domain: 'money',
      message: 'vat declaration xml export failed',
      errorText: l10n.workspaceGenericError,
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
          l10n.commonSavedTo(path ?? ''),
          replace: true,
        );
      },
    );
  }

  /// #2357 — what a line is beside its rate: « Deductible VAT » for an
  /// expense's VAT, « Acquisition tax » for the tax owed on services bought
  /// from abroad, « Correction of September 2026 » for a correction of a
  /// filed return; '' for the period's own sales.
  String _lineNote(AppLocalizations l10n, VatDeclarationLine line) {
    final words = vatWords(l10n);
    final start = line.correctsStart;
    final end = line.correctsEnd;
    final correction = !line.isCorrection
        ? ''
        : words.vatDeclCorrectionOf(start == null || end == null
            ? line.corrects
            : vatFilingPeriodLabel(l10n, (start: start, end: end)));
    return [
      if (line.isInput) words.vatDeclInputVat,
      if (line.isAcquisition) words.vatDeclAcquisitionTax,
      if (correction.isNotEmpty) correction,
    ].join(' · ');
  }

  String _statusLabel(AppLocalizations l10n, VatDeclaration declaration) =>
      switch (VatDeclarationRow(declaration).stage) {
        VatDeclarationStage.filed => l10n.vatDeclFiled,
        VatDeclarationStage.prepared => l10n.vatDeclPrepared,
        VatDeclarationStage.draft => l10n.vatDeclDraft,
      };

  Future<void> _markFiled(VatDeclaration declaration) async {
    final l10n = context.l10n;
    // #2357 — filed with the authority's receipt reference, or not at all.
    final receipt = await showDialog<String>(
      context: context,
      builder: (dialogContext) => VatMarkFiledDialog(l10n: l10n),
    );
    if (receipt == null || receipt.trim().isEmpty || !mounted) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'vat declaration mark filed failed',
      errorText: l10n.workspaceGenericError,
      action: () => ref
          .read(vatDeclarationCommandProvider)
          .fileByHand(declaration.id, receipt: receipt.trim()),
    );
    ref.invalidate(vatDeclarationsProvider);
  }

  Widget _periodRow(
    AppLocalizations l10n,
    List<VatFilingPeriod> periods,
    VatFilingPeriod period,
  ) {
    // New declaration: period + generate.
    return Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<int>(
          key: const ValueKey('vat-decl-period'),
          initialValue: _periodIndex,
          decoration: InputDecoration(
            labelText: l10n.vatDeclPeriod,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final (index, p) in periods.indexed)
              DropdownMenuItem(
                value: index,
                child: Text(vatFilingPeriodLabel(l10n, p)),
              ),
          ],
          onChanged: (value) => setState(
              () => _periodIndex = value ?? 0),
        ),
      ),
      HelpDot(l10n.helpTopicVat,
        anchor: HelpAnchor.moneyVatDeclaration,
      ),
      const SizedBox(width: AppSpacing.sm),
      FilledButton.icon(
        key: const ValueKey('vat-decl-generate'),
        onPressed: () => _generate(period),
        icon: const Icon(Icons.calculate_outlined),
        label: Text(
            l10n.vatDeclGenerate),
      ),
    ],
  );
  }

  /// The period's side exports, each behind its own feature.
  List<Widget> _exportButtons(BuildContext context, VatFilingPeriod period) {
    final l10n = context.l10n;
    final enabled = ref.watch(enabledFeaturesSyncProvider);
    return [
    // #878 — the period's positions for the accountant, as
    // the letter and as a CSV, beside the declaration.
    if (enabled.contains(WorkspaceFeature.vatReport)) ...[
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
            label: Text(l10n.vatReportPdf),
          ),
          OutlinedButton.icon(
            key: const ValueKey('vat-report-csv'),
            onPressed: () => saveVatReportCsv(context, ref,
                start: period.start, end: period.end),
            icon: const Icon(Icons.table_view_outlined),
            label: Text(l10n.vatReportCsv),
          ),
        ],
      ),
    ],
    // #2354 — the EU sales list (DES, ZM, 349) of the period.
    if (enabled.contains(WorkspaceFeature.recapitulativeStatement))
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('vat-recap-csv'),
            // No workspace, no currency, no file (#2488).
            onPressed: ref.read(currentWorkspaceProvider).value == null
                ? null
                : () => saveRecapitulativeCsv(context, ref,
                    start: period.start,
                    // the period's last day, included
                    end: addCalendarDays(period.end, 1),
                    currency: ref.read(currentWorkspaceProvider).value!.currencyCode),
            icon: const Icon(Icons.public_outlined),
            label: Text(l10n
                .recapCsv),
          ),
        ),
      ),
    ];
  }

  Widget _declarationActions(BuildContext context, VatDeclaration declaration) {
    final l10n = context.l10n;
    return Wrap(
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
          l10n.vatDeclPdf),
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
      label: Text(l10n.vatDeclXml),
      onPressed: () =>
          _exportXml(declaration),
    ),
    // #2357 — the file the channel files.
    if (vatFilingFileLabel(l10n, ref.watch(saveVatFilingFileProvider).country) case final label?)
      OutlinedButton.icon(
        key: ValueKey('vat-decl-filing-${declaration.id}'),
        icon: const Icon(Icons.upload_file_outlined, size: 18),
        label: Text(label),
        onPressed: () => exportVatFilingFile(context, ref.read(saveVatFilingFileProvider), declaration),
      ),
    if (VatDeclarationRow(declaration).canMarkFiled)
      OutlinedButton.icon(
        key: ValueKey(
            'vat-decl-filed-${declaration.id}'),
        icon: const Icon(
            Icons.task_alt_outlined,
            size: 18),
        label: Text(
            l10n.vatDeclMarkFiled),
        onPressed: () =>
            _markFiled(declaration),
      ),
  ],
);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final regime = vatRegimeFromWire(workspace?.vatRegime ?? '');
    final declarationsAsync = ref.watch(vatDeclarationsProvider);
    final now = ref.watch(clockProvider).now();
    // #2357 — only periods of the length the workspace files.
    final filing = InvoiceLegal.fromJson(
            workspace?.invoiceLegal ?? const <String, dynamic>{})
        .filingPeriod;
    final periods = vatFilingPeriodsOf(now, filing);
    final period = periods[_periodIndex.clamp(0, periods.length - 1)];

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(key: const ValueKey('vat-declarations-back-button'), onPressed: () => context.go('/money')),
        title: Text(l10n.vatDeclScreenTitle),
      ),
      body: regime != VatRegime.vatRegistered
          ? Padding(
              padding: AppSpacing.lgAll,
              child: InlineBanner(
                key: const ValueKey('vat-decl-regime-gate'),
                icon: Icons.gavel_outlined,
                text: l10n.vatDeclRegimeGate,
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
                InlineBanner(
                  key: const ValueKey('vat-decl-period-note'),
                  icon: Icons.date_range_outlined,
                  text: vatWords(l10n).vatDeclPeriodNote(
                      vatDeclarationPeriodName(l10n, filing)),
                ),
                const SizedBox(height: AppSpacing.sm),
                // New declaration: period + generate.
                _periodRow(l10n, periods, period),
                ..._exportButtons(context, period),
                VatCountryRegisters(
                  start: period.start,
                  end: period.end,
                  registers: ref
                      .watch(enabledFeaturesSyncProvider)
                      .contains(WorkspaceFeature.vatReport),
                ),
                SalesTaxWorksheetButton(start: period.start, end: period.end),
                const SizedBox(height: AppSpacing.lg),
                switch (declarationsAsync) {
                  AsyncData(value: final declarations)
                      when declarations.isEmpty =>
                    EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.vatDeclEmpty,
                    ),
                  AsyncData(value: final declarations) => Column(
                      children: [
                        for (final row in VatDeclarationRows.of(declarations))
                          VatDeclarationCard(
                            row: row,
                            statusLabel: _statusLabel(l10n, row.declaration),
                            lineNote: (line) => _lineNote(l10n, line),
                            actions:
                                _declarationActions(context, row.declaration),
                          ),
                      ],
                    ),
                  AsyncError() => Text(
                      l10n.workspaceGenericError,
                    ),
                  _ => const LoadingView(),
                },
              ],
            ),
    );
  }
}
