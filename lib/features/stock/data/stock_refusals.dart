// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169/#4170/#4171 -- how a refusal of the stock commands becomes a typed failure:
// less than asked on hand (DKG03), a stale revision (DKG10), a unit or tracking the first movement fixed or a
// history that is kept (DKG08), and a content that is not valid with its
// field and reason (DKG11). Any other answer is not a refusal of ours: it
// leaves the boundary as the app's own failure (#4411, #4413), never as the
// SDK's type.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/codes/dk_code.dart';
import '../../../core/data/app_failure_from.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/stock_config.dart';

/// Throws the typed failure [e] stands for, with its stack; a code this
/// table does not know is the app's [appFailureFrom] of it. [pieces]: the command names pieces
/// (#4379 put-away), so a refusal of a named piece (DKG25, DKG26) is typed with the piece it names.
Never throwStockFailure(PostgrestException e, StackTrace stack, {bool pieces = false}) {
  switch (e.code) {
    case DkCode.dkg25 || DkCode.dkg26 when pieces:
      Error.throwWithStackTrace(StockTagRefused(e.code!, _detail(e.details)), stack);
    case DkCode.dkg27 || DkCode.dkg28 || DkCode.dkg29:
      Error.throwWithStackTrace(StockUnitRefused(e.code!, _detail(e.details)), stack);
    case DkCode.dkg10:
      Error.throwWithStackTrace(const StockConfigStale(), stack);
    case DkCode.dkg08:
      Error.throwWithStackTrace(const StockConfigInUse(), stack);
    case DkCode.dkg03:
      Error.throwWithStackTrace(StockNotEnough(e.message), stack);
    case DkCode.dkg11:
      Error.throwWithStackTrace(_refused(e.details), stack);
    case DkCode.dkg22 || DkCode.dkg23 || DkCode.dkg24 || DkCode.dkg04:
      Error.throwWithStackTrace(StockTagRefused(e.code!, _detail(e.details)), stack);
    default:
      Error.throwWithStackTrace(appFailureFrom(e), stack);
  }
}

/// The field and the reason the server wrote as JSON in its detail.
StockConfigRefused _refused(Object? details) {
  try {
    final r = JsonReader.of(jsonDecode('$details'), context: DkCode.dkg11);
    return StockConfigRefused(r.string('field'), StockRefusal.fromWire(r.string('reason')));
  } on Object catch (error, stack) {
    TraceLogger.instance.warn('stock', 'a stock refusal detail was not JSON', error: error, stackTrace: stack);
    return const StockConfigRefused('request', StockRefusal.malformed);
  }
}

/// The JSON object the server wrote in a refusal's detail; empty when it is not one.
Map<String, Object?> _detail(Object? details) {
  try {
    final decoded = details is String ? jsonDecode(details) : details;
    return decoded is Map ? Map<String, Object?>.from(decoded) : const {};
  } on Object catch (error, stack) {
    TraceLogger.instance.warn('stock', 'a stock refusal detail was not JSON', error: error, stackTrace: stack);
    return const {};
  }
}
