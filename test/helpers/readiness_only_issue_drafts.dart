// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- the dry run of an issue for the test doubles: the essentials their
// readiness names, and no parties, so nothing about a channel is said.
import 'package:deskilo/features/money/domain/invoice_issue_draft.dart';
import 'package:deskilo/features/money/domain/invoice_queries.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

/// The essentials alone, from [queries]: for the test doubles, which cannot
/// tell the parties an issue would store. Nothing about a channel is said.
class ReadinessOnlyIssueDrafts implements InvoiceIssueDrafts {
  const ReadinessOnlyIssueDrafts(this.queries);

  final InvoiceQueries queries;

  @override
  Future<IssueDraft> issueDraft({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async => IssueDraft(
    missing: await queries.invoiceIssueReadiness(
      workspaceId: workspaceId,
      memberId: memberId,
      period: period,
      kind: kind,
      replacesId: replacesId,
      correctionReason: correctionReason,
    ),
  );
}
