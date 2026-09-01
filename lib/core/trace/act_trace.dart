// SPDX-License-Identifier: 0BSD
import 'trace_logger.dart';

/// #791 — the acts a member performs narrate themselves, not just their
/// crashes.
///
/// Two field reports arrived with an EMPTY developer trace: a map
/// check-in that "failed" while the seat QR worked (#772), and an invite
/// QR the scanner "could not recognise" (#773). Nothing threw in either
/// case, so an error log had nothing to record. The map had simply
/// decided not to offer a check-in, and the join screen had decoded a QR
/// and dropped it — decisions, not failures, and decisions were exactly
/// what the log could not see.
///
/// So these entries record what the app CHOSE, in three shapes:
///
/// * [step] — a decision or a server round trip that went as intended.
/// * [refused] — the app declining to do the thing the member reached
///   for. Warn level: this is what someone scrolls to first when the
///   complaint is "I tapped it and nothing happened".
/// * [failed] — an exception, with the same fields as the step that was
///   attempting it, so a red line is never orphaned from its context.
///
/// Every line is a verb followed by `key=value` pairs, so a trace can be
/// grepped (`grep 'act=check-in' deskilo-trace.log`) and one attempt read
/// end to end: what was tapped, what the client decided, what the server
/// was asked, what it answered.
class ActTrace {
  const ActTrace(this.area);

  /// Booking acts: reserve, check in, check out, cancel.
  static const booking = ActTrace('booking');

  /// Camera scanning: which lens opened, what decoded, what was refused.
  static const scan = ActTrace('scan');

  final String area;

  void step(String what, [Map<String, Object?> fields = const {}]) =>
      TraceLogger.instance.log(TraceLevel.info, area, line(what, fields));

  void refused(String what, [Map<String, Object?> fields = const {}]) =>
      TraceLogger.instance.warn(area, line(what, fields));

  void failed(
    String what,
    Object error,
    StackTrace stackTrace, [
    Map<String, Object?> fields = const {},
  ]) =>
      TraceLogger.instance.error(
        area,
        line(what, fields),
        error: error,
        stackTrace: stackTrace,
      );

  /// `check-in refused reason=window-closed reservation=… status=reserved`
  ///
  /// A null value is written as `null` rather than dropped: "the member id
  /// was null" is the finding in half these reports, and a field that
  /// vanishes when it is null cannot report that.
  static String line(String what, Map<String, Object?> fields) {
    final b = StringBuffer(what);
    for (final entry in fields.entries) {
      b.write(' ${entry.key}=${_value(entry.value)}');
    }
    return b.toString();
  }

  static String _value(Object? value) {
    if (value == null) return 'null';
    if (value is DateTime) return value.toIso8601String();
    // Spaces would break `key=value` parsing back apart.
    return value.toString().replaceAll(' ', '_');
  }

  /// What a scanned payload IS, never what it says.
  ///
  /// Invite codes and badge tokens are secrets that admit someone to a
  /// workspace, and a trace is meant to be exported and sent to whoever
  /// is debugging — so the log records the SHAPE that decoding turns on
  /// (scheme, host, which parameters are present, how long) and never the
  /// value. "It decoded a deskilo://join with a code parameter and we
  /// still refused it" is the whole diagnosis; the code itself adds
  /// nothing but a leak.
  static String payloadShape(String payload) {
    final text = payload.trim();
    if (text.isEmpty) return 'empty';
    final uri = Uri.tryParse(text);
    if (uri != null && uri.scheme.isNotEmpty) {
      final keys = uri.queryParameters.keys.toList()..sort();
      final params = keys.isEmpty ? '' : '?${keys.join(',')}';
      return '${uri.scheme}://${uri.host}$params(${text.length})';
    }
    return 'text(${text.length})';
  }
}
