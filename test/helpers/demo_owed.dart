// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Independent accounting oracle: account-owned source invoices, payment
// decisions and credit notes, grouped by their issuing business and currency.
import 'package:deskilo/core/demo/demo_fixture.dart';

Map<String, int> demoOwedFromTheSpaces(DemoFixture f) {
  final balances = <(String, String), int>{};
  for (final space in f.personalSpaces) {
    final memberIds = {
      for (final m in [space.workspaces.myMember, ...space.workspaces.otherMembers])
        if (m.userId == f.auth.currentUserId && !m.isKiosk) m.id,
    };
    for (final i in space.money.invoices) {
      if (!memberIds.contains(i.memberId) || i.isVoided ||
          i.settledByInvoiceId != null) {
        continue;
      }
      final match = space.money.invoiceMatchesStore[i.id];
      var open = i.totalCents;
      if (match != null) {
        if (match.status == 'pending' || match.resolution != 'under_accepted' ||
            match.writeoffAt != null) {
          continue;
        }
        open -= match.paidCents;
      }
      final payee = (i.workspaceId, i.currency);
      balances[payee] = (balances[payee] ?? 0) + open;
    }
  }
  final out = <String, int>{};
  for (final entry in balances.entries) {
    if (entry.value > 0) {
      out[entry.key.$2] = (out[entry.key.$2] ?? 0) + entry.value;
    }
  }
  return out;
}
