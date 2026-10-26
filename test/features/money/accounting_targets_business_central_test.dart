// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2374 — the Business Central targets: one per localisation, each an API
// target delivered as documents and connected with the client credentials
// of the company's Entra application, offered in its own country only; the
// adapter knows each target by the descriptor's country, the journals by
// the app's codes, the company and credential by the shapes the app
// composes, and the customer number by the descriptor's bound; the runner
// dispatches every localisation to the adapter.
import 'dart:io';

import 'package:deskilo/features/money/domain/accounting_capability.dart';
import 'package:deskilo/features/money/domain/accounting_connection.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/domain/business_central_connection.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:flutter_test/flutter_test.dart';

const _ids = {
  'business_central_de',
  'business_central_fr',
  'business_central_ch',
  'business_central_gb',
  'business_central_us',
  'business_central_ca',
};

const _adapterPath =
    'supabase/functions/_shared/accounting_business_central.ts';

List<AccountingTarget> get _bc => [
  for (final t in accountingTargets)
    if (t.id.startsWith('business_central_')) t,
];

/// The `key: "value"` rows of the adapter's table [name].
Map<String, String> _table(String adapter, String name, String row) {
  final table = adapter.substring(adapter.indexOf('$name: Record'));
  return {
    for (final m in RegExp(
      row,
      multiLine: true,
    ).allMatches(table.substring(0, table.indexOf('};'))))
      m[1]!: m[2]!,
  };
}

const _clientId = '0f1e2d3c-4b5a-4968-8776-655443322110';
const _company = '7c3e8a1f-2b4d-4e6a-9f10-1a2b3c4d5e6f';

EntraConnection _of({
  String clientId = _clientId,
  String secret = 'Xy8Q~secret',
  String? tenant = 'contoso.onmicrosoft.com',
  String? environment = 'Sandbox_DE',
  String? company = _company,
}) => EntraConnection.of(
  clientId: clientId,
  secret: secret,
  tenant: tenant,
  environment: environment,
  company: company,
);

void main() {
  test('the six localisations are API targets that take documents, '
      'connected with an Entra application, implemented against the named '
      'API', () {
    expect(_bc.map((t) => t.id).toSet(), _ids);
    for (final t in _bc) {
      expect(t.transport, AccountingTransport.api, reason: t.id);
      expect(t.payload, AccountingPayload.documents, reason: t.id);
      expect(t.format, isNull, reason: t.id);
      expect(t.connectsBy, {AccountingAuthKind.token}, reason: t.id);
      expect(t.tokenShape, AccountingTokenShape.entraClientCredentials);
      expect(t.runnerDelivers, isTrue, reason: t.id);
      expect(t.edition, contains('localisation'), reason: t.id);
      expect(t.limits.requestsPerMinute, 600, reason: t.id);
      expect(t.capability.state, QualificationState.implemented, reason: t.id);
      expect(t.capability.specification, contains('Business Central API v2.0'));
      expect(t.capability.obligations, {Obligation.targetAcceptance});
      expect(
        t.operations,
        isNot(contains(AccountingOperation.attachment)),
        reason: 'no PDF is attached yet',
      );
    }
  });

  test('each localisation is offered in its own country only', () {
    String? bcIn(String country) =>
        targetsFor(country)
            .where((t) => t.id.startsWith('business_central_'))
            .singleOrNull
            ?.id;
    for (final c in ['DE', 'FR', 'CH', 'GB', 'US', 'CA']) {
      expect(bcIn(c), 'business_central_${c.toLowerCase()}', reason: c);
    }
    expect(bcIn('IT'), isNull);
    expect(bcIn('ES'), isNull);
    expect(bcIn('AT'), isNull);
  });

  test('the adapter knows each localisation by the descriptor\'s country '
      'and each journal by the app\'s code', () {
    final adapter = File(_adapterPath).readAsStringSync();
    expect(
      _table(adapter, 'COMPANY_COUNTRIES', r'^  ([a-z_]+): "([A-Z]{2})",'),
      {for (final t in _bc) t.id: t.countries.single},
    );
    expect(_table(adapter, 'JOURNAL_CODES', r'^  ([a-z]+): "([A-Z]+)",'), {
      for (final j in PostingJournal.values) j.name: j.code,
    });
  });

  test('the adapter reads the company and the credential in the shapes the '
      'app composes, and keeps the descriptor\'s customer number', () {
    final adapter = File(_adapterPath).readAsStringSync();
    final address = RegExp(r'COMPANY_ADDRESS = /(.+)/;')
        .firstMatch(adapter)![1];
    expect(address, entraCompanyAddressPattern);
    expect(
      RegExp(r'CREDENTIAL_SEPARATOR = "(.)";').firstMatch(adapter)![1],
      entraCredentialSeparator,
    );
    final party = RegExp(r'PARTY_NUMBER_LENGTH = (\d+);')
        .firstMatch(adapter)![1];
    for (final t in _bc) {
      expect(t.customerIdRule.maxLength, int.parse(party!), reason: t.id);
    }
  });

  test('the runner dispatches every localisation to the adapter', () {
    final runner = File('supabase/functions/accounting-connect/deliver.ts')
        .readAsStringSync();
    final dispatched = {
      for (final m in RegExp(
        r'^  (business_central_[a-z]+): businessCentral,$',
        multiLine: true,
      ).allMatches(runner))
        m[1]!,
    };
    expect(dispatched, _ids);
  });

  group('a connection is composed', () {
    test('from the client id and secret, and the company by tenant, '
        'environment and id', () {
      final c = _of() as EntraValid;
      expect(c.token, '$_clientId${entraCredentialSeparator}Xy8Q~secret');
      expect(c.remoteTenantId, 'contoso.onmicrosoft.com/Sandbox_DE/$_company');
      expect(
        RegExp(entraCompanyAddressPattern).hasMatch(c.remoteTenantId!),
        isTrue,
      );
      expect(
        c.token.length,
        inInclusiveRange(accountingTokenLength.min, accountingTokenLength.max),
      );
    });

    test('a replaced secret keeps the company', () {
      final c =
          _of(tenant: null, environment: null, company: null) as EntraValid;
      expect(c.remoteTenantId, isNull);
    });

    test('each field of another form is named, and nothing is composed', () {
      EntraField? invalid(EntraConnection c) =>
          c is EntraInvalid ? c.field : null;
      expect(invalid(_of(clientId: 'my-app')), EntraField.clientId);
      expect(invalid(_of(secret: '  ')), EntraField.secret);
      expect(
        invalid(_of(secret: 'x' * (entraSecretMaxLength + 1))),
        EntraField.secret,
      );
      expect(invalid(_of(tenant: 'contoso/x')), EntraField.tenant);
      expect(invalid(_of(environment: 'Prod uction')), EntraField.environment);
      expect(
        invalid(
          _of(
            environment: 'E' * (entraFieldLength[EntraField.environment]! + 1),
          ),
        ),
        EntraField.environment,
      );
      expect(invalid(_of(company: 'CRONUS')), EntraField.company);
    });
  });
}
