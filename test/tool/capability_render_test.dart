// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1634 — the projection is deterministic and honest: two runs are
// byte-identical, a repository-local reference is `gated`, a dated
// record is `recorded` only while its component fingerprint holds and
// `stale` once the component moves, a skipped record is `unverified`,
// and the private block never reaches the release artifact or the page.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/capability_evidence/evidence.dart';
import '../../tool/capability_evidence/render.dart';
import 'capability_fixture.dart';

String _scope(Map<String, Object?> cap, String scope) {
  final p = project(manifest([cap]), fixtureContext);
  final c = (p['capabilities'] as List).first as Map;
  return (c['scopes'] as Map)[scope] as String;
}

void main() {
  setUp(createFixture);
  tearDown(deleteFixture);

  test('two projections of one tree are byte-identical', () {
    final m = manifest([entry()]);
    expect(validate(m, fixtureContext), isEmpty);
    expect(renderRelease(project(m, fixtureContext)),
        renderRelease(project(m, fixtureContext)));
    expect(renderPage(project(m, fixtureContext)),
        renderPage(project(m, fixtureContext)));
  });

  test('the page says gated for a local reference and a dash for nothing', () {
    final page = renderPage(project(manifest([entry()]), fixtureContext));
    expect(page, contains('| [pay.stripe](#paystripe) | shipped | gated | — | — | — | — |'));
    expect(page, contains('- `unit` · **gated** · [`test/a_test.dart`](../../test/a_test.dart)'));
    expect(_scope(entry(), 'unit'), 'gated');
    expect(_scope(entry(), 'local_integration'), 'unverified');
  });

  test('a record stands while its component stands, goes stale when the '
      'component moves, and is unmoved by an unrelated edit', () {
    final fp = fingerprint(['lib/features/x/'], fixtureContext);
    final cap = entry(evidence: [record(fp)], extra: {'provider': 'stripe'});
    expect(validate(manifest([cap]), fixtureContext), isEmpty);
    expect(_scope(cap, 'provider_sandbox'), 'recorded');
    fixtureFile('README.md', 'still unrelated');
    expect(fingerprint(['lib/features/x/'], fixtureContext), fp);
    expect(_scope(cap, 'provider_sandbox'), 'recorded');
    final page = renderPage(project(manifest([cap]), fixtureContext));
    expect(page, contains('| recorded 2026-09-25 |'));
    expect(page, contains('sha `abc1234` · 2026-09-25 · pass'));
    fixtureFile('lib/features/x/a.dart', 'class A { int v = 2; }');
    expect(fingerprint(['lib/features/x/'], fixtureContext), isNot(fp));
    expect(_scope(cap, 'provider_sandbox'), 'stale');
    expect(renderPage(project(manifest([cap]), fixtureContext)), contains('| stale |'));
  });

  test('a skipped record is unverified, never a pass', () {
    final fp = fingerprint(['lib/features/x/'], fixtureContext);
    final cap = entry(evidence: [record(fp, outcome: 'skipped')], extra: {'provider': 'stripe'});
    expect(validate(manifest([cap]), fixtureContext), isEmpty);
    expect(_scope(cap, 'provider_sandbox'), 'unverified');
  });

  test('the private block never reaches the projection', () {
    final fp = fingerprint(['lib/features/x/'], fixtureContext);
    final cap = entry(evidence: [record(fp)], extra: {'provider': 'stripe'});
    final p = project(manifest([cap]), fixtureContext);
    expect(renderRelease(p), isNot(contains('dashboard.example')));
    expect(renderPage(p), isNot(contains('dashboard.example')));
  });

  test('an edit to a component leaves the committed outputs alone unless a '
      'standing flips (#2121)', () {
    String outputs(Map<String, Object?> cap) {
      final projection = project(manifest([cap]), fixtureContext);
      return renderPage(projection) + renderRelease(projection);
    }

    final fp = fingerprint(['lib/features/x/'], fixtureContext);
    final gatedOnly = entry();
    final recorded =
        entry(evidence: [record(fp)], extra: {'provider': 'stripe'});
    final gatedBefore = outputs(gatedOnly);
    final recordedBefore = outputs(recorded);
    expect(gatedBefore, isNot(contains(fp)),
        reason: 'the fingerprint moves with every edit; committed, it put '
            'every open pull request in conflict');

    fixtureFile('lib/features/x/a.dart', 'class A { int v = 3; }');
    expect(fingerprint(['lib/features/x/'], fixtureContext), isNot(fp));
    expect(outputs(gatedOnly), gatedBefore,
        reason: 'nothing the page says depends on the component bytes');
    // The negative control: the guarantee the fingerprint exists for still
    // fires — a recorded record goes stale and the page says so.
    expect(outputs(recorded), isNot(recordedBefore));
    expect(outputs(recorded), contains('| stale |'));
    expect(currentFingerprints(manifest([recorded]), fixtureContext),
        {'pay.stripe': fingerprint(['lib/features/x/'], fixtureContext)});
  });
}
