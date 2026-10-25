// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/einvoice_transmissions.dart';

import '../money_repository.dart';

/// #2591 — the demo's e-invoice transmission and its channel credentials,
/// answered from one space's in-memory money store ([FakeMoneyRepository]);
/// every other port of that space reads and writes the same store.
class DemoEInvoiceTransmissions implements EInvoiceTransmissions {
  DemoEInvoiceTransmissions(this._m);

  final FakeMoneyRepository _m;

  @override
  Future<EInvoiceGatewayConfig> fetchEInvoiceGateway(
    String workspaceId,
  ) async => _m.einvoiceGateway;

  @override
  Future<Map<String, InvoiceTransmission>> fetchInvoiceTransmissions(
    String workspaceId,
  ) async => Map.of(_m.transmissions);

  @override
  Future<EInvoiceProviderStatus> fetchEInvoiceStatus(
    String workspaceId,
  ) async => EInvoiceProviderStatus(
    configured: _m.einvoiceConfig.isNotEmpty,
    fields: {
      for (final entry in _m.einvoiceConfig.entries)
        if (entry.key != 'auth_value') entry.key: entry.value,
    },
    secretsSet: [if (_m.einvoiceConfig.containsKey('auth_value')) 'auth_value'],
  );

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
    _m.sentEInvoices.add((
      invoiceId: invoiceId,
      fileName: fileName,
      bytes: bytes.length,
      environment: environment,
      destination: destination,
    ));
    _m.transmissions[invoiceId] = InvoiceTransmission(
      id: 'transmission-${_m.sentEInvoices.length}',
      format: format,
      invoiceId: invoiceId,
      status: _m.einvoiceOutcome,
      sentAt: kTestNow,
      externalId: 'platform-${_m.sentEInvoices.length}',
      environment: environment,
      destination: destination,
    );
    return EInvoiceSubmission(
      status: _m.einvoiceOutcome,
      externalId: 'platform-${_m.sentEInvoices.length}',
      detail: _m.einvoiceOutcome == EInvoiceSubmissionStatus.accepted
          ? ''
          : 'the platform said no',
    );
  }

  /// #2358 — the demo platform answers at once: delivered.
  @override
  Future<EInvoiceSubmission> requestEInvoiceReceipt({
    required String workspaceId,
    required String transmissionId,
  }) async {
    for (final MapEntry(:key, :value) in _m.transmissions.entries) {
      if (value.id == transmissionId) {
        _m.transmissions[key] = value.copyWithReceipt(const {
          'state': 'delivered',
        });
      }
    }
    return const EInvoiceSubmission(status: EInvoiceSubmissionStatus.accepted);
  }

  @override
  Future<void> setEInvoiceCredentials(
    String workspaceId,
    Map<String, String> config,
  ) async {
    // Mirrors the RPC: blank fields keep their stored value.
    config.forEach((key, value) {
      if (value.trim().isNotEmpty) _m.einvoiceConfig[key] = value.trim();
    });
  }

  @override
  Future<void> clearEInvoiceCredentials(String workspaceId) async =>
      _m.einvoiceConfig.clear();
}
