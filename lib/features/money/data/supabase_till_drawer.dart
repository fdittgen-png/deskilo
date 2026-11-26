// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/till_day.dart';
import '../domain/till_drawer.dart';

/// #4367 -- the till sessions' commands and the table reads behind the port. A refusal is thrown as the server sent it
/// (`knownRefusalText` and the drawer's own words read its code and reason); an answer of the wrong shape throws.
/// The table of the till sessions, read by this file and by the counter's book.
const String counterTillSessionsTable = 'counter_till_sessions';

class SupabaseTillDrawer implements TillDrawerPort {
  SupabaseTillDrawer(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(fn, params: params);
    } on PostgrestException catch (e, stack) {
      TraceLogger.instance.warn('money', 'the drawer was refused: ${e.code}', stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<List<DrawerTill>> tills(String workspaceId) async {
    final tills = await _client.from('counter_tills').select('id, name, active, site_id, selling_place_id').eq('workspace_id', workspaceId).order('name', ascending: true);
    final sessions = await fetchAllPages(
      table: counterTillSessionsTable,
      build: () => _client.from(counterTillSessionsTable).select('id, till_id, float_minor, opened_by_member_id').eq('workspace_id', workspaceId).eq('state', 'open').order('id', ascending: true),
    );
    final open = {for (final s in sessions.map(drawerSessionFromRow)) s.tillId: s};
    return [
      for (final t in tills) DrawerTill.fromJson(t, session: open[(t as Map)['id']]),
    ];
  }

  @override
  Future<DrawerTill> saveTill(String workspaceId, {required String requestId, String? tillId, required String name, String? siteId, required bool active, String? sellingPlaceId}) async =>
      DrawerTill.saved(await _call('counter_till_save_v2', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_till_id': tillId,
        'p_name': name,
        'p_site_id': siteId,
        'p_active': active,
        'p_selling_place_id': sellingPlaceId,
      }));

  @override
  Future<TillSellingPlaces> sellingPlaces(String workspaceId) async =>
      TillSellingPlaces.fromJson(await _call('counter_selling_places_v1', {'p_workspace_id': workspaceId}));

  @override
  Future<DrawerOpened> openSession(String workspaceId, {required String requestId, required String tillId, required int floatMinor, Denominations? denominations}) async =>
      DrawerOpened.fromJson(await _call('counter_session_open_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_till_id': tillId,
        'p_float_minor': floatMinor,
        'p_denominations': denominations?.toJson(),
      }));

  @override
  Future<DrawerEntryMade> cashEntry(String workspaceId, {required String requestId, required String sessionId, required DrawerEntry entry}) async =>
      DrawerEntryMade.fromJson(await _call('counter_cash_entry_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_session_id': sessionId,
        'p_kind': entry.kind,
        'p_amount_minor': entry.amountMinor,
        'p_reason': entry.reason,
        'p_purchase_document_id': entry.purchaseDocumentId,
      }));

  @override
  Future<DrawerCash> expected(String workspaceId, {required String sessionId}) async =>
      DrawerCash.fromJson(await _call('counter_session_expected_v1', {'p_workspace_id': workspaceId, 'p_session_id': sessionId}));

  @override
  Future<DrawerClosed> closeSession(String workspaceId, {required String requestId, required String sessionId, required DrawerCount count}) async =>
      DrawerClosed.fromJson(await _call('counter_session_close_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_session_id': sessionId,
        'p_counted_minor': count.countedMinor,
        'p_denominations': count.denominations?.toJson(),
        'p_difference_reason': count.differenceReason,
        'p_banked_minor': count.bankedMinor,
      }));

  @override
  Future<List<DayCloseRow>> dayCloses(String workspaceId) async {
    final rows = await _client.from('counter_day_closes').select('id, number, business_date').eq('workspace_id', workspaceId).order('business_date', ascending: false);
    return [for (final r in rows) DayCloseRow.fromJson(r)];
  }

  @override
  Future<DayReport> closeDay(String workspaceId, {required String requestId, String? siteId, required String businessDate}) async =>
      DayReport.fromJson(await _call('counter_day_close_v1', {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_site_id': siteId,
        'p_business_date': businessDate,
      }));

  @override
  Future<DayReport> dayReport(String workspaceId, {required String dayCloseId}) async =>
      DayReport.fromJson(await _call('counter_day_report_v1', {'p_workspace_id': workspaceId, 'p_day_close_id': dayCloseId}));
}
