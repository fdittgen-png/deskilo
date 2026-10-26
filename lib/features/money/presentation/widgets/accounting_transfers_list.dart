// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The transfers of a year: every file handed out whose period overlaps it,
// with who made it, when, its SHA-256 and the documents it carried; and
// every document delivered to a connection, with what the target answered.
// The digital link from these books to the accounting system, as a VAT
// inspection asks to see it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/accounting_connection.dart';
import '../../domain/posting.dart';
import '../../providers/accounting_connection_providers.dart';
import 'accounting_targets_sheet.dart';

/// How many hex digits of a digest a line shows; the whole digest is one
/// tap away.
const int _shortDigest = 12;

String _short(String sha) =>
    sha.length > _shortDigest ? '${sha.substring(0, _shortDigest)}…' : sha;

/// The words of a document event.
String _documentKindLabel(AppLocalizations l10n, String wire) =>
    switch (PostingKind.values.where((k) => k.wire == wire).firstOrNull) {
      PostingKind.invoice => l10n.acctKindInvoice,
      PostingKind.creditNote => l10n.acctKindCreditNote,
      PostingKind.receipt => l10n.acctKindReceipt,
      PostingKind.refund => l10n.acctKindRefund,
      PostingKind.writeOff => l10n.acctKindWriteOff,
      PostingKind.expense => l10n.acctKindExpense,
      PostingKind.supplierBill => l10n.acctKindSupplierBill,
      PostingKind.supplierCreditNote => l10n.acctKindSupplierCreditNote,
      PostingKind.supplierPayment => l10n.acctKindSupplierPayment,
      PostingKind.vatRelease => l10n.acctKindVatRelease,
      PostingKind.memberReceipt => l10n.acctKindMemberReceipt,
      PostingKind.reimbursement => l10n.acctKindReimbursement,
      null => l10n.acctKindOther,
    };

String _deliveryStatusLabel(AppLocalizations l10n, DeliveryStatus s) =>
    switch (s) {
      DeliveryStatus.generated => l10n.acctDeliveryGenerated,
      DeliveryStatus.sent => l10n.acctDeliverySent,
      DeliveryStatus.acknowledged => l10n.acctDeliveryAcknowledged,
      DeliveryStatus.conflict => l10n.acctDeliveryConflict,
      DeliveryStatus.failed => l10n.acctDeliveryFailed,
    };

class AccountingTransfersList extends ConsumerStatefulWidget {
  const AccountingTransfersList({
    required this.workspaceId,
    required this.memberNames,
    super.key,
  });

  final String workspaceId;

  /// Member id → name, for who made each file.
  final Map<String, String> memberNames;

  @override
  ConsumerState<AccountingTransfersList> createState() =>
      _AccountingTransfersListState();
}

class _AccountingTransfersListState
    extends ConsumerState<AccountingTransfersList> {
  late int _year = ref.read(clockProvider).now().year;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    final transfers = ref.watch(
      accountingTransfersProvider((
        workspaceId: widget.workspaceId,
        from: DateTime(_year),
        to: DateTime(_year, 12, 31),
      )),
    );
    final names = widget.memberNames;
    String day(DateTime d) => material.formatMediumDate(d);
    return Column(
      key: const ValueKey('acct-transfers'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.acctTransfersTitle, style: theme.titleMedium),
        Text(l10n.acctTransfersIntro, style: theme.bodySmall),
        Row(
          children: [
            IconButton(
              key: const ValueKey('acct-transfers-previous'),
              tooltip: material.previousPageTooltip,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _year--),
            ),
            Text(
              l10n.acctTransfersPeriod('$_year'),
              key: const ValueKey('acct-transfers-year'),
            ),
            IconButton(
              key: const ValueKey('acct-transfers-next'),
              tooltip: material.nextPageTooltip,
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _year++),
            ),
          ],
        ),
        transfers.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(
            l10n.acctTargetsLoadFailed,
            key: const ValueKey('acct-transfers-failed'),
          ),
          data: (t) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (t.files.isEmpty && t.deliveries.isEmpty)
                Text(l10n.acctTransfersEmpty, key: const ValueKey('acct-transfers-empty')),
              for (final f in t.files)
                ExpansionTile(
                  key: ValueKey('acct-transfer-file-${f.id}'),
                  tilePadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    l10n.acctTransferFile(targetLabel(f.formatId), day(f.from), day(f.to)),
                  ),
                  subtitle: Text(
                    [
                      l10n.acctTransferFileMeta(
                        day(f.exportedAt),
                        names[f.exportedByMemberId] ?? l10n.acctWhoUnknown,
                        f.documentCount,
                      ),
                      l10n.acctTransferSha(_short(f.sha256)),
                      if (f.closedPeriod) l10n.acctTransferClosed,
                    ].join(' · '),
                  ),
                  children: [
                    SelectableText(
                      l10n.acctTransferSha(f.sha256),
                      key: ValueKey('acct-transfer-sha-${f.id}'),
                      style: theme.bodySmall,
                    ),
                    if (f.deliveries.isNotEmpty)
                      Text(l10n.acctTransferDocuments(f.deliveries.length), style: theme.labelMedium),
                    for (final d in f.deliveries)
                      ListTile(
                        key: ValueKey('acct-transfer-doc-${d.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.acctTransferDocLine(
                            d.documentNumber,
                            _documentKindLabel(l10n, d.documentKind),
                            day(d.eventDate),
                          ),
                        ),
                        subtitle: Text(l10n.acctTransferSha(_short(d.payloadSha256))),
                      ),
                  ],
                ),
              for (final d in t.deliveries)
                ListTile(
                  key: ValueKey('acct-delivery-${d.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    d.status == DeliveryStatus.acknowledged
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_sync_outlined,
                  ),
                  title: Text(
                    l10n.acctTransferDocLine(
                      d.documentNumber,
                      _documentKindLabel(l10n, d.documentKind),
                      day(d.eventDate),
                    ),
                  ),
                  subtitle: Text(
                    [
                      targetLabel(d.targetId),
                      _deliveryStatusLabel(l10n, d.status),
                      if (d.remoteNumber.isNotEmpty || d.remoteId.isNotEmpty)
                        l10n.acctDeliveryRemote(
                          d.remoteNumber.isNotEmpty ? d.remoteNumber : d.remoteId,
                        ),
                      if (d.remoteState == 'draft') l10n.acctDeliveryRemoteDraft,
                      if (d.attempts > 1) l10n.acctDeliveryAttempts(d.attempts),
                      if (d.error.isNotEmpty) d.error,
                      l10n.acctTransferSha(_short(d.payloadSha256)),
                    ].join(' · '),
                    key: ValueKey('acct-delivery-state-${d.id}'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
