// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3843 — the prices of a period's bookings, read once per period: the read
// costs the server a pass over each member's months (#3967), so a refused or
// failed read is shown as no price, never asked again by itself.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_booking_price_reads.dart';
import '../domain/booking_price.dart';

/// The price read; the Demo and the tests replace it.
final bookingPriceReadsProvider = Provider<BookingPriceReads>(
  (ref) =>
      SupabaseBookingPriceReads(ref.watch(selectedWorkspaceClientProvider)),
);

/// The period a price read covers.
typedef BookingPricePeriod = ({String workspaceId, DateTime from, DateTime to});

/// The prices of the period's bookings, by booking.
final bookingPricesProvider = FutureProvider.autoDispose
    .family<Map<String, BookingPrice>, BookingPricePeriod>((ref, period) async {
      final prices = await ref
          .watch(bookingPriceReadsProvider)
          .prices(period.workspaceId, from: period.from, to: period.to);
      return {for (final p in prices) p.reservationId: p};
    }, retry: (_, _) => null);
