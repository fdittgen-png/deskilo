// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — an error report as the installation's operator reads it
// (`instance_trace_reports_v1`, 0953): what the app sent, nothing more.

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

  factory InstanceTraceReport.fromJson(Map<String, Object?> json) =>
      InstanceTraceReport(
        id: json['id']! as String,
        reportedAt: DateTime.parse(json['reported_at']! as String),
        appVersion: json['app_version']! as String,
        schemaVersion: (json['schema_version'] as num?)?.toInt(),
        platform: json['platform']! as String,
        failureType: json['failure_type']! as String,
        failureCode: json['failure_code'] as String?,
        stack: json['stack'] as String? ?? '',
      );

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
