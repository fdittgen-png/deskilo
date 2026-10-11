// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2383 — stand-ins only tests construct. They lived in `lib/` beside the
// interface they implement; nothing in the app ever built one, so they
// live here now and the dead-code lint keeps `lib/` free of their kind.
import 'package:deskilo/features/events/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/application/pending_invitation.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';

/// The "last seen" marker of an update feed, held in memory.
class InMemoryUpdateSeenStore implements UpdateSeenStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? next) async => value = next;
}

/// The pending invitation, held in memory instead of secure storage.
class InMemoryPendingInvitationStore implements PendingInvitationStore {
  InMemoryPendingInvitationStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

/// A finance KPI source with no server to sum invoices on.
class UnavailableFinanceKpiRepository implements FinanceKpiRepository {
  const UnavailableFinanceKpiRepository();

  @override
  Future<FinanceSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => throw const KpiUnavailable('no server in this mode');
}
