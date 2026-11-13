// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 (desk M8) — the Usage face at the desk: the month's bookings as a
// records table — the day, the hours, the place, whose (when not mine) and
// what of it bills. A row opens the booking's own card, with what can be
// asked or done about it there.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/usage_record.dart';
import '../../providers/usage_providers.dart';
import 'usage_face.dart';

class UsageTable extends ConsumerWidget {
  const UsageTable({super.key, required this.period});

  final String period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final read = ref.watch(usageReadProvider(period));
    final names = ref.watch(memberNamesProvider).value ?? const {}; // empty-ok: names are labels; an unread one is left blank, never a figure
    final me = ref.watch(myMemberProvider).value;
    final format = appFormatOf(context);
    final day = format.dates(DateShape.weekdayMonthDay);
    String whose(UsageRecord r) =>
        me?.id == r.memberId ? '' : (names[r.memberId] ?? '');
    final unprepared = read.value?.unpreparedReservations ?? 0;
    final table = RecordsTable<UsageRecord>(
      tableId: 'usage',
      rows: read.value?.records ?? const [],
      state: switch (read) {
        AsyncError() => RecordsState.failed,
        AsyncData() => RecordsState.ready,
        _ => RecordsState.loading,
      },
      onRetry: () => ref.invalidate(usageReadProvider(period)),
      keyOf: (r) => r.id,
      searchText: (r) => '${r.spaceLabel} ${whose(r)}',
      onOpen: (r) => showAppSheet<void>(
        context: context,
        builder: (_) => Padding(
          padding: AppSpacing.mdAll,
          child: UsageRecordCard(
            record: r,
            memberName: names[r.memberId] ?? '',
            mine: me?.id == r.memberId,
            mayRemove: (me?.isAdmin ?? false) || (me?.isOwner ?? false),
          ),
        ),
      ),
      cardBuilder: (context, r) => UsageRecordCard(
        record: r,
        memberName: names[r.memberId] ?? '',
        mine: me?.id == r.memberId,
        mayRemove: (me?.isAdmin ?? false) || (me?.isOwner ?? false),
      ),
      empty: Center(child: Text(l.usageEmpty)),
      initialQuery: const RecordsQuery(sortColumn: 'day', ascending: false),
      columns: [
        RecordColumn(
          id: 'day',
          label: l.calendarDay,
          flex: 3,
          hideable: false,
          sortKey: (r) => r.reservedFrom,
          cell: (_, r) => Text(day.format(r.reservedFrom)),
        ),
        RecordColumn(
          id: 'hours',
          label: l.dataReportColumnHours,
          flex: 2,
          cell: (_, r) => Text(
            '${format.time(r.reservedFrom)}–${format.time(r.reservedTo)}',
          ),
        ),
        RecordColumn(
          id: 'place',
          label: l.calendarDeskColumnPlace,
          flex: 3,
          sortKey: (r) => r.spaceLabel.toLowerCase(),
          cell: (_, r) => Text(r.spaceLabel, overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'member',
          label: l.calendarDeskColumnMember,
          flex: 3,
          sortKey: (r) => whose(r).toLowerCase(),
          cell: (_, r) => Text(whose(r), overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'billed',
          label: l.usageColBilled,
          flex: 2,
          numeric: true,
          sortKey: (r) => r.countedMinutes,
          cell: (_, r) => Text(usageDuration(r.countedMinutes)),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unprepared > 0)
          UsagePrepareBanner(period: period, count: unprepared),
        Expanded(child: table),
      ],
    );
  }
}
