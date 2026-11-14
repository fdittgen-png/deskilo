// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/booking_price.dart';

/// `booking_prices` (0767): what each booking of a period is charged, as the
/// server decides who may read it.
class SupabaseBookingPriceReads implements BookingPriceReads {
  const SupabaseBookingPriceReads(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BookingPrice>> prices(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'booking_prices',
      params: {
        'p_workspace_id': workspaceId,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      },
    );
    return [
      for (final row in rows)
        ?BookingPrice.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }
}
