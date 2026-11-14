// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3614 — the guest passes sold, as records: the guest, the pass, the
// window from and to, how much of it is used, and the price; sorted and
// filtered like every records table, one total per currency of what is
// shown. #3829 — whoever sells (issueInvoices) revokes a selection here,
// one pass after another; a revoked pass says so. #3837 — a pass opens the
// invoice its sale made, and a revoked one says whether that invoice is
// corrected yet; a chip finds those still to correct. The table is shown
// only to who may read the invoices (guest_passes_screen.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../domain/guest_pass.dart';
import '../../domain/guest_pass_invoice.dart';
import '../../providers/guest_pass_providers.dart';
import '../../providers/money_providers.dart';
import 'guest_pass_invoice_line.dart';
import 'guest_pass_revoke.dart';

/// The passes sold in [workspaceId]; [offers] name them.
class GuestPassRecords extends ConsumerWidget {
  const GuestPassRecords({
    super.key,
    required this.workspaceId,
    required this.offers,
    required this.currency,
    this.canRevoke = false,
  });

  final String workspaceId;
  final List<GuestPassOffer> offers;

  /// The space's currency: every pass is sold in it.
  final MoneyFormat currency;

  /// #3829 — whether the reader may revoke (issueInvoices, as to sell).
  final bool canRevoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final read = ref.watch(guestPassesSoldProvider(workspaceId));
    final dates = appFormatOf(context).dates(DateShape.numeric);
    final names = ref.watch(memberLabelsProvider);
    final now = ref.watch(clockProvider).now();
    // The business's calendar day of an instant: the window's days.
    final dayOf = ref.watch(invoicingBusinessProvider).dayOf;
    int used(GuestPassRecord p) => p.usedAt(now, dayOf);
    String day(DateTime instant) => dates.format(dayOf(instant));
    String lastDay(GuestPassRecord p) => dates.format(p.lastDay(dayOf));
    final offerNames = {for (final o in offers) o.id: o.name};
    final rows = read.value ?? const <GuestPassRecord>[]; // empty-ok: the table shows loading or failed while it is not read
    String holder(GuestPassRecord p) => names[p.memberId] ?? '';
    // #3837 — the business's invoices, read beside the passes: a pass not
    // found among them says nothing of its money.
    final invoices = ref.watch(invoicesProvider).value ?? const []; // empty-ok: an invoice not read leaves the pass's money unsaid
    PassInvoice invoiceOf(GuestPassRecord p) => passInvoiceOf(p, invoices);
    void openInvoice(String id) => context.push('/invoices/$id');
    bool uncorrected(GuestPassRecord p) =>
        p.revoked && invoiceOf(p).state == PassInvoiceState.notCorrected;
    return RecordsTable<GuestPassRecord>(
      tableId: 'guest-passes-sold',
      state: switch (read) {
        AsyncData() => RecordsState.ready,
        AsyncError() => RecordsState.failed,
        _ => RecordsState.loading,
      },
      onRetry: () => ref.invalidate(guestPassesSoldProvider(workspaceId)),
      rows: rows,
      keyOf: (p) => p.id,
      searchText: (p) => '${holder(p)} ${offerNames[p.offerId] ?? ''}',
      // The guest's invoice is where the pass is read in full.
      onOpen: (p) {
        if (invoiceOf(p).invoice case final invoice?) openInvoice(invoice.id);
      },
      rowActions: (p) => [
        if (invoiceOf(p).invoice case final invoice?)
          RecordAction(
            id: 'invoice',
            label: l10n.guestPassOpenInvoice,
            icon: Icons.receipt_long_outlined,
            onRun: (_) => openInvoice(invoice.id),
          ),
      ],
      chips: [
        RecordChip(
          id: 'uncorrected',
          label: l10n.guestPassFilterUncorrected,
          keeps: uncorrected,
        ),
      ],
      empty: EmptyState(
        icon: Icons.confirmation_number_outlined,
        title: l10n.guestPassesSoldEmpty,
      ),
      initialQuery: const RecordsQuery(sortColumn: 'from', ascending: false),
      amountOf: (p) => (currency: currency.code, minor: p.amountCents),
      bulkActions: [
        if (canRevoke)
          RecordBulkAction(
            id: 'revoke',
            label: l10n.guestPassRevokeSelected,
            icon: Icons.block_outlined,
            onRun: (keys) => revokeGuestPasses(
              context,
              commands: ref.read(guestPassCommandsProvider),
              onRevoked: () => ref.invalidate(guestPassesSoldProvider(workspaceId)),
              workspaceId: workspaceId,
              passes: [
                for (final p in rows)
                  if (keys.contains(p.id) && !p.revoked) p,
              ],
              holder: holder,
              invoiceOf: invoiceOf,
              onOpenInvoice: openInvoice,
            ),
          ),
      ],
      formatAmount: (_, minor) => currency.formatMinor(minor),
      columns: [
        RecordColumn(
          id: 'holder',
          label: l10n.guestPassHolder,
          flex: 3,
          hideable: false,
          sortKey: (p) => holder(p).toLowerCase(),
          cell: (_, p) => Text(holder(p), overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'pass',
          label: l10n.guestPassChoose,
          flex: 2,
          cell: (_, p) => Text(
            offerNames[p.offerId] ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        RecordColumn(
          id: 'from',
          label: l10n.guestPassFrom,
          flex: 2,
          sortKey: (p) => p.startsAt,
          cell: (_, p) => Text(day(p.startsAt)),
        ),
        RecordColumn(
          id: 'to',
          label: l10n.guestPassTo,
          flex: 2,
          sortKey: (p) => p.endsAt,
          cell: (_, p) => Text(lastDay(p)),
        ),
        RecordColumn(
          id: 'used',
          label: l10n.guestPassUsed,
          flex: 2,
          cell: (_, p) => Text(l10n.noteRefFilterCount(used(p), p.units)),
        ),
        RecordColumn(
          id: 'state',
          label: l10n.guestPassState,
          flex: 2,
          sortKey: (p) => p.revoked ? (uncorrected(p) ? 2 : 1) : 0,
          cell: (_, p) => p.revoked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(
                      key: ValueKey('guest-pass-revoked-${p.id}'),
                      label: l10n.guestPassRevoked,
                      tone: StatusTone.neutral,
                    ),
                    if (passInvoiceWords(l10n, invoiceOf(p)) case final line?)
                      Text(
                        line,
                        key: ValueKey('guest-pass-invoice-${p.id}'),
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        RecordColumn(
          id: 'price',
          label: l10n.servicesPrice,
          numeric: true,
          flex: 2,
          sortKey: (p) => p.amountCents,
          cell: (_, p) => Text(currency.formatMinor(p.amountCents)),
        ),
      ],
      cardBuilder: (context, p) => ListTile(
        title: Text(holder(p), overflow: TextOverflow.ellipsis),
        // Each fact its own words: the pass, its days, how much is used.
        subtitle: Wrap(
          spacing: AppSpacing.sm,
          children: [
            Text(offerNames[p.offerId] ?? ''),
            Text(day(p.startsAt)),
            Text(lastDay(p)),
            Text(l10n.guestPassUsed),
            Text(l10n.noteRefFilterCount(used(p), p.units)),
            if (p.revoked) Text(l10n.guestPassRevoked),
            if (p.revoked)
              if (passInvoiceWords(l10n, invoiceOf(p)) case final line?)
                Text(line),
          ],
        ),
        trailing: Text(currency.formatMinor(p.amountCents)),
      ),
    );
  }
}
