// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1634 — a throwaway repository for the capability-evidence tests: one
// Dart test, one pgTAP file, one Stripe stub script, one component, one
// dated provider record, and a Context that knows one feature and two
// quality-report rows.
import 'dart:io';

import '../../tool/capability_evidence/evidence.dart';

late Directory fixtureDir;
late Context fixtureContext;

void fixtureFile(String path, String body) => File('${fixtureDir.path}/$path')
  ..parent.createSync(recursive: true)
  ..writeAsStringSync(body);

void createFixture() {
  fixtureDir = Directory.systemTemp.createTempSync('capability_evidence');
  fixtureFile('test/a_test.dart', 'void main() {}');
  fixtureFile('supabase/tests/database/01_x.sql', 'select 1;');
  fixtureFile('scripts/stub_check.sh', '# a stripe stub');
  fixtureFile('lib/features/x/a.dart', 'class A {}');
  fixtureFile('README.md', 'unrelated');
  fixtureFile('docs/product/evidence/stripe.md',
      'scope: provider_sandbox\ncapability: pay.stripe\n');
  fixtureContext = Context(
    root: fixtureDir.path,
    features: {'flagA'},
    ciJobs: {'Tests': 'code', 'Restore drill': 'database'},
  );
}

void deleteFixture() => fixtureDir.deleteSync(recursive: true);

Map<String, Object?> entry({
  String id = 'pay.stripe',
  String status = 'shipped',
  List<Object?> evidence = const [
    {'scope': 'unit', 'ref': 'test/a_test.dart'},
  ],
  Map<String, Object?> extra = const {},
}) =>
    {
      'id': id,
      'outcome': 'o',
      'status': status,
      'features': ['flagA'],
      'component': ['lib/features/x/'],
      'prerequisites': 'p',
      'limitations': 'l',
      'evidence': evidence,
      ...extra,
    };

Map<String, Object?> manifest(List<Map<String, Object?>> caps) =>
    {'schema_version': 1, 'version': 'v', 'capabilities': caps};

/// A dated provider-sandbox record against [fingerprint], with a private
/// block that must never be projected.
Map<String, Object?> record(String fingerprint, {String outcome = 'pass'}) => {
      'scope': 'provider_sandbox',
      'ref': 'docs/product/evidence/stripe.md',
      'sha': 'abc1234',
      'date': '2026-09-25',
      'outcome': outcome,
      'fingerprint': fingerprint,
      'private': {'report': 'https://dashboard.example/private'},
    };
