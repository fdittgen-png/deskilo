// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3882 — a named connector has fields for its test environment, saved with
// the `_uat` suffix the function reads; a sandbox address typed in the
// production field would be sent, and recorded, as production.
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/einvoice_providers.dart';
import 'package:deskilo/features/money/presentation/widgets/einvoice_provider_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey('einvoice-provider-$key')),
  matching: find.byType(EditableText),
);

void main() {
  testWidgets('a Peppol sandbox configuration is sent with the _uat keys and '
      'leaves the production ones alone', (tester) async {
    final form = EInvoiceProviderForm()..provider = 'peppol';
    addTearDown(form.dispose);
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: EInvoiceProviderSection(
            form: form,
            secretsSet: const [],
            onChanged: (_) {},
          ),
        ),
      ),
      overrides: standardTestOverrides(),
      size: const Size(600, 1600),
    );

    for (final field in eInvoiceProviderFields['peppol']!) {
      expect(find.byKey(ValueKey('einvoice-provider-$field')), findsOneWidget);
      expect(
        find.byKey(ValueKey('einvoice-provider-${field}_uat')),
        findsOneWidget,
        reason: '$field has a test twin',
      );
    }
    // The documented sandbox address is offered on the test twin only.
    expect(find.text(eInvoiceSandboxDefaults['peppol']!['base_url']!),
        findsOneWidget);
    // Obscured like the production secret.
    expect(
      tester.widget<EditableText>(_field('api_key_uat')).obscureText,
      isTrue,
    );
    expect(
      tester.widget<EditableText>(_field('base_url_uat')).obscureText,
      isFalse,
    );

    await tester.enterText(_field('base_url_uat'), ' https://sandbox.example ');
    await tester.enterText(_field('api_key_uat'), 'test-key');
    await tester.enterText(_field('legal_entity_id_uat'), '77');

    expect(form.values(), {
      'provider': 'peppol',
      'base_url': '',
      'api_key': '',
      'legal_entity_id': '',
      'base_url_uat': 'https://sandbox.example',
      'api_key_uat': 'test-key',
      'legal_entity_id_uat': '77',
    });
  });

  test('the stored test fields come back; a test secret never does', () {
    final form = EInvoiceProviderForm()
      ..load(
        const EInvoiceProviderStatus(
          configured: true,
          provider: 'peppol',
          fields: {
            'base_url': 'https://prod.example',
            'base_url_uat': 'https://sandbox.example',
            'legal_entity_id_uat': '77',
          },
          secretsSet: ['api_key', 'api_key_uat'],
        ),
      )
      ..controllerFor('api_key_uat').text = 'typed';
    expect(form.controllerFor('base_url').text, 'https://prod.example');
    expect(form.controllerFor('base_url_uat').text, 'https://sandbox.example');
    expect(form.controllerFor('legal_entity_id_uat').text, '77');
    form.clearSecrets();
    expect(form.controllerFor('api_key_uat').text, isEmpty);
    form.dispose();
  });

  test('the generic connector sends no test twin of its own', () {
    final form = EInvoiceProviderForm()..provider = 'generic';
    expect(form.values(), {'provider': 'generic'});
    form.dispose();
  });
}
