// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 -- the strict adapter of `my_reservations_page_v1`. C1 asked the
// selected workspace's host; C2 asks the host a source names, through
// THAT host's own verified client (the workspace-host resolver: the
// installation the app is signed in to, or the connected pool's pinned
// client), and refuses a host that identifies itself as another
// installation. What comes back is typed: the page decoded strictly with
// the asked installation attached as its source, the zone of each of its
// workspaces read from the same host, or a refusal the page can name.
// The limits are the personal home's own platform settings: no selected
// workspace decides how many hosts are read, how long, or how far.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_target.dart';
import '../../../core/backend/connection_outcome.dart';
import '../../../core/backend/context_clients.dart';
import '../../../core/data/json_reader.dart';
import '../../../core/settings/settings.dart';
import '../../../core/trace/trace_logger.dart';
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

/// The verified host of [source]: the installation the app is signed in to
/// for a workspace of my personal home, else the [connected] installation
/// whose verified identity is the source's, through the existing resolver
/// ([resolverFor] the connected origin, null for the signed-in one). Not
/// connected here is the typed refusal, never another host's answer.
Future<ResolvedWorkspaceHost> resolveMyReservationsHost(
  MyReservationsSource source, {
  required Future<List<ConnectedInstallation>> Function() connected,
  required WorkspaceHostResolver Function(String? origin) resolverFor,
}) async {
  String? origin;
  if (!source.hostedHere) {
    for (final c in await connected()) {
      if (c.installationId == source.installationId) origin = c.endpoint.url;
    }
    if (origin == null) {
      throw MyReservationsRefused(
        MyReservationsFailure.hostUnavailable,
        detail: '${source.installationId} is not connected here',
      );
    }
  }
  return resolverFor(origin).resolve(source.workspaceIds.first);
}

class HostMyReservationsRepository implements MyReservationsRepository {
  const HostMyReservationsRepository({
    required this.platformSettings,
    required this.hostOf,
  });

  /// The personal home's platform settings for the signed-in person; null
  /// signed out.
  final Future<SettingsSet?> Function() platformSettings;

  /// The verified host of a source, with its own client.
  final Future<ResolvedWorkspaceHost> Function(MyReservationsSource source) hostOf;

  @override
  Future<MyReservationsLimits> limits() async {
    final settings = await platformSettings();
    if (settings == null) {
      throw const MyReservationsRefused(MyReservationsFailure.noContext);
    }
    try {
      return MyReservationsLimits(
        windowDays: settings.read<int>('personal.reservation_window_days'),
        maxDays: settings.read<int>('personal.reservation_max_window_days'),
        concurrency: settings.read<int>('personal.read_concurrency'),
        timeout: Duration(
          seconds: settings.read<int>('personal.read_timeout_seconds'),
        ),
      );
    } on UnknownSetting catch (e, st) {
      // trace-exempt: rethrown typed; the page says the registry lacks the rows.
      Error.throwWithStackTrace(
        MyReservationsRefused(MyReservationsFailure.misconfigured, detail: '$e'),
        st,
      );
    } on SettingTypeMismatch catch (e, st) {
      // trace-exempt: rethrown typed; a row of another type is no limit.
      Error.throwWithStackTrace(
        MyReservationsRefused(MyReservationsFailure.misconfigured, detail: '$e'),
        st,
      );
    }
  }

  Future<ResolvedWorkspaceHost> _host(MyReservationsSource source) async {
    final ResolvedWorkspaceHost host;
    try {
      host = await hostOf(source);
    } on UnverifiedInstallation catch (e, st) {
      // trace-exempt: rethrown typed; the slot says its host is unavailable.
      Error.throwWithStackTrace(
        MyReservationsRefused(MyReservationsFailure.hostUnavailable, detail: '$e'),
        st,
      );
    } on ConnectionFailure catch (e, st) {
      // trace-exempt: rethrown typed; the slot says its host is unavailable.
      Error.throwWithStackTrace(
        MyReservationsRefused(MyReservationsFailure.hostUnavailable, detail: '$e'),
        st,
      );
    }
    if (host.installationId != source.installationId) {
      host.lease?.release();
      throw MyReservationsRefused(
        MyReservationsFailure.hostUnavailable,
        detail: 'asked ${source.installationId}, answered ${host.installationId}',
      );
    }
    return host;
  }

  @override
  Future<MyReservationsPage> page(
    MyReservationsSource source,
    MyReservationsQuery query,
  ) async {
    final host = await _host(source);
    try {
      final page = await _page(host.client, source.installationId, query);
      return page.withZones(await _zones(host.client, page));
    } finally {
      host.lease?.release();
    }
  }

  Future<MyReservationsPage> _page(
    SupabaseClient client,
    String installation,
    MyReservationsQuery query,
  ) async {
    final Object? raw;
    try {
      raw = await client.rpc<Object?>(
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

  /// The zone of each workspace [page] names, from the same host's own
  /// workspace rows. A failed read leaves the page without zones: its days
  /// are then the device's, and the bookings are still shown.
  Future<Map<String, String>> _zones(
    SupabaseClient client,
    MyReservationsPage page,
  ) async {
    final ids = {for (final i in page.items) i.workspaceId}.toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await client
          .from('workspaces')
          .select('id, timezone')
          .inFilter('id', ids);
      return {
        for (final row in rows)
          if (row['id'] is String && row['timezone'] is String)
            row['id'] as String: row['timezone'] as String,
      };
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'reservations',
        'the zones of my reservations\' workspaces were not read',
        error: e,
        stackTrace: st,
      );
      return const {};
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
