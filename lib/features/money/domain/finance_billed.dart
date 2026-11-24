// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the documents a customer reads through a billing-access grant,
// grouped by the debtor they are owed by. Two debtors of one seller and one
// currency stay two groups: a person buying personally and for a company holds
// two subjects, and neither one's credit lowers the other's debt. Split from
// `finance_overview.dart`, which re-exports it.
import 'finance_overview.dart';

/// One billing-only subject of one business, with its documents.
class BilledSubject {
  const BilledSubject({
    required this.networkId,
    required this.workspaceId,
    required this.workspaceName,
    required this.subjectId,
    required this.invoices,
  });

  /// The business, qualified by its installation.
  final String networkId, workspaceId, workspaceName;

  /// The seller-local financial subject (`members.id`) the documents are owed by.
  /// Empty from a host that did not name it.
  final String subjectId;

  /// Newest first.
  final List<FinanceInvoice> invoices;

  /// What stays open, per currency: this subject's invoices to pay less its
  /// own credit notes, never another subject's and never across currencies.
  Map<String, int> get openByCurrency {
    final out = <String, int>{};
    for (final i in invoices) {
      if (!i.state.owed) continue;
      out[i.currency] = (out[i.currency] ?? 0) + i.remainingCents;
    }
    return {for (final code in out.keys.toList()..sort()) code: out[code]!};
  }
}

extension FinanceBilled on FinanceOverview {
  /// The billing-only documents, one group per business and subject, by
  /// business name and then subject.
  List<BilledSubject> get billedGroups {
    final groups = <(String, String), List<FinanceInvoice>>{};
    for (final i in billed) {
      groups
          .putIfAbsent((i.networkId, i.financialSubjectId ?? ''), () => [])
          .add(i);
    }
    return [
      for (final e in groups.entries)
        BilledSubject(
          networkId: e.key.$1,
          workspaceId: e.value.first.workspaceId,
          workspaceName: e.value.first.workspaceName,
          subjectId: e.key.$2,
          invoices: [...e.value]
            ..sort((a, b) {
              final byTime = b.issuedAt.compareTo(a.issuedAt);
              return byTime != 0 ? byTime : b.id.compareTo(a.id);
            }),
        ),
    ]..sort((a, b) {
      final byName = a.workspaceName.compareTo(b.workspaceName);
      if (byName != 0) return byName;
      final bySource = a.networkId.compareTo(b.networkId);
      return bySource != 0 ? bySource : a.subjectId.compareTo(b.subjectId);
    });
  }
}
