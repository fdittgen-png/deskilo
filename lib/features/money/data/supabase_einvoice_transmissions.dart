// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert' show base64Encode;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../domain/einvoice_gateway.dart';
import '../domain/einvoice_transmissions.dart';
import '../domain/payment_provider.dart';
import '../domain/renderer_declaration.dart';

/// #2591 — e-invoice transmission and its channel credentials, with its own
/// client. The bodies are the ones that lived in the money repository and its
/// part files.
class SupabaseEInvoiceTransmissions implements EInvoiceTransmissions {
  SupabaseEInvoiceTransmissions(
    this._client, {
    Future<String> Function()? appVersion,
  }) : _appVersion = appVersion ?? _unknownVersion;

  final SupabaseClient _client;

  /// The one source of the app version (#3336); '' when it cannot be told.
  final Future<String> Function() _appVersion;

  static Future<String> _unknownVersion() async => '';

  @override
  Future<EInvoiceGatewayConfig> fetchEInvoiceGateway(String workspaceId) async {
    final data = await _invokeSend({
      'action': 'config',
      'workspace_id': workspaceId,
    });
    if (data == null) return EInvoiceGatewayConfig.notConfigured;
    return EInvoiceGatewayConfig(
      configured: data['configured'] == true,
      provider: data['provider'] as String? ?? 'generic',
      missing: [
        for (final field in (data['missing'] as List? ?? const []))
          field as String,
      ],
      environments: {
        for (final entry in (data['environments'] as Map? ?? const {}).entries)
          entry.key as String: entry.value == true,
      },
      // #568 — absent on a pre-destination function: the customer leg
      // then stays hidden (the deployment latch).
      destinations: {
        for (final entry in (data['destinations'] as Map? ?? const {}).entries)
          entry.key as String: EInvoiceDestination(
            configured: (entry.value as Map)['configured'] == true,
            missing: [
              for (final field
                  in ((entry.value as Map)['missing'] as List? ?? const []))
                field as String,
            ],
            environments: {
              for (final env
                  in ((entry.value as Map)['environments'] as Map? ?? const {})
                      .entries)
                env.key as String: env.value == true,
            },
          ),
      },
    );
  }

  @override
  Future<Map<String, InvoiceTransmission>> fetchInvoiceTransmissions(
    String workspaceId,
  ) async {
    // #1310 S2 — paged. The fold below keeps only the newest row per
    // invoice, so a truncated read would silently drop whole invoices'
    // transmission state rather than merely shortening a list.
    final rows = await fetchAllPages(
      table: 'invoice_transmissions',
      build: () => _client
          .from('invoice_transmissions')
          .select()
          .eq('workspace_id', workspaceId)
          .order('sent_at', ascending: false)
          .order('id', ascending: true),
    );
    final latest = <String, InvoiceTransmission>{};
    for (final row in rows) {
      // Ordered newest first: the first row per invoice is the current one.
      final transmission = InvoiceTransmission.fromRow(row);
      latest.putIfAbsent(transmission.invoiceId, () => transmission);
    }
    return latest;
  }

  @override
  Future<EInvoiceProviderStatus> fetchEInvoiceStatus(String workspaceId) async {
    final data = await _client.rpc<dynamic>(
      'einvoice_status',
      params: {'p_workspace_id': workspaceId},
    );
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
    return EInvoiceProviderStatus(
      configured: map['configured'] == true,
      // #2358 — the connector the space uses; 'generic' before it existed.
      provider: JsonReader.of(map).stringOr('provider', 'generic'),
      fields: {
        for (final entry in (map['fields'] as Map? ?? const {}).entries)
          entry.key as String: '${entry.value}',
      },
      secretsSet: [
        for (final name in (map['secrets_set'] as List? ?? const []))
          name as String,
      ],
    );
  }

  @override
  Future<EInvoiceSubmission> sendEInvoice({
    required String workspaceId,
    required String invoiceId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    String environment = 'prod',
    String destination = 'government',
    String format = '',
    String receiverScheme = '',
    String receiverId = '',
  }) async {
    final data = await _invokeSend({
      // #2358 — the syntax built for the channel, and where to deliver it.
      if (format.isNotEmpty) 'format': format,
      if (receiverId.isNotEmpty) 'receiver_scheme': receiverScheme,
      if (receiverId.isNotEmpty) 'receiver_id': receiverId,
      'workspace_id': workspaceId,
      'invoice_id': invoiceId,
      'file_name': fileName,
      'mime_type': mimeType,
      'content_base64': base64Encode(bytes),
      'environment': environment,
      'destination': destination,
      // #3336 — declared, never proof: the server keeps it apart
      'declared': RendererDeclaration(
        renderer: format,
        appVersion: await _appVersion(),
      ).toJson(),
    });
    if (data == null) {
      return const EInvoiceSubmission(
        status: EInvoiceSubmissionStatus.failed,
        detail: 'not_deployed',
      );
    }
    return EInvoiceSubmission(
      status: EInvoiceSubmissionStatus.fromWire(
        phase: data['phase'] as String?,
        status: data['status'] as String?,
      ),
      externalId: data['external_id'] as String? ?? '',
      detail: data['detail'] as String? ?? data['error'] as String? ?? '',
    );
  }

  @override
  Future<EInvoiceSubmission> requestEInvoiceReceipt({
    required String workspaceId,
    required String transmissionId,
  }) async {
    final data = await _invokeSend({
      'workspace_id': workspaceId,
      'action': 'status',
      'transmission_id': transmissionId,
    });
    if (data == null) {
      return const EInvoiceSubmission(
        status: EInvoiceSubmissionStatus.failed,
        detail: 'not_deployed',
      );
    }
    final answer = JsonReader.of(data, context: 'send-e-invoice status');
    return EInvoiceSubmission(
      status: EInvoiceSubmissionStatus.fromWire(
        phase: answer.stringOr('phase'),
        status: answer.stringOr('status'),
      ),
      detail: answer.stringOr('detail', answer.stringOr('error')),
    );
  }

  @override
  Future<EInvoiceResolveResult> resolveEInvoiceTransmission({
    required String workspaceId,
    required String transmissionId,
    required EInvoiceResolution resolution,
    required String reason,
    required String evidence,
    bool documentRejected = false,
  }) async {
    final data = await _invokeSend({
      'workspace_id': workspaceId,
      'action': 'resolve',
      'transmission_id': transmissionId,
      'outcome': resolution.name,
      'reason': reason,
      'evidence': evidence,
      if (documentRejected && resolution == EInvoiceResolution.accepted)
        'verdict': {'document': 'rejected'},
    });
    if (data == null) {
      return const EInvoiceResolveResult(resolved: false, error: 'not_deployed');
    }
    final answer = JsonReader.of(data, context: 'send-e-invoice resolve');
    return EInvoiceResolveResult(
      resolved: data['resolved'] == true,
      error: data['resolved'] == true
          ? ''
          : answer.stringOr('error', 'already_settled'),
    );
  }

  @override
  Future<void> setEInvoiceCredentials(
    String workspaceId,
    Map<String, String> config,
  ) async {
    await _client.rpc<void>(
      'set_einvoice_credentials',
      params: {'p_workspace_id': workspaceId, 'p_config': config},
    );
  }

  @override
  Future<void> clearEInvoiceCredentials(String workspaceId) async {
    await _client.rpc<void>(
      'clear_einvoice_credentials',
      params: {'p_workspace_id': workspaceId},
    );
  }

  @override
  Future<EInvoiceTestState> fetchEInvoiceTest(String workspaceId) async {
    final data = await _invokeSend({
      'workspace_id': workspaceId,
      'action': 'test_state',
    });
    return data == null
        ? EInvoiceTestState.unavailable
        : EInvoiceTestState.fromWire(data);
  }

  @override
  Future<EInvoiceTestSent> sendEInvoiceTest({
    required String workspaceId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final data = await _invokeSend({
      'workspace_id': workspaceId,
      'action': 'test',
      'file_name': fileName,
      'mime_type': 'application/xml',
      'format': 'fatturaPa',
      'content_base64': base64Encode(bytes),
    });
    if (data == null) {
      return const EInvoiceTestSent(refusal: EInvoiceTestRefusal.unavailable);
    }
    final error = data['error'] as String?;
    final phase = data['phase'] as String?;
    return EInvoiceTestSent(
      refusal: error != null
          ? EInvoiceTestRefusal.fromWire(error)
          : phase == 'rejected' || phase == 'failed'
          ? EInvoiceTestRefusal.failed
          : EInvoiceTestRefusal.none,
      missing: [
        for (final field in (data['missing'] as List? ?? const []))
          '$field',
      ],
    );
  }

  /// Same seam as the payment function: a 404 means "not deployed", which
  /// is a configuration answer, not an error.
  Future<Map<String, dynamic>?> _invokeSend(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'send-e-invoice',
        body: body,
      );
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } on FunctionException catch (e, st) {
      if (e.status == 404) return null;
      // A 409/502 carries the platform's own words in the body — surface
      // them rather than a generic failure.
      final details = e.details;
      if (details is Map) return Map<String, dynamic>.from(details);
      // trace-exempt: rethrown for the caller's runGuarded to trace.
      Error.throwWithStackTrace(
        PaymentGatewayException(
          e.status,
          e.details?.toString() ?? e.reasonPhrase ?? 'function error',
        ),
        st,
      );
    }
  }
}
