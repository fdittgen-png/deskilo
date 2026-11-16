// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- what an issue would store, read before the number is taken: the
// essentials still missing and, when none is, the parties the invoice would
// freeze. The app judges what the configured channel will need on exactly
// those parties, with the function the send sheet uses on the stored ones.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:meta/meta.dart';

import 'einvoice_channel_check.dart';
import 'invoice_queries.dart';

/// What stops the issue, and what the e-invoice will still need (#4105).
typedef IssueJudgement = ({List<String> missing, List<ChannelGap> gaps});

/// Nothing known yet.
const IssueJudgement noJudgement = (missing: <String>[], gaps: <ChannelGap>[]);

/// The dry run of one issue.
class IssueDraft {
  const IssueDraft({this.missing = const [], this.seller, this.buyer});

  /// Reads the server's answer (`invoice_issue_draft`, 0792).
  factory IssueDraft.fromAnswer(Object? answer) {
    final map = answer is Map ? answer : const <String, Object?>{};
    final parties = map['parties'];
    return IssueDraft(
      missing: [
        for (final k in map['missing'] as List? ?? const []) k as String,
      ],
      seller: parties is Map && parties['seller'] is Map
          ? InvoiceParty.fromSnapshot(parties['seller'] as Map)
          : null,
      buyer: parties is Map && parties['buyer'] is Map
          ? InvoiceParty.fromSnapshot(parties['buyer'] as Map)
          : null,
    );
  }

  /// The essentials still missing, as the server's stable keys.
  final List<String> missing;

  /// The parties the invoice would store; null while something is missing.
  final InvoiceParty? seller;
  final InvoiceParty? buyer;
}

/// The dry run of an issue, with the parties it would store.
abstract interface class InvoiceIssueDrafts {
  Future<IssueDraft> issueDraft({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  });
}

/// The essentials alone, from [queries]: for the test doubles, which cannot
/// tell the parties an issue would store. Nothing about a channel is said.
@visibleForTesting
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
