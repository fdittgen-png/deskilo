// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3614 — the guest passes sold, as records: the guest, the pass, the
// window from and to, how much of it is used, and the price; sorted and
// filtered like every records table, one total per currency of what is
// shown. A pass is revoked through its own issue (#3829): this table only
// lists.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../domain/guest_pass.dart';
import '../../providers/guest_pass_providers.dart';
import '../../providers/money_providers.dart';

/// The passes sold in [workspaceId]; [offers] name them.
class GuestPassRecords extends ConsumerWidget {
  const GuestPassRecords({
    super.key,
    required this.workspaceId,
    required this.offers,
    required this.currency,
  });

  final String workspaceId;
  final List<GuestPassOffer> offers;

  /// The space's currency: every pass is sold in it.
  final MoneyFormat currency;

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
    final offerNames = {for (final o in offers) o.id: o.name};
    final rows = read.value ?? const <GuestPassRecord>[]; // empty-ok: the table shows loading or failed while it is not read
    String holder(GuestPassRecord p) => names[p.memberId] ?? '';
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
      onOpen: (_) {},
      empty: EmptyState(
        icon: Icons.confirmation_number_outlined,
        title: l10n.guestPassesSoldEmpty,
      ),
      initialQuery: const RecordsQuery(sortColumn: 'from', ascending: false),
      amountOf: (p) => (currency: currency.code, minor: p.amountCents),
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
          cell: (_, p) => Text(day(p.endsAt)),
        ),
        RecordColumn(
          id: 'used',
          label: l10n.guestPassUsed,
          flex: 2,
          cell: (_, p) => Text(l10n.noteRefFilterCount(used(p), p.units)),
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
            Text(day(p.endsAt)),
            Text(l10n.guestPassUsed),
            Text(l10n.noteRefFilterCount(used(p), p.units)),
          ],
        ),
        trailing: Text(currency.formatMinor(p.amountCents)),
      ),
    );
  }
}
