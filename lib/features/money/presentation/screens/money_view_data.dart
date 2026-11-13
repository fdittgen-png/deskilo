// SPDX-License-Identifier: AGPL-3.0-or-later




import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../events/domain/workspace_event.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/overage_policy.dart';
import '../../../workspace/domain/payment_instructions.dart';
import '../../../workspace/domain/workspace.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/ledger_entry.dart';
import '../../domain/member_account.dart';
import '../../domain/payment_intent.dart';
import '../../domain/statement.dart';
import '../../providers/money_providers.dart';
import '../invoice_status.dart';
import '../widgets/online_payment_status_card.dart';

/// Everything the Money tab READS, watched once per build (#2494): the
/// space, the member, the browsed month's statement, the ledger and the
/// derived values the layouts share. Each `ref.watch` is the one the screen
/// made before it was split — the scope of a rebuild is unchanged.
class MoneyViewData {
  MoneyViewData._({
    this.reads = const ReadsAnswer.answered(),
    required this.workspace,
    required this.member,
    required this.statementAsync,
    required this.settlement,
    required this.ledger,
    required this.pendingEvents,
    required this.onlineAttempts,
    required this.account,
    required this.features,
    required this.format,
  });

  factory MoneyViewData.watch(WidgetRef ref, String period) {
    final member = ref.watch(myMemberProvider).value;
    final statementAsync = ref.watch(myStatementProvider(period));
    final invoices = ref.watch(invoicesProvider);
    final matches = ref.watch(invoiceMatchesProvider);
    final ledger = ref.watch(myLedgerProvider);
    final events = ref.watch(eventsProvider);
    final intents = ref.watch(myPaymentIntentsProvider);
    return MoneyViewData._(
      // #3680 — the bill is shown only when every read it is built from
      // answered; the empty fallbacks below are never on screen otherwise.
      reads: ReadsAnswer.of([invoices, matches, ledger, events, intents]),
      workspace: ref.watch(currentWorkspaceProvider).value,
    format: ref.watch(appFormatProvider),
      member: member,
      statementAsync: statementAsync,
      // #510 — once an invoice covers the browsed month, the DOCUMENT
      // decides settled/outstanding (its payment usually lands in a later
      // month). RLS scopes both providers to the member's own rows.
      settlement: settlementOfPeriod(
        period,
        member?.id ?? '',
        invoices.value ?? const [], // empty-ok: shown only when `reads` answered
        matches.value ?? const {}, // empty-ok: shown only when `reads` answered
      ),
      ledger: ledger.value ?? const <LedgerEntry>[], // empty-ok: shown only when `reads` answered
      pendingEvents: events.value ?? const [], // empty-ok: shown only when `reads` answered
      // #1637 — the month's online attempts the provider has not confirmed.
      onlineAttempts: OnlinePaymentStatusCard.shown(
        intents.value ?? const [], // empty-ok: shown only when `reads` answered
        period,
      ),
      // #512 — the REAL cross-month position, above the per-month bill.
      account: ref.watch(myAccountProvider).value,
      features: ref.watch(enabledFeaturesSyncProvider),
    );
  }

  /// #3680 — whether the reads the bill is built from answered.
  final ReadsAnswer reads;

  /// Repeats the reads the bill is built from.
  static void retry(WidgetRef ref) => ref
    ..invalidate(invoicesProvider)
    ..invalidate(invoiceMatchesProvider)
    ..invalidate(myLedgerProvider)
    ..invalidate(eventsProvider)
    ..invalidate(myPaymentIntentsProvider);

  /// #2577 — only the gates, for a page that shows doors and no statement:
  /// nothing of the month is read.
  factory MoneyViewData.gates(WidgetRef ref) => MoneyViewData._(
    workspace: ref.watch(currentWorkspaceProvider).value,
    format: ref.watch(appFormatProvider),
    member: ref.watch(myMemberProvider).value,
    statementAsync: const AsyncValue.data(null),
    settlement: null,
    ledger: const [],
    pendingEvents: const [],
    onlineAttempts: const [],
    account: null,
    features: ref.watch(enabledFeaturesSyncProvider),
  );

  final Workspace? workspace;
  final Member? member;
  final AsyncValue<Statement?> statementAsync;
  final PeriodSettlement? settlement;
  final List<LedgerEntry> ledger;
  final List<WorkspaceEvent> pendingEvents;
  final List<PaymentIntent> onlineAttempts;
  final MemberAccount? account;
  final Set<WorkspaceFeature> features;

  /// The permission names used by the purchase entry points.
  static Set<String> purchasePermissionNames(WidgetRef ref) => {
    for (final permission in ref.watch(myPermissionsProvider)) permission.wireName,
  };

  Statement? get statement => statementAsync.value;

  /// #3308 — passes sold at the desk to guests.
  // #3550 — a pass books a place for its guest.
  bool get guestPassesOn =>
      _on(WorkspaceFeature.placeBooking) && _on(WorkspaceFeature.guestPasses);
  bool _on(WorkspaceFeature f) => features.contains(f);

  // The feature gates the Money tab reads; callers ask the question, not the
  // enum (#2494).
  bool get pdfExportOn => _on(WorkspaceFeature.pdfExport);
  bool get eventsTabOn => _on(WorkspaceFeature.eventsTab);
  bool get financeFacesOn => _on(WorkspaceFeature.financeFaces);
  bool get onlinePaymentsOn => _on(WorkspaceFeature.onlinePayments);
  bool get scheduledExpensesOn => _on(WorkspaceFeature.scheduledExpenses);
  bool get servicesOn => _on(WorkspaceFeature.services);
  bool get invoicingOn => _on(WorkspaceFeature.invoicing);
  bool get documentsOn => _on(WorkspaceFeature.documents);
  bool get usageRecordsOn => _on(WorkspaceFeature.usageRecords);
  bool get priceNegotiationsOn => _on(WorkspaceFeature.priceNegotiations);

  /// #494, #502 — the member's self-service letters.
  bool get memberReportsOn => _on(WorkspaceFeature.memberReports);

  /// #873 — the consumption report needs the records AND the letters.
  bool get usageReportOn =>
      memberReportsOn && _on(WorkspaceFeature.usageReport);

  /// #934 — the treasurer's view and the guided repartition are for those
  /// who manage the money.
  bool get statusToolOn =>
      _on(WorkspaceFeature.workspaceStatus) && (member?.isAdmin ?? false);
  /// #828, #3597 — the shared-expense distribution.
  bool get expenseRepartitionOn => _on(WorkspaceFeature.expenseRepartition);
  bool get repartitionWizardOn =>
      _on(WorkspaceFeature.expenseRepartitionWizard) &&
      (member?.isAdmin ?? false);

  /// #2567 — the suppliers are master data of the expense flows, for those
  /// who manage the money (the server decides who may write).
  bool get suppliersOn =>
      _on(WorkspaceFeature.supplyExpenses) && (member?.isAdmin ?? false);

  /// #2863 — the supplier form may ask a company registry: the same
  /// verification VIES gives a member's VAT number.
  bool get supplierLookupOn => _on(WorkspaceFeature.viesVerification);

  /// #2573 — the purchase documents: a member's own receipts, and the
  /// supplier bills of those who manage them.
  bool get purchasesOn => _on(WorkspaceFeature.purchases);
  bool get premisesLeaseOn => _on(WorkspaceFeature.premisesLease);
  bool get assetRegisterOn => _on(WorkspaceFeature.assetRegister);
  bool get externalRoomsOn => _on(WorkspaceFeature.externalRooms);
  bool get accountingPeriodsOn => _on(WorkspaceFeature.accountingPeriods);
  bool get accountingConnectorsOn =>
      _on(WorkspaceFeature.accountingConnectors);
  bool get bankImportOn => _on(WorkspaceFeature.bankImport);
  bool get vatManagementOn => _on(WorkspaceFeature.vatManagement);
  bool get vatDeclarationsOn => _on(WorkspaceFeature.vatDeclarations);
  bool get numberSequencesOn => _on(WorkspaceFeature.numberSequences);
  bool get moneyTabOn => _on(WorkspaceFeature.moneyTab);

  /// 0042 — the owner put this member on the package plan.
  bool get onPackagePlan => member?.overagePolicy == OveragePolicy.package;

  /// #155 — how-to-pay card on an outstanding balance.
  PaymentInstructions get paymentInstructions =>
      PaymentInstructions.fromDb(workspace?.paymentInstructions ?? const {});

  String get currencyCode => workspace?.currencyCode ?? format.currencyCode;

  /// #3484 — the member's formats, for the amounts this view prints.
  final AppFormat format;

  MoneyFormat get currency => format.moneyIn(currencyCode);

  /// The online-payment card above the bill, when an attempt is pending.
  List<Widget> get attemptsCard => [
        if (onlineAttempts.isNotEmpty) ...[
          OnlinePaymentStatusCard(
            intents: onlineAttempts,
            currencyCode: currencyCode,
          ),
          const SizedBox(height: 8),
        ],
      ];
}
