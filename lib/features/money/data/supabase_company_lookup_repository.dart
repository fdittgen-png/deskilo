// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/company_lookup.dart';

/// #2863 — the `supplier-lookup` edge function. The server decides who may
/// ask and talks to the registry; this reads its neutral answer. A
/// transport failure is an outcome (the registry could not be reached),
/// the server's refusal of the caller is thrown.
class SupabaseCompanyLookupRepository implements CompanyLookupRepository {
  const SupabaseCompanyLookupRepository(this._client);

  final SupabaseClient _client;

  /// How long the app waits for the function, which itself gives the
  /// registry less, before the question counts as timed out.
  static const Duration _clientTimeout = Duration(seconds: 25);

  @override
  Future<CompanyLookupResult> lookup(
    String workspaceId,
    String providerId,
    CompanyLookupRequest request,
  ) async {
    try {
      final response = await _client.functions
          .invoke(
            'supplier-lookup',
            body: {'workspace_id': workspaceId, ...request.toWire(providerId)},
          )
          .timeout(_clientTimeout);
      final Object? data = response.data;
      if (data is! Map) {
        return CompanyLookupResult.failure(
          providerId,
          LookupRetrieval.malformed,
        );
      }
      return CompanyLookupResult.fromJson(data);
    } on FunctionException catch (e, st) {
      final retrieval = lookupFailureForStatus(e.status);
      if (retrieval == null) {
        Error.throwWithStackTrace(CompanyLookupRefused(_reason(e.details)), st);
      }
      TraceLogger.instance.warn(
        'money',
        'supplier lookup: the function answered ${e.status}',
        error: e,
        stackTrace: st,
      );
      return CompanyLookupResult.failure(
        providerId,
        retrieval,
        detail: _reason(e.details),
      );
    } on TimeoutException catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'supplier lookup: no answer in time',
        error: e,
        stackTrace: st,
      );
      return CompanyLookupResult.failure(providerId, LookupRetrieval.timeout);
    }
  }

  /// The function's `{error}` body, or the transport's own words.
  static String _reason(Object? details) => switch (details) {
    Map() => details['error']?.toString() ?? '',
    null => '',
    _ => details.toString(),
  };
}

/// The outcome an HTTP status of the function stands for; null for a
/// refusal of the caller (401, 403), which is not a registry outcome. A
/// transport failure arrives as status 0: the registry was not reached.
@visibleForTesting
LookupRetrieval? lookupFailureForStatus(int status) => switch (status) {
  401 || 403 => null,
  400 => LookupRetrieval.invalidInput,
  408 || 504 => LookupRetrieval.timeout,
  429 => LookupRetrieval.throttled,
  _ => LookupRetrieval.unavailable,
};
