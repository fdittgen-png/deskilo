// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C3 -- View, Cancel and Check in from a row of My reservations, each
// through the host the row was read from: that source's own verified
// client (the same resolver the read uses), never the selected workspace's.
// View reads the booking again with the strict page adapter, narrowed to
// its workspace and its start; Cancel and Check in call the host's own
// commands with the booking's id. A host without the command is the typed
// refusal; any other answer of the host comes through unchanged, so the
// row says the host's own reason. Nothing is retried with a fresh id.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/context_clients.dart';
import '../domain/my_reservations.dart';
import 'host_my_reservations_repository.dart';

class HostMyReservationActions implements MyReservationActions {
  const HostMyReservationActions({required this.pages, required this.hostOf});

  /// The strict read, the one My reservations pages through.
  final MyReservationsRepository pages;

  /// The verified host of a source, with its own client.
  final Future<ResolvedWorkspaceHost> Function(MyReservationsSource source) hostOf;

  @override
  Future<MyReservationItem> view(
    MyReservationsSource source,
    MyReservationItem item,
  ) async {
    final page = await pages.page(source, myReservationLookup(item));
    for (final found in page.items) {
      if (found.id == item.id) return found;
    }
    throw MyReservationsRefused(MyReservationsFailure.gone, detail: item.id);
  }

  @override
  Future<void> cancel(MyReservationsSource source, MyReservationItem item) =>
      _command(source, 'cancel_reservation', item.id);

  @override
  Future<void> checkIn(MyReservationsSource source, MyReservationItem item) =>
      _command(source, 'check_in_reservation', item.id);

  Future<void> _command(
    MyReservationsSource source,
    String command,
    String reservationId,
  ) async {
    final host = await verifiedMyReservationsHost(hostOf, source);
    try {
      await host.client.rpc<Object?>(
        command,
        params: {'p_reservation_id': reservationId},
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: an older host without the command is typed; every
      // other answer is the host's own reason, rethrown for the row.
      if (e.code != 'PGRST202') rethrow;
      Error.throwWithStackTrace(
        MyReservationsRefused(MyReservationsFailure.unsupported, detail: e.message),
        st,
      );
    } finally {
      host.lease?.release();
    }
  }
}
