// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C1 -- the strict adapter of `my_reservations_page_v1`. It takes the
// workspace context once, at the start of the call, asks THAT context's
// verified host through the host's own client (never the process-wide
// one), and types what comes back: the page decoded strictly with the host
// attached as its source, or a refusal the page can name. The window
// limits come from the same context's captured settings: what the host
// enforces is what the person is shown.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/operation_context.dart';
import '../../../core/data/json_reader.dart';
import '../../../core/settings/settings.dart';
import '../domain/my_reservations.dart';

/// How a personal read retries. A typed refusal or any answer of the host
/// itself is final: asking again returns the same, and the default (ten
/// tries, minutes in all, in every provider that watches this one) would
/// hammer a host that said no. Only a transport failure is tried again,
/// twice and quickly.
Duration? myReservationsRetry(int retryCount, Object error) {
  if (retryCount >= 2) return null;
  return switch (error) {
    MyReservationsRefused() || PostgrestException() => null,
    _ => Duration(milliseconds: 200 << retryCount),
  };
}

class ContextMyReservationsRepository implements MyReservationsRepository {
  const ContextMyReservationsRepository({
    required this.context,
    required this.clientFor,
  });

  /// The operation context at the moment of the call.
  final Future<WorkspaceContext?> Function() context;

  /// The client of a verified installation.
  final SupabaseClient Function(String installationId) clientFor;

  Future<WorkspaceContext> _captured() async {
    final captured = await context();
    if (captured == null) {
      throw const MyReservationsRefused(MyReservationsFailure.noContext);
    }
    return captured;
  }

  @override
  Future<MyReservationsLimits> limits() async {
    final settings = (await _captured()).settings.settings;
    try {
      return MyReservationsLimits(
        windowDays: settings.read<int>('personal.reservation_window_days'),
        maxDays: settings.read<int>('personal.reservation_max_window_days'),
      );
    } on UnknownSetting catch (e, st) {
      // trace-exempt: rethrown typed; the page says the registry lacks the rows.
      Error.throwWithStackTrace(
        MyReservationsRefused(MyReservationsFailure.misconfigured, detail: '$e'),
        st,
      );
    } on SettingTypeMismatch catch (e, st) {
      // trace-exempt: rethrown typed; a row of another type is no window.
      Error.throwWithStackTrace(
        MyReservationsRefused(MyReservationsFailure.misconfigured, detail: '$e'),
        st,
      );
    }
  }

  @override
  Future<MyReservationsPage> page(MyReservationsQuery query) async {
    final installation = (await _captured()).target.installationId;
    final Object? raw;
    try {
      raw = await clientFor(installation).rpc<Object?>(
        'my_reservations_page_v1',
        params: query.toRpcParams(),
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the page says which refusal.
      final failure = _refusalOf(e);
      if (failure == null) rethrow;
      Error.throwWithStackTrace(
        MyReservationsRefused(failure, detail: e.message),
        st,
      );
    }
    try {
      return MyReservationsPage.decode(raw, source: installation);
    } on JsonShapeException catch (e, st) {
      // trace-exempt: rethrown typed; a malformed answer is never shown as empty.
      Error.throwWithStackTrace(
        MyReservationsRefused(MyReservationsFailure.malformed, detail: '$e'),
        st,
      );
    }
  }

  /// The SQLSTATEs the read raises on purpose, and the one the registry
  /// raises for a missing personal row. Anything else is not a refusal.
  static MyReservationsFailure? _refusalOf(PostgrestException e) =>
      switch (e.code) {
        'PGRST202' => MyReservationsFailure.unsupported,
        '42501' => MyReservationsFailure.forbidden,
        '22023' => MyReservationsFailure.invalid,
        'P0001' when e.message.contains('unknown setting') =>
          MyReservationsFailure.misconfigured,
        _ => null,
      };
}
