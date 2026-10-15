// SPDX-License-Identifier: AGPL-3.0-or-later




import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/locale/report_language.dart';
import '../../../../core/time/date_text.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/workspace.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/bill_pdf.dart';
import '../../domain/bill_sections.dart';
import '../../domain/invoice_line_text.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/invoice_report.dart';
import '../../domain/ledger_entry.dart';
import '../../domain/report_data_letters.dart';
import '../../domain/statement.dart';
import '../../providers/money_providers.dart';
import '../../providers/usage_providers.dart';
import '../invoice_documents.dart';
import '../period_label.dart';
import '../report_actions.dart';
import '../report_facts_of.dart';
import '../report_layout_actions.dart';
import '../report_strings_l10n.dart';
import '../usage_report_data.dart';
import '../widgets/bill_view.dart';

/// The documents a member prints from the Money tab: the self-service
/// letters (#494) and the month's bill (#133, ADR 0008). Split out of
/// `_MoneyScreenState` (#2494); it holds no screen state, only the [State]
/// the dialogs and snackbars belong to.
class MoneyMemberDocuments {
  MoneyMemberDocuments(this._state, this._ref);

  final State _state;
  final WidgetRef _ref;

  BuildContext get _context => _state.context;

  /// #494 — one of the member's self-service letter documents: quick
  /// in-app view, download, or share.
  Future<void> memberDoc(String docId, String period) async {
    final l10n = _context.l10n;
    await warmLetterDocProviders(_ref, docId);
    if (!_context.mounted) return;
    final me = _ref.read(myMemberProvider).value;
    final names = _ref.read(memberNamesProvider).value ?? const {};
    if (me == null) return;
    // #496 — MY documents print in MY language chain.
    final String language;
    try {
      language = resolveMemberReportLanguage(_ref,
          memberLocale:
              _ref.read(myMemberProvider).value?.preferredLocaleOverride ??
              _ref.read(myProfileProvider).value?.preferredLocale ?? '');
    } on AmbiguousReportLanguage {
      AppSnack.error(
        _context,
        l10n.reportLanguageAmbiguous,
      );
      return;
    }
    final docL10n = l10nForLanguage(language);
    if (docId == 'usage') {
      // #873 — the figures come from the statement and the records.
      await _ref.read(memberStatementProvider(me.id, period).future);
      await _ref.read(usageRecordsProvider(period).future);
      if (!_context.mounted) return;
    }
    final data = _letterData(
        docId, period, docL10n, language,
        (id: me.id, name: names[me.id] ?? '', pct: me.subscriptionPct));
    final report = renderLetterDoc(_context, _ref,
        docId: docId, data: data, language: language);
    final title = switch (docId) {
      'agreement' => docL10n.reportDocAgreement,
      'usage' => docL10n.reportDocUsage,
      _ => docL10n.reportDocPayments,
    };
    // #514 — the shared triad: quick view / save / share.
    await runReportActions(
      _context,
      _ref,
      keyPrefix: 'member-doc',
      logMessage: 'member report pdf failed',
      render: () => report,
      buildPdf: () async {
        final pdf = await letterDocPdf(_context, _ref,
            report: report,
            title: title,
            layoutXml:
                letterLayoutXml(_ref, docId: docId, language: language),
            data: data);
        return (bytes: pdf.bytes, fileName: pdf.fileName);
      },
    );
  }

  Map<String, Object?> _letterData(
    String docId,
    String period,
    AppLocalizations docL10n,
    String language,
    ({String id, String name, int pct}) who,
  ) =>
      switch (docId) {
        'agreement' => agreementReportData(
            reportStringsFor(_context, l10n: docL10n, localeName: language),
            agreementFactsOf(_ref),
            memberName: who.name,
            subscriptionPct: who.pct),
        'usage' => usageReportData(_context, _ref,
            period: period,
            memberId: who.id,
            memberName: who.name,
            l10nOverride: docL10n,
            localeName: language),
        _ => paymentsReportData(
            reportStringsFor(_context, l10n: docL10n, localeName: language),
            paymentsFactsOf(_ref, period),
            period: period,
            memberName: who.name),
      };

  /// Renders the visible period's bill as a PDF — the exact sections
  /// [BillView] shows via [buildBillSections] — and hands it to the system
  /// share sheet (#133, ADR 0008).
  Future<void> exportBill(
    Statement statement, {
    required DateTime month,
    required String nowPeriod,
  }) async {
    final context = _context;
    final l10n = context.l10n;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final workspace = _ref.read(currentWorkspaceProvider).value;
    final member = _ref.read(myMemberProvider).value;
    if (workspace == null || member == null) return;
    final ledger = _ref.read(myLedgerProvider).value ?? const <LedgerEntry>[];
    final pendingEvents = _ref.read(eventsProvider).value ?? const [];
    final memberName =
        _ref.read(memberNamesProvider).value?[member.id] ?? '';
    final monthLabel = DateFormat.yMMMM(locale).format(month);

    final strings = _billStrings(l10n, statement, locale, month);
    final sections = buildBillSections(
      period: statement.period, memberId: member.id, ledger: ledger,
      pendingEvents: pendingEvents, nowPeriod: nowPeriod,
    );
    final document = BillDocument(statement: statement,
        sections: sections,
        currencyCode: workspace.currencyCode,
        workspaceName: workspace.name,
        memberName: memberName,
        periodLabel: monthLabel,
        strings: strings,
        locale: locale);
    final report = _statementReport(document, workspace);
    await runReportActions(
      context,
      _ref,
      keyPrefix: 'bill-export',
      logMessage: 'bill PDF export failed',
      render: () => report,
      buildPdf: () => _buildBillPdf(document, report, workspace, l10n),
    );
  }

  BillPdfStrings _billStrings(
    AppLocalizations l10n,
    Statement statement,
    String? locale,
    DateTime month,
  ) =>
      BillPdfStrings(
        title: l10n.billPdfTitle,
        subscription: subscriptionLabel(
            reportStringsOf(l10n), statement.subscriptionPct,
            association: _ref.watch(sellerIsAssociationProvider),
            // #1000 — the bill's position names its month too.
            month: monthNameOf(locale, yearMonth(month.year, month.month))),
        entitlement: l10n.billEntitlement(
          statement.usedHalfDays,
          statement.includedHalfDays,
          statement.openDays,
        ),
        overage: l10n.billOverage(statement.extraHalfDays),
        accessorySupplements: l10n.billAccessorySupplements,
        services: l10n.billServices,
        servicesTotal: l10n.billServicesTotal,
        serviceFallback: l10n.ledgerCategoryService,
        packages: l10n.billPackages,
        openPositions: l10n.billOpenPositions,
        pendingBadge: l10n.billPendingBadge,
        paymentsCredits: l10n.billPaymentsCredits,
        paymentFallback: l10n.ledgerCategoryPayment,
        expenseFallback: l10n.ledgerCategoryExpense,
        adjustmentFallback: l10n.ledgerCategoryAdjustment,
        eventPayment: l10n.eventTypePayment,
        eventExpense: l10n.eventTypeExpense,
        eventAdjustment: l10n.eventTypeAdjustment,
        balance: l10n.billBalance,
        settled: l10n.billSettled,
        outstanding: l10n.billOutstanding,
      );

  /// #514 — the shared triad, for the bill too: the statement report (owner
  /// template or default bands) is the quick view; download and share build
  /// the same PDF the save-only path used to.
  InvoiceReport _statementReport(BillDocument document, Workspace workspace) {
    final data = statementReportData(
      reportStringsFor(_context),
      statement: document.statement,
      workspaceName: workspace.name,
      memberName: document.memberName,
      periodLabel: document.periodLabel,
      currencyCode: workspace.currencyCode,
      workspace: workspace,
    );
    final template = _ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.invoicePdfTemplate)
        ? _ref.read(invoicePdfTemplateProvider).value
        : null;
    final bands = template?.statementBands;
    // #880 — the owner's texts beside the data.
    final texts = template?.texts ?? const <String, String>{};
    return (bands != null
            ? renderReportBands(
                bands: bands, data: withOwnerTexts(data, texts))
            : null) ??
        buildBillReport(document);
  }

  Future<({Uint8List bytes, String fileName})> _buildBillPdf(
    BillDocument document,
    InvoiceReport report,
    Workspace workspace,
    AppLocalizations l10n,
  ) async {
    // Embedded Roboto: base-14 PDF fonts cannot encode '€'/'−' (#133).
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final bytes = await buildBillPdf(
        BillDocument(statement: document.statement,
            sections: document.sections,
            currencyCode: document.currencyCode,
            workspaceName: document.workspaceName,
            memberName: document.memberName,
            periodLabel: document.periodLabel,
            strings: document.strings,
            locale: document.locale,
            report: report,
            reportImages: await resolveReportImages(_ref, report)),
        baseFont: pw.Font.ttf(regular),
        boldFont: pw.Font.ttf(bold),
        pageLabel: l10n.invoicePdfPage,
        watermark: workspace.isDevelopment ? (l10n.developmentWatermark) : '');
    return (
      bytes: bytes,
      fileName: 'deskilo-bill-${document.statement.period}.pdf',
    );
  }
}
