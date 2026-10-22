// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 — the purchase and cost cards of the analytics page: what each
// figure is, what it leaves out, and how it is computed.
import 'package:intl/intl.dart';

import '../../../../core/time/workspace_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_result.dart';
import '../../domain/cost_allocation_rules.dart';
import '../../domain/kpi_purchases.dart';
import 'bi_module_section.dart';
import 'cost_allocation_editor.dart';

// #2582 — a count of documents, in no currency.
String _countCell(num? v, String locale, String? currency) =>
    v == null ? '—' : NumberFormat.decimalPattern(locale).format(v);

PurchaseSummaryKpi? _purchase(BiMeasure m) => m.detail as PurchaseSummaryKpi?;

/// #2582 — a purchase card: its figure, what it cannot know, and how it is
/// computed.
BiModuleView _purchaseView(
  String Function(AppLocalizations l10n) title,
  String Function(AppLocalizations l10n) definition, {
  bool count = false,
  String Function(PurchaseSummaryKpi k, AppLocalizations l10n, String locale)?
  basis,
  String Function(AppLocalizations l10n)? always,
}) => BiModuleView(
  title: title,
  value: count ? _countCell : biMoneyCell,
  basis: (m, l10n, locale) => switch (_purchase(m)) {
    final k? when basis != null && !m.unknown => basis(k, l10n, locale),
    _ => '',
  },
  notes: (m, l10n, locale) => [
    if (m.reasons.contains('currency_mix') && !count) l10n.biFinanceCurrencyMix,
    if (m.reasons.contains('amount_not_exact')) l10n.biFinanceNotExact,
    if (m.reasons.contains('period_not_over')) l10n.biFinancePartial,
    if (count && m.reasons.contains('current_queue'))
      l10n.biPurchasesCurrentQueue,
    if (always != null) always(l10n),
  ],
  details: (m, l10n, locale) => [
    definition(l10n),
    if (_purchase(m) case final k?)
      l10n.biFinanceComputed(
        DateFormat.yMd(locale).format(WorkspaceTime.wall(k.computedAt)),
      ),
  ],
);

CostSummaryKpi? _cost(BiMeasure m) => m.detail as CostSummaryKpi?;

/// #2582 C2 — a cost card: what it leaves out or cannot know, and how it is
/// computed.
BiModuleView _costView(
  String Function(AppLocalizations l10n) title,
  String Function(AppLocalizations l10n) definition, {
  String Function(AppLocalizations l10n)? always,
  String Function(CostSummaryKpi k, AppLocalizations l10n, String locale)?
  basis,
}) => BiModuleView(
  title: title,
  value: biMoneyCell,
  basis: (m, l10n, locale) => switch (_cost(m)) {
    final k? when basis != null => basis(k, l10n, locale),
    _ => '',
  },
  notes: (m, l10n, locale) => [
    if (m.reasons.contains('currency_mix')) l10n.biFinanceCurrencyMix,
    if (m.reasons.contains('amount_not_exact')) l10n.biFinanceNotExact,
    if (m.reasons.contains('period_not_over')) l10n.biFinancePartial,
    if (_cost(m) case final k? when k.unresolvedLines > 0)
      l10n.biCostsUnresolved('${k.unresolvedLines}'),
    if (_cost(m) case final k? when k.unqualifiedLines > 0)
      l10n.biCostsUnqualified('${k.unqualifiedLines}'),
    if (m.unknown && m.reasons.contains('asset_register_off'))
      l10n.biAssetsRegisterOff,
    if (m.unknown && m.reasons.contains('book_coverage_incomplete'))
      l10n.biDepreciationIncomplete,
    if (m.unknown && m.reasons.contains('no_contracts'))
      l10n.biCommitmentsNoContracts,
    if (always != null) always(l10n),
  ],
  details: (m, l10n, locale) => [
    definition(l10n),
    if (_cost(m) case final k?)
      l10n.biFinanceComputed(
        DateFormat.yMd(locale).format(WorkspaceTime.wall(k.computedAt)),
      ),
  ],
);

CostAllocationKpi? _allocation(BiMeasure m) =>
    m.detail as CostAllocationKpi?;

/// #2582 C2 — the shared costs spread over the resources: what went where,
/// what no rule spreads, and the rule revisions behind it. An analysis:
/// nobody is billed by it.
final _allocationView = BiModuleView(
  title: (l10n) => l10n.biAllocationTitle,
  value: biMoneyCell,
  basis: (m, l10n, locale) => switch (_allocation(m)) {
    final k? => l10n.biAllocationBasis(
      biMoneyCell(k.directMinor, locale, k.currency),
      biMoneyCell(k.sharedMinor, locale, k.currency),
      biMoneyCell(k.unallocatedMinor, locale, k.currency),
    ),
    _ => '',
  },
  notes: (m, l10n, locale) => [
    if (m.reasons.contains('currency_mix')) l10n.biFinanceCurrencyMix,
    if (m.reasons.contains('amount_not_exact')) l10n.biFinanceNotExact,
    if (m.reasons.contains('period_not_over')) l10n.biFinancePartial,
    if (_allocation(m) case final k? when (k.unallocatedMinor ?? 0) != 0)
      l10n.biAllocationUnallocated(
        biMoneyCell(k.unallocatedMinor, locale, k.currency),
      ),
    if (_allocation(m) case final k? when k.conflictingLines > 0)
      l10n.biAllocationConflicts('${k.conflictingLines}'),
    l10n.biAllocationNotBilled,
  ],
  details: (m, l10n, locale) => [
    l10n.biAllocationDefinition,
    if (_allocation(m) case final k? when k.rulesUsed.isNotEmpty)
      l10n.biAllocationRevisions(
        [
          for (final (basis, revision) in k.rulesUsed)
            l10n.biAllocationRevision(basis, '$revision'),
        ].join('; '),
      ),
    if (_allocation(m) case final k?)
      l10n.biFinanceComputed(
        DateFormat.yMd(locale).format(WorkspaceTime.wall(k.computedAt)),
      ),
  ],
  action: (context) => const CostAllocationRulesButton(),
);

/// The purchase and cost modules' views (#2582).
final purchaseModuleViews = <String, BiModuleView>{
  'purchases.ap_outstanding': _purchaseView(
    (l10n) => l10n.biPurchasesApTitle,
    (l10n) => l10n.biPurchasesApDefinition,
  ),
  'purchases.member_reimbursements_due': _purchaseView(
    (l10n) => l10n.biPurchasesMemberDueTitle,
    (l10n) => l10n.biPurchasesMemberDueDefinition,
  ),
  'purchases.pending_reviews': _purchaseView(
    (l10n) => l10n.biPurchasesPendingTitle,
    (l10n) => l10n.biPurchasesPendingDefinition,
    count: true,
    basis: (k, l10n, locale) => l10n.biPurchasesPendingBasis(
      biMoneyCell(k.pendingMinor, locale, k.currency),
    ),
  ),
  'cash.recorded_outflows': _purchaseView(
    (l10n) => l10n.biCashOutflowsTitle,
    (l10n) => l10n.biCashOutflowsDefinition,
    basis: (k, l10n, locale) => l10n.biCashOutflowsBasis('${k.outflows}'),
    always: (l10n) => l10n.biCashNotBankBalance,
  ),
  'purchases.operating_costs': _costView(
    (l10n) => l10n.biCostsOperatingTitle,
    (l10n) => l10n.biCostsOperatingDefinition,
  ),
  'assets.acquisitions': _costView(
    (l10n) => l10n.biAssetsAcquisitionsTitle,
    (l10n) => l10n.biAssetsAcquisitionsDefinition,
    always: (l10n) => l10n.biAssetsNotCost,
  ),
  'finance.recorded_contribution': _costView(
    (l10n) => l10n.biContributionTitle,
    (l10n) => l10n.biContributionDefinition,
    always: (l10n) => l10n.biContributionNotProfit,
  ),
  'assets.book_depreciation': _costView(
    (l10n) => l10n.biDepreciationTitle,
    (l10n) => l10n.biDepreciationDefinition,
    always: (l10n) => l10n.biDepreciationNoCash,
  ),
  'finance.contribution_after_depreciation': _costView(
    (l10n) => l10n.biAfterDepreciationTitle,
    (l10n) => l10n.biAfterDepreciationDefinition,
    always: (l10n) => l10n.biContributionNotProfit,
  ),
  'purchases.unbilled_commitments': _costView(
    (l10n) => l10n.biCommitmentsTitle,
    (l10n) => l10n.biCommitmentsDefinition,
    basis: (k, l10n, locale) => l10n.biCommitmentsBasis(
      biMoneyCell(k.unbilledOverdueMinor, locale, k.currency),
      biMoneyCell(k.unbilledUpcomingMinor, locale, k.currency),
    ),
    always: (l10n) => l10n.biCommitmentsNotForecast,
  ),
  'finance.cost_allocation': _allocationView,
};
