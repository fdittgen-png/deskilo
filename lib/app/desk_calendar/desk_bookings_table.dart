// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — all bookings of the period as a records table (K1): member,
// place, from, to, state. It reads the very list the grid draws, so the two
// show the same bookings. A row opens the booking beside the table.
//
// #3843 — and what each was or will be charged: a room's charge with its
// amount, a pass, a carnet, free, the subscription, or the month's extra
// half-days. The period's prices are asked for once, after the table has
// drawn (the read costs the server a pass per member and month, #3967); the
// charges are added up under the table, per currency.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/ui/empty_state.dart';
import '../../core/ui/kit/records_table.dart';
import '../../features/reservations/domain/booking_price.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/reservations/presentation/widgets/my_reservations_layout.dart' show myReservationStatusWords;
import '../../features/reservations/providers/reservation_providers.dart';
import '../../l10n/app_localizations.dart';
import 'desk_booking_chip.dart';
import 'desk_calendar.dart';

/// The key of the records table of the desk calendar.
const Key _deskBookingsTableKey = ValueKey('desk-bookings-table');

/// The word for a booking's [kind] of price (a charge says its amount).
String _priceWord(AppLocalizations l10n, BookingPriceKind kind) =>
    switch (kind) {
      BookingPriceKind.charge => l10n.bookingPriceCharge('').trim(),
      BookingPriceKind.pass => l10n.bookingPricePass,
      BookingPriceKind.carnet => l10n.bookingPriceCarnet,
      BookingPriceKind.free => l10n.bookingPriceFree,
      BookingPriceKind.subscription => l10n.bookingPriceSubscription,
      BookingPriceKind.overage => l10n.bookingPriceOverage,
    };

/// A booking's price as the table and its export say it: the charge with its
/// amount, else the kind's word.
String bookingPriceText(
  AppLocalizations l10n,
  String Function(String currency, int minor) amountText,
  BookingPrice price,
) => price.isCharge
    ? l10n.bookingPriceCharge(amountText(price.currency!, price.amountCents!))
    : _priceWord(l10n, price.kind);

class DeskBookingsTable extends ConsumerStatefulWidget {
  const DeskBookingsTable({
    required this.bookings,
    required this.names,
    required this.placeNames,
    required this.onOpen,
    this.period,
    super.key,
  });

  final List<Reservation> bookings;
  final Map<String, String> names;
  final Map<String, String> placeNames;
  final ValueChanged<Reservation> onOpen;

  /// The period whose prices the table asks for; null: no price column.
  final BookingPricePeriod? period;

  @override
  ConsumerState<DeskBookingsTable> createState() => _DeskBookingsTableState();
}

class _DeskBookingsTableState extends ConsumerState<DeskBookingsTable> {
  /// Whether the table has drawn: the prices are asked for only then.
  bool _drawn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _drawn = true);
    });
  }

  String _place(Reservation r) =>
      widget.placeNames[bookingTargetId(r)] ?? r.spaceLabel ?? '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final names = widget.names;
    final period = widget.period;
    final prices = period == null || !_drawn
        ? const <String, BookingPrice>{}
        : ref.watch(bookingPricesProvider(period)).value ??
              const <String, BookingPrice>{}; // empty-ok: no price is shown until the read answers, and none when it is refused
    String amount(String code, int minor) =>
        format.moneyIn(code).formatMinor(minor);
    return RecordsTable<Reservation>(
      key: _deskBookingsTableKey,
      tableId: 'desk-bookings',
      rows: widget.bookings,
      keyOf: (r) => r.id,
      initialQuery: const RecordsQuery(sortColumn: 'from'),
      searchText: (r) => '${deskBookingWho(names, r)} ${_place(r)}',
      onOpen: widget.onOpen,
      amountOf: (r) => switch (prices[r.id]) {
        final p? when p.isCharge => (currency: p.currency!, minor: p.amountCents!),
        _ => null,
      },
      amountColumn: 'price',
      formatAmount: amount,
      empty: EmptyState(
        icon: Icons.event_busy_outlined,
        title: l10n.calendarNothingHere,
      ),
      columns: [
        RecordColumn(
          id: 'member',
          label: l10n.calendarDeskColumnMember,
          flex: 3,
          hideable: false,
          sortKey: (r) => deskBookingWho(names, r).toLowerCase(),
          cell: (_, r) => Text(
            deskBookingWho(names, r),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        RecordColumn(
          id: 'place',
          label: l10n.calendarDeskColumnPlace,
          flex: 3,
          sortKey: (r) => _place(r).toLowerCase(),
          cell: (_, r) => Text(_place(r), overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'from',
          label: l10n.calendarDeskColumnFrom,
          flex: 3,
          sortKey: (r) => r.startsAt,
          cell: (_, r) => Text(format.dateTime(r.startsAt)),
        ),
        RecordColumn(
          id: 'to',
          label: l10n.calendarDeskColumnTo,
          flex: 3,
          sortKey: (r) => r.endsAt,
          cell: (_, r) => Text(format.dateTime(r.endsAt)),
        ),
        RecordColumn(
          id: 'state',
          label: l10n.calendarDeskColumnState,
          flex: 2,
          sortKey: (r) => r.status.index,
          cell: (_, r) => Text(myReservationStatusWords(l10n, r.status)),
        ),
        if (period != null)
          RecordColumn(
            id: 'price',
            label: l10n.calendarDeskColumnPrice,
            flex: 3,
            sortKey: (r) => switch (prices[r.id]) {
              final p? => p.kind.index * 100000000 + (p.amountCents ?? 0),
              null => -1,
            },
            cell: (_, r) => switch (prices[r.id]) {
              final p? => Text(
                bookingPriceText(l10n, amount, p),
                overflow: TextOverflow.ellipsis,
              ),
              null => const SizedBox.shrink(),
            },
          ),
      ],
      cardBuilder: (context, r) => Card(
        child: ListTile(
          title: Text(deskBookingWho(names, r)),
          subtitle: Text('${_place(r)} · ${deskBookingRange(context, r)}'),
          onTap: () => widget.onOpen(r),
        ),
      ),
    );
  }
}
