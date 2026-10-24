// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C5 — Me › Finances reads every workspace host my personal account
// names (#2563), grouped by installation exactly as My reservations reads
// them (#2553 C2). Composed here, where both features are: money sits
// below me in the feature graph.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/me/application/my_reservation_sources.dart';
import '../features/me/providers/me_providers.dart';
import '../features/money/domain/finance_hosts.dart';
import '../features/money/providers/finance_host_providers.dart';

/// Puts the hosts in a scope's overrides (main.dart, the demo container).
final Override financeHostsFromMe = financeHostsProvider.overrideWith((
  ref,
) async {
  final refs = await ref.watch(personalWorkspaceRefsProvider.future);
  return [
    for (final source in myReservationSourcesOf(refs))
      FinanceHost(
        installationId: source.installationId,
        workspaceIds: source.workspaceIds,
        hostedHere: source.hostedHere,
        labels: source.labels,
      ),
  ];
});
