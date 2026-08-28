// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/invoice.dart';
import '../domain/dunning.dart';
import '../domain/invoice_pdf_template.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_money_repository.dart';
export '../domain/bill_sections.dart' show currentPeriod;

import '../domain/einvoice_gateway.dart';
import '../domain/fee_band.dart';
import '../domain/ledger_entry.dart';
import '../domain/member_account.dart';
import '../domain/money_repository.dart';
import '../domain/package.dart';
import '../domain/service_item.dart';
import '../domain/statement.dart';
import '../domain/subscription_levels.dart';
import '../domain/vat_rate.dart';
import '../../../core/time/clock.dart';

part 'money_providers.g.dart';

@Riverpod(keepAlive: true)
MoneyRepository moneyRepository(Ref ref) =>
    SupabaseMoneyRepository(Supabase.instance.client);

/// The signed-in member's statement for a period ('yyyy-MM').
@riverpod
Future<Statement?> myStatement(Ref ref, String period) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return null;
  return ref.watch(moneyRepositoryProvider).fetchStatement(member.id, period);
}

/// The signed-in member's full ledger, newest first.
@riverpod
Future<List<LedgerEntry>> myLedger(Ref ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchLedger(member.id);
}

/// ONE MEMBER's money, for the dossier on their profile (#704).
///
/// The `my*` providers above answer "mine"; these answer "theirs", and
/// the server decides whether the asker may know. `member_account`,
/// `member_statement` and the RLS on `ledger_entries` / `invoices` all
/// apply the same rule — self, or an admin of that workspace — so these
/// providers add no authority of their own. The UI gate that hides the
/// card is a courtesy, not the boundary.
@riverpod
Future<MemberAccount> memberAccount(Ref ref, String memberId) async =>
    ref.read(moneyRepositoryProvider).fetchMemberAccount(memberId);

/// One member's statement for a period ('yyyy-MM').
@riverpod
Future<Statement?> memberStatement(
  Ref ref,
  String memberId,
  String period,
) async =>
    ref.read(moneyRepositoryProvider).fetchStatement(memberId, period);

/// One member's ledger, newest first — where their PAYMENTS are.
@riverpod
Future<List<LedgerEntry>> memberLedger(Ref ref, String memberId) async =>
    ref.read(moneyRepositoryProvider).fetchLedger(memberId);

/// One member's invoices, newest first.
///
/// Filtered from the workspace list rather than fetched per member: an
/// admin already holds all of them, and a plain member's copy already
/// contains only their own — RLS saw to that before it arrived.
@riverpod
Future<List<Invoice>> memberInvoices(Ref ref, String memberId) async {
  final all = await ref.watch(invoicesProvider.future);
  return [
    for (final invoice in all)
      if (invoice.memberId == memberId) invoice,
  ]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
}

/// Fee bands of the current workspace, ordered by from_pct (#128).
@Riverpod(keepAlive: true)
Future<List<FeeBand>> feeBands(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchFeeBands(workspace.id);
}

/// Offered subscription levels of the current workspace (#128).
@Riverpod(keepAlive: true)
Future<SubscriptionLevels> subscriptionLevels(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const SubscriptionLevels();
  return ref
      .watch(moneyRepositoryProvider)
      .fetchSubscriptionLevels(workspace.id);
}

/// Current period key in workspace terms ('yyyy-MM').

/// Active consumable services of the current workspace (#123).
@Riverpod(keepAlive: true)
Future<List<ServiceItem>> services(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchServices(workspace.id);
}

/// Every service incl. deactivated ones — the owner's catalog editor (#123).
@riverpod
Future<List<ServiceItem>> allServices(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(moneyRepositoryProvider)
      .fetchServices(workspace.id, includeInactive: true);
}

/// Active day packages of the current workspace — the member buy sheet
/// (migration 0042).
@riverpod
Future<List<Package>> packages(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchPackages(workspace.id);
}

/// Every package incl. deactivated ones — the owner's package editor.
@riverpod
Future<List<Package>> allPackages(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(moneyRepositoryProvider)
      .fetchPackages(workspace.id, includeInactive: true);
}

/// The workspace's VAT rates (0072). Member-readable: the rate is on the
/// bill and on every invoice, so it is not owner-only data.
///
/// Empty means VAT is off — every amount is then whatever the workspace's
/// regime says it is, and nothing about the bill changes.
@Riverpod(keepAlive: true)
Future<List<VatRate>> vatRates(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchVatRates(workspace.id);
}

/// The percentage an item with no rate of its own is taxed at — the mirror
/// of `workspace_default_vat_percent`, for previews only. The server is
/// still what stamps the ledger.
@riverpod
Future<double> defaultVatPercent(Ref ref) async {
  final rates = await ref.watch(vatRatesProvider.future);
  for (final rate in rates) {
    if (rate.isDefault) return rate.percent;
  }
  return 0;
}

/// The invoice archive (0060): RLS scopes rows — members their own,
/// admins the whole workspace.
@Riverpod(keepAlive: true)
Future<List<Invoice>> invoices(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchInvoices(workspace.id);
}

/// Invoice-PDF template of the active workspace (#454); empty while no
/// workspace is selected. The renderer additionally gates on the
/// invoicePdfTemplate feature flag at the call site.
@Riverpod(keepAlive: true)
Future<InvoicePdfTemplate> invoicePdfTemplate(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return InvoicePdfTemplate.empty;
  return ref
      .watch(moneyRepositoryProvider)
      .fetchInvoicePdfTemplate(workspace.id);
}

/// The workspace's report-image library (#488) — the names templates
/// can reference with `![name]`.
@riverpod
Future<List<String>> reportImages(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.read(moneyRepositoryProvider).listReportImages(workspace.id);
}

/// One library image's bytes, cached per name (#488).
@Riverpod(keepAlive: true)
Future<Uint8List?> reportImageBytes(Ref ref, String name) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return null;
  return ref.read(moneyRepositoryProvider).fetchReportImage(
        workspace.id,
        name,
      );
}

/// Dunning policy of the active workspace (#472); defaults while none
/// is stored. The Open tab derives reminder suggestions from it.
@Riverpod(keepAlive: true)
Future<DunningRules> dunningRules(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return DunningRules.defaults;
  return ref
      .watch(moneyRepositoryProvider)
      .fetchDunningRules(workspace.id);
}

/// The member's REAL cross-month position (#512): credit on account,
/// open remainders from any month, refunds due, net. Watches the
/// archive, the matches and the ledger so every settlement action
/// refreshes it.
@Riverpod(keepAlive: true)
Future<MemberAccount> myAccount(Ref ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return MemberAccount.empty;
  // No internal provider watches: double subscriptions (widget +
  // provider) trip Riverpod's pause bookkeeping when a screen hides.
  // Mutation sites invalidate this provider explicitly instead
  // (invalidateBookingData + the invoice actions).
  return ref.read(moneyRepositoryProvider).fetchMemberAccount(member.id);
}

/// invoiceId → its payment match (0067) — the invoice lifecycle state.
@Riverpod(keepAlive: true)
Future<Map<String, InvoiceMatch>> invoiceMatches(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  return ref
      .read(moneyRepositoryProvider)
      .fetchInvoiceMatches(workspace.id);
}

/// invoiceId → reminder count + last instant (0066), for the archive
/// badges.
@Riverpod(keepAlive: true)
Future<Map<String, ({int count, DateTime last})>> invoiceReminders(
  Ref ref,
) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  return ref
      .read(moneyRepositoryProvider)
      .fetchInvoiceReminders(workspace.id);
}

/// Whether this workspace can SEND an e-invoice (0073) — the affordance
/// only shows when the owner has configured a platform and the function is
/// deployed.
@Riverpod(keepAlive: true)
Future<EInvoiceGatewayConfig> eInvoiceGateway(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return EInvoiceGatewayConfig.notConfigured;
  return ref
      .read(moneyRepositoryProvider)
      .fetchEInvoiceGateway(workspace.id);
}

/// The owner-visible state of the platform credentials (0071): non-secret
/// fields plus the NAMES of the secrets that are set.
@riverpod
Future<EInvoiceProviderStatus> eInvoiceStatus(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) {
    return const EInvoiceProviderStatus(configured: false);
  }
  return ref.read(moneyRepositoryProvider).fetchEInvoiceStatus(workspace.id);
}

/// invoiceId → its latest transmission (0071), for the detail sheet's
/// "sent on / accepted by" line.
@Riverpod(keepAlive: true)
Future<Map<String, InvoiceTransmission>> invoiceTransmissions(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  return ref
      .read(moneyRepositoryProvider)
      .fetchInvoiceTransmissions(workspace.id);
}

/// One "ready to invoice" row of the invoicing hub: a member with
/// derivable positions for the month and no invoice yet.
typedef ToInvoiceEntry = ({String memberId, String name, int totalCents});

/// One OPEN invoice (0067 lifecycle): issued, not voided/replaced and
/// without a match yet — or with a match still awaiting its validation
/// quorum ([pendingMatch]). Only matching closes an invoice.
typedef OpenInvoiceEntry = ({Invoice invoice, InvoiceMatch? pendingMatch});

/// What the invoicing hub shows the issuer (field request: "the user
/// sees what to invoice, what to remind, what has been invoiced").
typedef InvoicingOverview = ({
  String period,
  List<ToInvoiceEntry> toInvoice,
  List<OpenInvoiceEntry> open,
});

/// yyyy-MM of the month BEFORE [now] — the natural billing moment: a
/// completed month whose positions no longer move.
String previousPeriodOf(DateTime now) {
  final prev = DateTime(now.year, now.month - 1);
  return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
}

/// The invoicing overview (issuers only — callers gate on canIssue).
///
///  * TO INVOICE: every active non-kiosk member whose PREVIOUS month
///    derives positions and has no non-voided invoice covering it.
///  * OPEN: non-voided, non-replaced invoices whose month's LIVE solde
///    (re-derived) is still positive; the live amount is what is shown
///    as outstanding. Legacy invoices without a period fall back to
///    their stored total.
///
/// Derivations run in parallel; the provider re-evaluates when the
/// archive changes (issue/void/replace all invalidate invoicesProvider).
@Riverpod(keepAlive: true)
Future<InvoicingOverview> invoicingOverview(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final invoices = await ref.watch(invoicesProvider.future);
  if (workspace == null) {
    return (
      period: previousPeriodOf(ref.read(clockProvider).now()),
      toInvoice: const <ToInvoiceEntry>[],
      open: const <OpenInvoiceEntry>[],
    );
  }
  final repo = ref.read(moneyRepositoryProvider);
  final period = previousPeriodOf(ref.read(clockProvider).now());
  final members = (await ref.watch(workspaceMembersProvider.future))
      .where((m) => m.status == MemberStatus.active && !m.isKiosk)
      .toList();
  final names = await ref.watch(memberNamesProvider.future);

  final invoicedMemberIds = {
    for (final invoice in invoices)
      if (!invoice.isVoided && invoice.period == period) invoice.memberId,
  };
  final replacedIds = {
    for (final invoice in invoices) ?invoice.replacesInvoiceId,
  };

  final toInvoice = (await Future.wait([
    for (final member in members)
      if (!invoicedMemberIds.contains(member.id))
        repo
            .previewInvoice(
              workspaceId: workspace.id,
              memberId: member.id,
              period: period,
            )
            .then<ToInvoiceEntry?>(
              (preview) => preview.lines.isEmpty
                  ? null
                  : (
                      memberId: member.id,
                      name: names[member.id] ?? '',
                      totalCents: preview.totalCents,
                    ),
              // A member whose statement fails must not sink the hub.
              onError: (Object e, StackTrace st) => null,
            ),
  ]))
      .whereType<ToInvoiceEntry>()
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  // 0067/#504 — the lifecycle is EXPLICIT: an invoice stays open until
  // FULLY settled. A pending match awaits its quorum here; a standing
  // PARTIAL match (under_accepted, remainder not written off) stays
  // open too — the rest is owed until the validated write-off.
  final matches = await ref.watch(invoiceMatchesProvider.future);
  bool stillOpen(InvoiceMatch? match) =>
      match == null ||
      match.pending ||
      (match.resolution == 'under_accepted' && match.writeoffAt == null);
  final open = [
    for (final invoice in invoices)
      if (!invoice.isVoided &&
          !replacedIds.contains(invoice.id) &&
          stillOpen(matches[invoice.id]))
        (invoice: invoice, pendingMatch: matches[invoice.id]),
  ]..sort((a, b) => a.invoice.issuedAt.compareTo(b.invoice.issuedAt));

  return (period: period, toInvoice: toInvoice, open: open);
}
