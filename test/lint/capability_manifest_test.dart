// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1634 — the capability page says exactly what the manifest and the
// repository support: every cited evidence path exists at HEAD, no entry
// claims a scope its evidence cannot reach, and the checked-in page and
// release artifact are what the generator writes for this tree.
//
// The validator is also proved able to fail here: the real manifest with
// one evidence reference pointed at a test that does not exist is
// refused by name. A gate that cannot go red is a comment.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/capability_evidence/evidence.dart';
import '../../tool/capability_evidence/render.dart';

Map<String, Object?> _manifest() =>
    (jsonDecode(File(manifestPath).readAsStringSync()) as Map)
        .cast<String, Object?>();

void main() {
  final ctx = Context.load('.');

  test('the manifest is valid against this tree', () {
    expect(validate(_manifest(), ctx), isEmpty);
  });

  test('the page and the release artifact are up to date', () {
    final projection = project(_manifest(), ctx);
    for (final (path, expected) in [
      (pagePath, renderPage(projection)),
      (releasePath, renderRelease(projection)),
    ]) {
      expect(File(path).readAsStringSync(), expected,
          reason: '$path drifted — run `dart run tool/capability_evidence.dart`');
    }
  });

  test('every capability the issue names is there, and the roadmap ones '
      'are roadmap', () {
    final byId = {
      for (final c in _manifest()['capabilities'] as List)
        (c as Map)['id'] as String: c['status'],
    };
    for (final id in [
      'booking', 'membership.allowances', 'statements.shared_expenses',
      'approvals', 'payments.stripe', 'payments.paypal', 'payments.mollie',
      'payments.wero', 'accounting.export', 'einvoice.generate',
      'einvoice.transmit', 'recovery.database_restore', 'demo', //
    ]) {
      expect(byId[id], 'shipped', reason: id);
    }
    for (final id in [
      'recovery.storage_auth', 'mcp.read', 'mcp.write', 'mcp.consent',
      'calendar.interchange', //
    ]) {
      expect(byId[id], 'roadmap', reason: '$id has no delivered evidence');
    }
  });

  test('the validator goes red on a cited test that does not exist', () {
    final m = _manifest();
    final booking = ((m['capabilities'] as List).first as Map)
        .cast<String, Object?>();
    final evidence =
        (booking['evidence'] as List).cast<Map<String, Object?>>();
    evidence.first['ref'] = 'test/features/reservations/imaginary_test.dart';
    expect(
      validate(m, ctx),
      ['booking: evidence `test/features/reservations/imaginary_test.dart` '
          'does not exist or is not a recognised reference'],
    );
  });
}
