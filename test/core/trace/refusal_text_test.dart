// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1305 S2 — a refusal is not a fault, and every guarded action says which
// refusal it met.
//
// Four families any screen can hit — no permission, no session, already
// decided by someone else, changed in the meantime — each get one
// sentence at runGuarded, the single point every guarded action passes
// through. A failure outside them keeps its caller's own text: a
// mis-classified fault is worse than a generic one.
//
// The substrings are server sentences, so they are PINNED: each must still
// be raised by some migration. A refusal reworded in SQL would otherwise
// drop silently back to "Something went wrong".
import 'dart:io';

import 'package:deskilo/core/trace/guarded.dart';
import 'package:deskilo/core/trace/refusal_text.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _generic = 'Something went wrong. Please try again.';

Future<void> _pumpGuarded(WidgetTester tester, Object thrown) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => runGuarded(
              context,
              domain: 'test',
              message: 'thing failed',
              errorText: _generic,
              action: () async => throw thrown,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

PostgrestException _pg(String message, {String? code}) =>
    PostgrestException(message: message, code: code);

void main() {
  group('the families', () {
    test('a permission refusal, in several server wordings', () {
      for (final m in [
        'not an admin of this workspace',
        'only owners may invite admins',
        'only workspace settings managers may change the wording',
        'new row violates row-level security policy for table "fee_bands"',
      ]) {
        expect(knownRefusalOf(_pg(m)), KnownRefusal.permission, reason: m);
      }
      expect(knownRefusalOf(_pg('permission denied for table x', code: '42501')),
          KnownRefusal.permission);
    });

    test('a session that ended', () {
      expect(knownRefusalOf(_pg('not authenticated')), KnownRefusal.session);
      expect(knownRefusalOf(const AuthException('JWT expired')),
          KnownRefusal.session);
    });

    test('already decided, and changed meanwhile', () {
      expect(knownRefusalOf(_pg('already decided')), KnownRefusal.alreadyDecided);
      expect(knownRefusalOf(_pg('you already decided this event')),
          KnownRefusal.alreadyDecided);
      expect(knownRefusalOf(_pg('invoice is voided')),
          KnownRefusal.changedMeanwhile);
    });

    test('anything else is not a known refusal', () {
      expect(knownRefusalOf(_pg('duplicate key value')), isNull);
      expect(knownRefusalOf(StateError('boom')), isNull);
      expect(knownRefusalText(null, StateError('boom')), isNull);
    });
  });

  testWidgets('a guarded action refused for a permission says so instead of '
      '"try again"', (tester) async {
    await _pumpGuarded(tester, _pg('not an admin of this workspace'));
    expect(find.textContaining('do not have the permission'), findsOneWidget);
    expect(find.text(_generic), findsNothing);
  });

  testWidgets('an unknown failure keeps its caller\'s text', (tester) async {
    await _pumpGuarded(tester, _pg('duplicate key value violates unique'));
    expect(find.text(_generic), findsOneWidget);
  });

  test('every pinned substring is still raised by a migration', () {
    final sql = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .map((f) => f.readAsStringSync().toLowerCase())
        .join('\n');
    // Postgres raises this one itself; no migration writes it.
    const postgresOwn = {'violates row-level security policy', 'jwt expired'};
    final missing = [
      for (final s in [
        ...permissionRefusalSubstrings,
        ...sessionRefusalSubstrings,
        ...alreadyDecidedSubstrings,
        ...changedMeanwhileSubstrings,
      ])
        if (!postgresOwn.contains(s) && !sql.contains(s)) s,
    ];
    expect(missing, isEmpty,
        reason: 'no migration raises these any more — reword the substring '
            'to match the server, or remove it:\n${missing.join('\n')}');
  });
}
