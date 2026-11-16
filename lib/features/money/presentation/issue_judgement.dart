// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- before the number is taken, what an issue still needs and what its
// e-invoice will need. The essentials refuse the issue; the channel's gaps are
// a warning (a paper or PDF invoice is valid without them). The gaps are
// judged on the parties the issue would store, with the very function the
// send sheet uses on the stored ones, so the two moments cannot disagree.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/trace_logger.dart';
import '../../workspace/domain/workspace.dart';
import '../domain/einvoice_channel_check.dart';
import '../domain/einvoice_gateway.dart';
import '../providers/money_providers.dart';
import 'e_invoice_identity.dart';

/// What stops the issue, and what the e-invoice will still need.
typedef IssueJudgement = ({List<String> missing, List<ChannelGap> gaps});

/// Nothing known yet.
const IssueJudgement noJudgement = (missing: <String>[], gaps: <ChannelGap>[]);

/// One issue to judge: whose, which month, and what it corrects.
typedef IssueAsk = ({
  String memberId,
  String period,
  InvoiceKind kind,
  String? replacesId,
  String correctionReason,
});

/// The dry run of [ask] in [workspace], judged.
Future<IssueJudgement> judgeIssue(
  WidgetRef ref,
  Workspace workspace,
  IssueAsk ask,
) async {
  final draft = await ref
      .read(invoiceIssueDraftsProvider)
      .issueDraft(
        workspaceId: workspace.id,
        memberId: ask.memberId,
        period: ask.period,
        kind: ask.kind,
        replacesId: ask.replacesId,
        correctionReason: ask.correctionReason,
      );
  final seller = draft.seller;
  final buyer = draft.buyer;
  if (seller == null || buyer == null) {
    return (missing: draft.missing, gaps: const <ChannelGap>[]);
  }
  final gateway = await _gateway(ref);
  return (
    missing: draft.missing,
    gaps: channelGapsFor(
      gateway,
      seller: seller,
      buyer: buyer,
      iban: workspaceIban(workspace),
    ),
  );
}

/// A failed probe reads as "not configured": nothing is warned about.
Future<EInvoiceGatewayConfig> _gateway(WidgetRef ref) async {
  try {
    return await ref.read(eInvoiceGatewayProvider.future);
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'e-invoice gateway probe failed',
      error: e,
      stackTrace: st,
    );
    return EInvoiceGatewayConfig.notConfigured;
  }
}
