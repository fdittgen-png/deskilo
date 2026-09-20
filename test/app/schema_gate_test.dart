// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1312 — the app refuses a server whose schema is older than it needs,
// and ONLY that: a current or newer server boots as before, and a check
// that could not be asked (offline) never blocks. Signed out or signed in,
// a behind server lands on the update screen, and the Server screen stays
// reachable from it so the device can be pointed elsewhere.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/schema_gate.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

Future<void> _boot(WidgetTester tester, FixedSchemaVersionSource source,
    {bool signedIn = true}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        schemaVersion: source,
        auth: signedIn ? null : FakeAuthRepository(),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

const _update = ValueKey('schema-update');

void main() {
  group('schemaGateRedirect', () {
    test('behind sends an ordinary route to the update screen', () {
      expect(schemaGateRedirect(SchemaCompatibility.behind, '/reserve'),
          kSchemaUpdateRoute);
    });
    test('behind leaves the way out open', () {
      for (final open in ['/server', '/server/new-instance', '/help',
          '/privacy', kSchemaUpdateRoute]) {
        expect(schemaGateRedirect(SchemaCompatibility.behind, open), isNull,
            reason: open);
      }
    });
    test('anything else gates nothing, and leaves the update screen', () {
      for (final c in [null, ...SchemaCompatibility.values]) {
        if (c == SchemaCompatibility.behind) continue;
        expect(schemaGateRedirect(c, '/reserve'), isNull);
        expect(schemaGateRedirect(c, kSchemaUpdateRoute), '/reserve');
      }
    });
  });

  testWidgets('a server one version behind lands on the update screen',
      (tester) async {
    await _boot(tester, const FixedSchemaVersionSource(requiredSchemaVersion - 1));
    expect(find.byKey(_update), findsOneWidget);
    expect(find.text('This server needs an update'), findsOneWidget);
    expect(find.textContaining('version $requiredSchemaVersion'), findsOneWidget);
  });

  testWidgets('a server with no marker is behind too, even signed out',
      (tester) async {
    await _boot(tester, const FixedSchemaVersionSource(null), signedIn: false);
    expect(find.byKey(_update), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('an equal server boots normally', (tester) async {
    await _boot(tester, const FixedSchemaVersionSource(requiredSchemaVersion));
    expect(find.byKey(_update), findsNothing);
    expect(find.text('Messages'), findsWidgets);
  });

  testWidgets('a newer server boots normally', (tester) async {
    await _boot(tester, const FixedSchemaVersionSource(requiredSchemaVersion + 1));
    expect(find.byKey(_update), findsNothing);
    expect(find.text('Messages'), findsWidgets);
  });

  testWidgets('an unanswered check never blocks', (tester) async {
    await _boot(tester, const FixedSchemaVersionSource(null, unavailable: true));
    expect(find.byKey(_update), findsNothing);
    expect(find.text('Messages'), findsWidgets);
  });

  testWidgets('the Server screen stays reachable from the update screen',
      (tester) async {
    await _boot(tester, const FixedSchemaVersionSource(requiredSchemaVersion - 1));
    await tester.tap(find.byKey(const ValueKey('schema-update-server')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backend-status')), findsOneWidget);
  });
}
