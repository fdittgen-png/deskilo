// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/hmrc_submission.dart';

/// #2470 — the HMRC submission over `hmrc_connection_v1` (0649) and the
/// `accounting-connect` function's `authorize` and `hmrc_submit` actions.
/// No answer carries a token.
class SupabaseHmrcRepository implements HmrcRepository {
  const SupabaseHmrcRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<HmrcState> state(String workspaceId) async => HmrcState.fromJson(
    await _client.rpc<Object?>(
      'hmrc_connection_v1',
      params: {'p_workspace_id': workspaceId},
    ),
  );

  @override
  Future<Uri> startConnect(String workspaceId, String issuerSiteId) async {
    final response = await _client.functions.invoke(
      'accounting-connect',
      body: {
        'action': 'authorize',
        'workspace_id': workspaceId,
        'issuer_site_id': issuerSiteId,
        'target_id': 'hmrc_mtd',
        'display_name': 'HMRC',
      },
    );
    final data = response.data;
    final url = data is Map ? Uri.tryParse('${data['authorize_url']}') : null;
    if (url == null || !url.hasScheme) {
      throw const FormatException('accounting-connect: no HMRC sign-in page');
    }
    return url;
  }

  @override
  Future<HmrcOutcome> submit({
    required String declarationId,
    required String connectionId,
    required Map<String, num> boxes,
    required HmrcClientValues client,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'accounting-connect',
        body: {
          'action': 'hmrc_submit',
          'connection_id': connectionId,
          'declaration_id': declarationId,
          'boxes': boxes,
          'client': client.toJson(),
        },
      );
      final data = response.data;
      final receipt = data is Map ? HmrcReceipt.fromJson(data['receipt']) : null;
      if (receipt == null || receipt.formBundleNumber.isEmpty) {
        // A success without a receipt is not a filing.
        return const HmrcUnconfirmed(code: 'NO_RECEIPT');
      }
      return HmrcFiled(receipt);
    } on FunctionException catch (e) {
      return hmrcOutcomeOfRefusal(e.status, e.details);
    }
  }
}

/// The outcome a non-2xx answer of the function stands for. Public so the
/// mapping is tested without a network.
HmrcOutcome hmrcOutcomeOfRefusal(int status, Object? details) {
  final Map<Object?, Object?> body = details is Map ? details : const {};
  final error = '${body['error'] ?? ''}';
  final code = '${body['code'] ?? ''}';
  if (error == 'accepted_not_recorded') {
    return HmrcAcceptedNotRecorded(HmrcReceipt.fromJson(body['receipt']));
  }
  if (error == 'unconfirmed' || status == 504) {
    return HmrcUnconfirmed(code: code);
  }
  if (error == 'fraud_headers_missing') {
    return HmrcRefused(
      HmrcRefusal.fraudHeadersMissing,
      missing: [for (final m in (body['missing'] as List? ?? const [])) '$m'],
    );
  }
  final refusal = switch (error) {
    'hmrc_not_configured' => HmrcRefusal.notConfigured,
    'connect_hmrc_first' => HmrcRefusal.notConnected,
    'wrong_registration' => HmrcRefusal.wrongRegistration,
    'sign_in_again' => HmrcRefusal.signInAgain,
    'figures_differ_from_return' ||
    'return_not_computable' => HmrcRefusal.figuresDiffer,
    'acquisition_not_supported' => HmrcRefusal.acquisitionNotSupported,
    'no_open_obligation' => HmrcRefusal.noOpenObligation,
    'already_submitted' => HmrcRefusal.alreadySubmitted,
    'not_authorised' => HmrcRefusal.notAuthorised,
    'refused' || 'invalid_return' => HmrcRefusal.refused,
    'busy' => HmrcRefusal.busy,
    'in_flight' => HmrcRefusal.inFlight,
    'accepted_for_other_figures' => HmrcRefusal.acceptedForOtherFigures,
    'unreachable' => HmrcRefusal.unreachable,
    _ when status == 403 => HmrcRefusal.notAllowed,
    _ => HmrcRefusal.other,
  };
  return HmrcRefused(refusal, code: code);
}
