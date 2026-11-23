// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 — the Demo's analysis export: the snapshot the server's export read
// answers (`bi_export_snapshot_v1`), made from the Demo's own capacity and
// finance figures, so the file the app writes from it holds what the Demo's
// pages show. A figure the Demo does not hold (accounts payable, say) is the
// server's own `0A000` for that figure and is left out and said, never
// approximated; amounts keep their currency; the same ask is the same hash.
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/trace/trace_logger.dart';
import '../../../features/workspace/domain/bi_batch.dart';
import '../../../features/workspace/domain/bi_report_snapshot.dart';
import '../../../features/workspace/domain/kpi_contract.dart';
import '../../data/pg_code.dart';

class DemoBiExportRepository implements BiExportRepository {
  DemoBiExportRepository({
    required this.seats,
    required this.finance,
    required this.now,
  });

  final KpiRepository seats;
  final FinanceKpiRepository finance;
  final DateTime Function() now;

  @override
  Future<Object?> snapshot(
    String workspaceId, {
    required List<BiBatchRequest> requests,
    required BiExportFormat format,
    String? reportId,
    int? reportRevision,
  }) async {
    final results = [for (final r in requests) await _answer(workspaceId, r)];
    return {
      'workspace_id': workspaceId,
      'format': format.name,
      'computed_at': now().toUtc().toIso8601String(),
      'hash': _hash('$workspaceId|${format.name}|$results'),
      'results': results,
    };
  }

  Future<Map<String, Object?>> _answer(
    String workspaceId,
    BiBatchRequest r,
  ) async {
    final definition = kpiDefinitionOf(r.metricId);
    final base = <String, Object?>{
      'request_key': r.key,
      if (definition != null) ...{
        'metric_version': definition.version,
        'unit': definition.unit,
        'date_basis': definition.dateBasis.wire,
        'coverage': definition.coverage.wire,
      },
    };
    try {
      if (r.metricId == 'capacity.seat_utilisation') {
        final k = await seats.seatCapacity(
          workspaceId,
          from: r.from!,
          to: r.to!,
          levelId: r.levelId,
        );
        return {...base, 'ok': true, 'result': _seat(k)};
      }
      if (r.metricId.startsWith('finance.')) {
        final k = await finance.summary(
          workspaceId,
          fromMonth: r.fromMonth!,
          toMonth: r.toMonth!,
        );
        return {...base, 'ok': true, 'result': _money(k)};
      }
    } on KpiUnavailable catch (e, st) {
      TraceLogger.instance.error(
        'workspace',
        'a figure of the Demo export is unavailable',
        error: e,
        stackTrace: st,
      );
      return {...base, 'ok': false, 'code': PgCode.invalidParameterValue, 'message': e.reason};
    }
    return {
      ...base,
      'ok': false,
      'code': PgCode.featureNotSupported,
      'message': 'the Demo does not answer this figure',
    };
  }

  static List<String> _quality(Set<KpiQuality> q) => [
    for (final e in q) _wire[e]!,
  ];

  static const _wire = {
    KpiQuality.knownZero: 'known_zero',
    KpiQuality.notRecorded: 'not_recorded',
    KpiQuality.notApplicable: 'not_applicable',
    KpiQuality.partial: 'partial',
    KpiQuality.stale: 'stale',
    KpiQuality.unavailable: 'unavailable',
    KpiQuality.forbidden: 'forbidden',
  };

  static Map<String, Object?> _seat(SeatCapacityKpi k) => {
    'from': k.from.toUtc().toIso8601String(),
    'to': k.to.toUtc().toIso8601String(),
    'physical_seat_hours': k.physicalSeatHours,
    'offered_seat_hours': k.offeredSeatHours,
    'reserved_seat_hours': k.reservedSeatHours,
    'reserved_outside_offered_seat_hours': k.reservedOutsideOfferedSeatHours,
    'overlapping_seat_hours': k.overlappingSeatHours,
    'seats': k.seats,
    'rooms_without_seats': k.roomsWithoutSeats,
    'offered_room_hours': k.offeredRoomHours,
    'reserved_room_hours': k.reservedRoomHours,
    'quality': _quality(k.quality),
    'reasons': k.reasons,
    'computed_at': k.computedAt.toUtc().toIso8601String(),
    if (k.historySince != null)
      'history_since': k.historySince!.toUtc().toIso8601String(),
  };

  static Map<String, Object?> _money(FinanceSummaryKpi k) => {
    'from': k.fromMonth,
    'to': k.toMonth,
    'currency': k.currency,
    'invoiced_minor': k.invoicedMinor,
    'credit_notes_minor': k.creditNotesMinor,
    'collected_minor': k.collectedMinor,
    'invoices': k.invoices,
    'matches': k.matches,
    'quality': _quality(k.quality),
    'reasons': k.reasons,
    'computed_at': k.computedAt.toUtc().toIso8601String(),
    if (k.lastChangeAt != null)
      'last_change_at': k.lastChangeAt!.toUtc().toIso8601String(),
  };

  /// A stable digest of [text]: the same ask gives the same one, on every
  /// platform (a 64-bit integer does not survive the web build).
  static String _hash(String text) =>
      sha256.convert(utf8.encode(text)).toString();
}
