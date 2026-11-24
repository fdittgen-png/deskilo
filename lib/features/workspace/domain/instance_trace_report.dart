// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — an error report as the installation's operator reads it
// (`instance_trace_reports_v1`, 0956): what the app sent, nothing more.

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// How many reports the operator's list reads at a time.
const int traceReportsPageSize = 50;

class InstanceTraceReport {
  const InstanceTraceReport({
    required this.id,
    required this.reportedAt,
    required this.appVersion,
    required this.platform,
    required this.failureType,
    required this.stack,
    this.schemaVersion,
    this.failureCode,
  });

  factory InstanceTraceReport.fromJson(Map<String, Object?> json) {
    final r = JsonReader.of(json, context: 'instance_trace_reports_v1');
    return InstanceTraceReport(
      id: r.string('id'),
      reportedAt: r.dateTime('reported_at'),
      appVersion: r.string('app_version'),
      schemaVersion: r.intOrNull('schema_version'),
      platform: r.string('platform'),
      failureType: r.string('failure_type'),
      failureCode: r.stringOrNull('failure_code'),
      stack: r.stringOr('stack'),
    );
  }

  final String id;
  final DateTime reportedAt;
  final String appVersion;
  final int? schemaVersion;
  final String platform;

  /// Where in the app and what kind (`money/StateError`).
  final String failureType;
  final String? failureCode;

  /// Redacted by the app before it was sent.
  final String stack;
}
