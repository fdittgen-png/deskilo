// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/invoice.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_money_repository.dart';
export '../domain/bill_sections.dart' show currentPeriod;

import '../domain/fee_band.dart';
import '../domain/ledger_entry.dart';
import '../domain/money_repository.dart';
import '../domain/package.dart';
import '../domain/service_item.dart';
import '../domain/statement.dart';
import '../domain/subscription_levels.dart';

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

/// The invoice archive (0060): RLS scopes rows — members their own,
/// admins the whole workspace.
@Riverpod(keepAlive: true)
Future<List<Invoice>> invoices(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(moneyRepositoryProvider).fetchInvoices(workspace.id);
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

/// One "ready to invoice" row of the invoicing hub: a member with
/// derivable positions for the month and no invoice yet.
typedef ToInvoiceEntry = ({String memberId, String name, int totalCents});

/// One OPEN invoice: issued, not voided/replaced, and the month's LIVE
/// solde is still positive — payments recorded after issue settle it
/// automatically.
typedef OpenInvoiceEntry = ({Invoice invoice, int liveSoldeCents});

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
      period: previousPeriodOf(DateTime.now()),
      toInvoice: const <ToInvoiceEntry>[],
      open: const <OpenInvoiceEntry>[],
    );
  }
  final repo = ref.read(moneyRepositoryProvider);
  final period = previousPeriodOf(DateTime.now());
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

  final candidates = [
    for (final invoice in invoices)
      if (!invoice.isVoided &&
          !replacedIds.contains(invoice.id) &&
          invoice.totalCents > 0)
        invoice,
  ];
  final open = (await Future.wait([
    for (final invoice in candidates)
      invoice.period == null
          ? Future<OpenInvoiceEntry?>.value(
              (invoice: invoice, liveSoldeCents: invoice.totalCents))
          : repo
              .previewInvoice(
                workspaceId: workspace.id,
                memberId: invoice.memberId,
                period: invoice.period!,
              )
              .then<OpenInvoiceEntry?>(
                (preview) => preview.totalCents > 0
                    ? (invoice: invoice, liveSoldeCents: preview.totalCents)
                    : null,
                onError: (Object e, StackTrace st) =>
                    (invoice: invoice, liveSoldeCents: invoice.totalCents),
              ),
  ]))
      .whereType<OpenInvoiceEntry>()
      .toList()
    ..sort((a, b) => a.invoice.issuedAt.compareTo(b.invoice.issuedAt));

  return (period: period, toInvoice: toInvoice, open: open);
}
