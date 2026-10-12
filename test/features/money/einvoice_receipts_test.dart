// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — what a national channel answered is kept with the transmission
// and read back as the one fact a person wants (the KSeF number, the
// ANAF download id, the PA status); the configuration form sends the
// connector and only that connector's fields.
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/einvoice_providers.dart';
import 'package:deskilo/features/money/presentation/widgets/einvoice_provider_section.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({Object? receipt, String format = 'ksefFa3'}) => {
  'id': 'tx-1',
  'invoice_id': 'inv-1',
  'status': 'accepted',
  'sent_at': '2026-10-11T10:00:00Z',
  'provider': 'pl_ksef',
  'external_id': 'session/invoice',
  'format': format,
  'receipt': receipt,
  'receipt_at': receipt == null ? null : '2026-10-11T10:05:00Z',
};

void main() {
  group('the transmission keeps what came back', () {
    test('a KSeF number is the receipt a reader sees', () {
      final t = InvoiceTransmission.fromRow(
        _row(receipt: {'ksefNumber': '5260001246-20261011-ABC', 'code': 200}),
      );
      expect(t.id, 'tx-1');
      expect(t.format, 'ksefFa3');
      expect(t.receiptSummary, '5260001246-20261011-ABC');
      expect(t.receiptAt, isNotNull);
    });

    test('an ANAF answer names its download id, a PA its flow status', () {
      expect(
        InvoiceTransmission.fromRow(
          _row(receipt: {'stare': 'ok', 'id_descarcare': '3001'}),
        ).receiptSummary,
        '3001',
      );
      expect(
        InvoiceTransmission.fromRow(_row(receipt: {'flowStatus': 'Deposited'}))
            .receiptSummary,
        'Deposited',
      );
    });

    test('a row from before #2358 has no receipt and no format', () {
      final row = _row()
        ..remove('format')
        ..remove('receipt')
        ..remove('id');
      final t = InvoiceTransmission.fromRow(row);
      expect(t.format, '');
      expect(t.receipt, isEmpty);
      expect(t.receiptSummary, '');
    });
  });

  group('the configuration form', () {
    test('sends the connector and only its own fields', () {
      final form = EInvoiceProviderForm()
        ..provider = 'ro_efactura'
        ..controllerFor('base_url').text =
            ' https://api.anaf.ro/test/FCTEL/rest '
        ..controllerFor('cif').text = 'RO1234567'
        ..controllerFor('access_token').text = 'secret'
        ..controllerFor('api_key').text = 'a peppol key typed earlier';
      expect(form.values(), {
        'provider': 'ro_efactura',
        'base_url': 'https://api.anaf.ro/test/FCTEL/rest',
        'cif': 'RO1234567',
        'access_token': 'secret',
      });
      form.dispose();
    });

    test('loads the connector and never a secret', () {
      final form = EInvoiceProviderForm()
        ..load(
          const EInvoiceProviderStatus(
            configured: true,
            provider: 'peppol',
            fields: {'base_url': 'https://ap.example', 'legal_entity_id': '42'},
            secretsSet: ['api_key'],
          ),
        );
      expect(form.provider, 'peppol');
      expect(form.controllerFor('base_url').text, 'https://ap.example');
      expect(form.controllerFor('api_key').text, isEmpty);
      form.dispose();
    });

    test('an unknown connector from a newer server reads as generic', () {
      final form = EInvoiceProviderForm()
        ..load(const EInvoiceProviderStatus(configured: true, provider: 'x'));
      expect(form.provider, 'generic');
      expect(form.values(), {'provider': 'generic'});
      expect(eInvoiceProviderFields.keys, contains(form.provider));
      form.dispose();
    });
  });
}
