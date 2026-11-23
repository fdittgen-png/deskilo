// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169/#4170/#4171 -- how a refusal of the stock commands becomes a typed failure:
// less than asked on hand (DKG03), a stale revision (DKG10), a unit or tracking the first movement fixed or a
// history that is kept (DKG08), and a content that is not valid with its
// field and reason (DKG11). Anything else is not a refusal of ours and is
// rethrown as it came.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/stock_config.dart';

/// Throws the typed failure [e] stands for, with its stack, or rethrows it.
Never throwStockFailure(PostgrestException e, StackTrace stack) {
  switch (e.code) {
    case 'DKG10':
      Error.throwWithStackTrace(const StockConfigStale(), stack);
    case 'DKG08':
      Error.throwWithStackTrace(const StockConfigInUse(), stack);
    case 'DKG03':
      Error.throwWithStackTrace(StockNotEnough(e.message), stack);
    case 'DKG11':
      Error.throwWithStackTrace(_refused(e.details), stack);
    case 'DKG22' || 'DKG23' || 'DKG24' || 'DKG04':
      Error.throwWithStackTrace(StockTagRefused(e.code!, _detail(e.details)), stack);
    default:
      Error.throwWithStackTrace(e, stack);
  }
}

/// The field and the reason the server wrote as JSON in its detail.
StockConfigRefused _refused(Object? details) {
  try {
    final r = JsonReader.of(jsonDecode('$details'), context: 'DKG11');
    return StockConfigRefused(r.string('field'), r.string('reason'));
  } on Object catch (error, stack) {
    TraceLogger.instance.warn('stock', 'a stock refusal detail was not JSON: $error\n$stack');
    return const StockConfigRefused('request', 'malformed');
  }
}

/// The JSON object the server wrote in a refusal's detail; empty when it is not one.
Map<String, Object?> _detail(Object? details) {
  try {
    final decoded = details is String ? jsonDecode(details) : details;
    return decoded is Map ? Map<String, Object?>.from(decoded) : const {};
  } on Object catch (error, stack) {
    TraceLogger.instance.warn('stock', 'a stock refusal detail was not JSON: $error\n$stack');
    return const {};
  }
}
