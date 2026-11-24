// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — an error the app recorded, as it may leave the device: to the
// installation the person is signed in to, never to a third party. Only what
// the trace already holds, scrubbed as the support bundle and the exported log
// are: the app and schema versions, the platform, the failure's kind and code,
// and the stack. Never the error's own sentence, which can quote a person's
// data, never a typed value, a token, an address or a name.
import 'dart:convert';

import 'redaction.dart';
import 'trace_logger.dart';

/// One error report.
class TraceReport {
  const TraceReport({
    required this.deviceId,
    required this.appVersion,
    required this.schemaVersion,
    required this.platform,
    required this.failureType,
    required this.failureCode,
    required this.stack,
  });

  /// A random id this device keeps; data only, the budget is the person's.
  final String deviceId;
  final String appVersion;
  final int? schemaVersion;
  final String platform;

  /// Where it was recorded and what kind of error it was (`money/StateError`).
  final String failureType;
  final String? failureCode;

  /// The redacted stack, cut to the installation's size cap.
  final String stack;
}

/// What the installation answered. Every answer but [stored] means the report
/// was dropped there; the app never sends it again.
enum TraceReportAnswer {
  stored('stored'),
  tooLarge('too_large'),
  rateLimited('rate_limited'),
  malformed('malformed'),
  unknown('');

  const TraceReportAnswer(this.wire);
  final String wire;

  static TraceReportAnswer fromWire(Object? wire) => values.firstWhere(
    (a) => a.wire == wire && a != unknown,
    orElse: () => unknown,
  );
}

/// The installation's door for error reports.
abstract interface class TraceReportSink {
  Future<TraceReportAnswer> submit(TraceReport report);
}

/// The longest a report's kind or code may be (the table's own checks).
const _typeLimit = 120;
const _codeLimit = 80;

/// [entry] as a report, or null when it is no error. The stack is scrubbed by
/// the trace's redactor and cut so the whole report fits [maxBytes].
TraceReport? traceReportOf(
  TraceEntry entry, {
  required String deviceId,
  required String appVersion,
  required int? schemaVersion,
  required String platform,
  required int maxBytes,
}) {
  if (entry.level != TraceLevel.error) return null;
  final type = _clip('${entry.area}/${entry.errorType ?? '-'}', _typeLimit);
  final code = entry.errorCode == null
      ? null
      : _clip(entry.errorCode!, _codeLimit);
  final fixed = utf8.encode('$appVersion$platform$type${code ?? ''}').length;
  final stack = _fitBytes(redactTraceLine(entry.stack ?? ''), maxBytes - fixed);
  return TraceReport(
    deviceId: deviceId,
    appVersion: appVersion,
    schemaVersion: schemaVersion,
    platform: platform,
    failureType: type,
    failureCode: code,
    stack: stack,
  );
}

String _clip(String s, int chars) =>
    s.length <= chars ? s : s.substring(0, chars);

/// [s] cut, at a character, to at most [bytes] UTF-8 bytes (nothing when the
/// rest of the report already fills them).
String _fitBytes(String s, int bytes) {
  if (bytes <= 0) return '';
  if (utf8.encode(s).length <= bytes) return s;
  var end = s.length;
  while (end > 0 && utf8.encode(s.substring(0, end)).length > bytes) {
    end = (end * bytes / utf8.encode(s.substring(0, end)).length).floor();
  }
  return s.substring(0, end);
}
