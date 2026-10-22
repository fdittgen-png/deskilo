// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A capacity repository with no server behind it: every read answers
// `KpiUnavailable`, so a test can prove the tile says so rather than
// inventing a figure.
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';

class UnavailableKpiRepository implements KpiRepository {
  const UnavailableKpiRepository();

  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async => throw const KpiUnavailable('no server in this mode');
}
