// SPDX-License-Identifier: 0BSD
import '../trace/trace_logger.dart';

/// #1148 — an enum read off the wire, with a floor under it.
///
/// `Enum.values.byName` THROWS on a value it does not know, and the row
/// mappers call it inside `rows.map(...).toList()` — so one widened wire
/// value (a status, an orientation, a ledger category added server-side)
/// emptied the whole member list, plan or statement on any client that
/// had not updated yet. There is no minimum-version gate; there will be
/// widened values.
///
/// The unknown is TRACED, not swallowed: the Developer screen says which
/// value arrived and where, and the row survives with [fallback] — which
/// every caller chooses to be the SAFE reading, never the privileged one.
T enumOr<T extends Enum>(
  List<T> values,
  String? raw,
  T fallback, {
  required String area,
}) {
  final hit = raw == null ? null : values.asNameMap()[raw];
  if (hit != null) return hit;
  TraceLogger.instance.warn(
    area,
    'unknown ${values.first.runtimeType} on the wire: $raw — read as ${fallback.name}',
  );
  return fallback;
}
