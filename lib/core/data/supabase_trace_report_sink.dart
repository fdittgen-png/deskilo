// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — the installation's door for error reports (`submit_trace_report_v1`,
// 0956). Its answer is read; a refusal (an assistant's session, nobody signed
// in) arrives as the client's exception and the reporter drops the report.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../trace/trace_report.dart';

class SupabaseTraceReportSink implements TraceReportSink {
  const SupabaseTraceReportSink(this._client);

  final SupabaseClient _client;

  @override
  Future<TraceReportAnswer> submit(TraceReport report) async =>
      TraceReportAnswer.fromWire(
        await _client.rpc<Object?>(
          'submit_trace_report_v1',
          params: {
            'p_device_id': report.deviceId,
            'p_app_version': report.appVersion,
            'p_schema_version': report.schemaVersion,
            'p_platform': report.platform,
            'p_failure_type': report.failureType,
            'p_failure_code': report.failureCode,
            'p_stack': report.stack,
          },
        ),
      );
}
