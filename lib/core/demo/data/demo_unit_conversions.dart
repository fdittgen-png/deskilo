// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- the Demo keeps the general unit conversions of each business in memory, with the server's own rules (0967): a business starts
// with what its built-in units convert between; a unit made later gets its conversions to the units of its dimension (editable rows);
// a conversion is written between two different units of the business, none of them a packaging unit, with a factor above zero; the
// one written for a pair replaces the one that was, whichever way round; a retried request id answers once. Nothing leaves the process.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/stock/domain/stock_config.dart';
import '../../../features/stock/domain/unit_conversions.dart';
import '../../../features/stock/domain/workspace_units.dart';
import '../../codes/dk_code.dart';

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

class DemoUnitConversions implements UnitConversions {
  /// The units of the business, as the Demo's unit port holds them (a conversion joins two of them).
  List<WorkspaceUnit> Function(String workspaceId) unitsOf = (_) => builtInUnits;

  final Map<String, List<UnitConversion>> _rows = {};
  final Map<String, Object> _answers = {};
  final Map<String, String> _digests = {};

  /// The conversions of [workspaceId] now (the ledger reads them as they stand).
  List<UnitConversion> rows(String workspaceId) => _rows.putIfAbsent(workspaceId, () => [...builtInConversions]);

  /// A unit was made or its factor changed: its conversions are written again (0967 `workspace_units_relink`).
  void unitSaved(String workspaceId, WorkspaceUnit unit, List<WorkspaceUnit> all) {
    final list = rows(workspaceId)..removeWhere((c) => c.fromUnit == unit.code || c.toUnit == unit.code);
    for (final c in linkedConversions(all)) {
      if ((c.fromUnit == unit.code || c.toUnit == unit.code) && !list.any((o) => o.joins(c.fromUnit, c.toUnit))) list.add(c);
    }
  }

  @override
  Future<List<UnitConversion>> conversions(String workspaceId) async => [...rows(workspaceId)]
    ..sort((a, b) => a.fromUnit != b.fromUnit ? a.fromUnit.compareTo(b.fromUnit) : a.toUnit.compareTo(b.toUnit));

  @override
  Future<UnitConversion> save(String workspaceId, {required String requestId, required UnitConversion conversion}) async {
    final digest = '$workspaceId|save|${conversion.fromUnit}|${conversion.toUnit}|${conversion.factorNum}|${conversion.factorDen}';
    _begin(requestId, digest);
    if (_answers[requestId] case final UnitConversion done?) return done;
    final units = {for (final u in unitsOf(workspaceId)) u.code: u};
    final from = units[conversion.fromUnit];
    final to = units[conversion.toUnit];
    if (from == null) throw const StockConfigRefused('from_unit', StockRefusal.unitUnknown);
    if (to == null) throw const StockConfigRefused('to_unit', StockRefusal.unitUnknown);
    if (from.code == to.code) throw const StockConfigRefused('to_unit', StockRefusal.conversionSameUnit);
    if (from.dimension == UnitDimension.package || to.dimension == UnitDimension.package) {
      throw const StockConfigRefused('from_unit', StockRefusal.packageUnit);
    }
    if (conversion.factorNum <= 0 || conversion.factorDen <= 0) throw const StockConfigRefused('factor', StockRefusal.factorInvalid);
    final g = _gcd(conversion.factorNum, conversion.factorDen);
    final written = UnitConversion(
      fromUnit: conversion.fromUnit,
      toUnit: conversion.toUnit,
      factorNum: conversion.factorNum ~/ g,
      factorDen: conversion.factorDen ~/ g,
    );
    rows(workspaceId)
      ..removeWhere((c) => c.joins(written.fromUnit, written.toUnit))
      ..add(written);
    _answers[requestId] = written;
    return written;
  }

  @override
  Future<void> delete(String workspaceId, {required String requestId, required String fromUnit, required String toUnit}) async {
    _begin(requestId, '$workspaceId|delete|$fromUnit|$toUnit');
    if (_answers[requestId] != null) return;
    final list = rows(workspaceId);
    final before = list.length;
    list.removeWhere((c) => c.joins(fromUnit, toUnit));
    if (list.length == before) throw const StockConfigRefused('conversion', StockRefusal.conversionUnknown);
    _answers[requestId] = true;
  }

  /// A request id answers the request it first came with: another content under it is refused (0948 request_begin).
  void _begin(String requestId, String digest) {
    final first = _digests[requestId];
    if (first != null && first != digest) {
      throw const PostgrestException(message: 'this request id was already used for a different request', code: DkCode.dkg07);
    }
    _digests[requestId] = digest;
  }
}
