// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- the Demo's dry run of an issue: the essentials its session names
// and, when none is missing, the parties the issue would store, so the
// channel's gaps are told before the number is taken, as on the server.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../../features/money/domain/invoice_issue_draft.dart';
import '../../../../features/money/domain/invoice_queries.dart';
import 'demo_invoice_queries.dart';

class DemoInvoiceIssueDrafts implements InvoiceIssueDrafts {
  const DemoInvoiceIssueDrafts(this.queries);

  final InvoiceQueries queries;

  @override
  Future<IssueDraft> issueDraft({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async {
    final missing = await queries.invoiceIssueReadiness(
      workspaceId: workspaceId,
      memberId: memberId,
      period: period,
      kind: kind,
      replacesId: replacesId,
      correctionReason: correctionReason,
    );
    final q = queries;
    final parties = missing.isEmpty && q is DemoInvoiceQueries
        ? q.buyers.parties?.call(memberId)
        : null;
    return IssueDraft(
      missing: missing,
      seller: parties?.seller,
      buyer: parties?.buyer,
    );
  }
}
