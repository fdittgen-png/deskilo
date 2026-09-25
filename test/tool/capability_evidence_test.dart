// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1634 — the capability manifest can only claim what its evidence
// supports, and the validator refuses everything else with a named
// reason: a reference that does not exist, a scope above the ceiling of
// its reference, a stub validating a provider it never names, a roadmap
// entry carrying evidence, an incomplete dated record, a secret in
// public text.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/capability_evidence/evidence.dart';
import 'capability_fixture.dart';

List<String> _problems(Map<String, Object?> cap) =>
    validate(manifest([cap]), fixtureContext);

void main() {
  setUp(createFixture);
  tearDown(deleteFixture);

  test('a well-formed entry is valid', () {
    expect(_problems(entry()), isEmpty);
  });

  test('schema, duplicate id, unknown feature, bad paths and unknown scope', () {
    expect(validate({'schema_version': 2, 'capabilities': []}, fixtureContext),
        containsAll(['schema_version must be 1', 'version must be a string']));
    expect(validate(manifest([entry(), entry()]), fixtureContext),
        contains('pay.stripe: duplicate id'));
    expect(_problems(entry(extra: {'features': ['nope']})),
        contains('pay.stripe: unknown feature `nope`'));
    expect(_problems(entry(extra: {'component': ['lib/gone/']})),
        contains('pay.stripe: component path `lib/gone/` does not exist'));
    expect(
      _problems(entry(evidence: [{'scope': 'unit', 'ref': 'test/gone_test.dart'}])),
      contains('pay.stripe: evidence `test/gone_test.dart` does not exist or is '
          'not a recognised reference'),
    );
    expect(_problems(entry(evidence: [{'scope': 'live', 'ref': 'test/a_test.dart'}])),
        contains(startsWith('pay.stripe: evidence needs a ref and a scope')));
    expect(_problems(entry(evidence: [{'scope': 'unit', 'ref': 'ci:Nope'}])),
        contains(startsWith('pay.stripe: evidence `ci:Nope` does not exist')));
  });

  test('a reference supports its ceiling and nothing above it', () {
    final ctx = fixtureContext;
    expect(ceiling('test/a_test.dart', ctx), 'unit');
    expect(ceiling('supabase/tests/database/01_x.sql', ctx), 'local_integration');
    expect(ceiling('scripts/stub_check.sh', ctx), 'local_integration');
    expect(ceiling('ci:Tests', ctx), 'unit');
    expect(ceiling('ci:Restore drill', ctx), 'local_integration');
    expect(ceiling('docs/product/evidence/stripe.md', ctx), 'provider_sandbox');
    expect(ceiling('README.md', ctx), isNull, reason: 'prose is not evidence');
    expect(
      _problems(entry(evidence: [{'scope': 'provider_sandbox', 'ref': 'scripts/stub_check.sh'}])),
      contains('pay.stripe: `scripts/stub_check.sh` supports at most '
          '`local_integration`, not `provider_sandbox`'),
    );
    expect(
      _problems(entry(evidence: [{'scope': 'local_integration', 'ref': 'test/a_test.dart'}])),
      contains(startsWith('pay.stripe: `test/a_test.dart` supports at most `unit`')),
    );
  });

  test('a Stripe stub cannot validate PayPal', () {
    final stub = {'scope': 'local_integration', 'ref': 'scripts/stub_check.sh'};
    expect(_problems(entry(evidence: [stub], extra: {'provider': 'stripe'})), isEmpty);
    expect(
      _problems(entry(id: 'pay.paypal', evidence: [stub], extra: {'provider': 'paypal'})),
      contains('pay.paypal: `scripts/stub_check.sh` says nothing about `paypal` '
          'and cannot validate it'),
    );
  });

  test('roadmap carries no evidence and names its issues; shipped needs both', () {
    expect(_problems(entry(status: 'roadmap', extra: {'issues': [1607]})),
        contains('pay.stripe: roadmap entries carry no evidence'));
    expect(_problems(entry(status: 'roadmap', evidence: [])),
        contains('pay.stripe: roadmap entries name the issues that deliver them'));
    expect(_problems(entry(evidence: [])), contains('pay.stripe: shipped without evidence'));
    expect(_problems(entry(status: 'live')),
        contains(startsWith('pay.stripe: status must be one of')));
  });

  test('a dated record is complete or invalid', () {
    const ref = 'docs/product/evidence/stripe.md';
    expect(_problems(entry(evidence: [record('0123456789ab')], extra: {'provider': 'stripe'})), isEmpty);
    expect(_problems(entry(evidence: [{'scope': 'provider_sandbox', 'ref': ref}])), containsAll([
      'pay.stripe: `$ref` needs the tested sha',
      'pay.stripe: `$ref` needs a date',
      startsWith('pay.stripe: `$ref` outcome must be'),
      'pay.stripe: `$ref` needs the component fingerprint it was taken against',
    ]));
  });

  test('secrets and foreign links never reach the public text', () {
    for (final s in ['sk_live_abc', 'whsec_x', 'owner@example.org', 'https://x.test/r']) {
      expect(_problems(entry(extra: {'limitations': 'see $s'})),
          contains(startsWith('pay.stripe: public text carries')), reason: s);
    }
    expect(_problems(entry(extra: {'limitations': 'see https://github.com/fdittgen-png/deskilo/issues/1'})), isEmpty);
    expect(_problems(entry(evidence: [{'scope': 'unit', 'ref': 'test/a_test.dart', 'url': 'x'}])),
        contains('pay.stripe: unknown evidence key `url`'));
  });
}
