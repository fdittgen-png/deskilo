// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1832 A — the connected-servers screen shows each server's OWN state and
// the one recovery it leads to: a usable server says so, an expired one
// offers "Sign in again", a changed one "Verify again" (no retry of its
// actions), one that is down "Try again" — and the others stay usable.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/features/directory/presentation/connection_outcome_text.dart';
import 'package:deskilo/features/directory/presentation/connections_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ConnectedInstallation _row(String host) => ConnectedInstallation(
  endpoint: BackendEndpoint('https://$host.example', 'sb_publishable_$host'),
  account: '$host-user',
  installationId: 'i-$host',
);

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('each server shows its own state and its own recovery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final rows = [_row('ok'), _row('old'), _row('moved'), _row('down')];
    final registry = FakeConnectedInstallations()
      ..sources.addAll(rows)
      ..health.addAll({
        'https://old.example': ConnectionFailure(
          'https://old.example',
          ConnectionFailureReason.expired,
        ),
        'https://moved.example': ConnectionFailure(
          'https://moved.example',
          ConnectionFailureReason.changedIdentity,
        ),
        'https://down.example': ConnectionFailure(
          'https://down.example',
          ConnectionFailureReason.unavailable,
        ),
      });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectedInstallationsProvider.overrideWith((ref) => registry),
          connectedSourcesProvider.overrideWith((ref) async => rows),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ConnectionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder inRow(String host, Finder f) => find.descendant(
      of: _key('connection-https://$host.example'),
      matching: f,
    );

    expect(inRow('ok', _key('connection-status-usable')), findsOneWidget);
    expect(
      inRow('ok', find.byType(TextButton)),
      findsNothing,
      reason: 'a usable server offers no recovery',
    );

    expect(inRow('old', _key('connection-status-expired')), findsOneWidget);
    expect(inRow('old', _key('connection-action-signin')), findsOneWidget);

    expect(
      inRow('moved', _key('connection-status-changedIdentity')),
      findsOneWidget,
    );
    expect(inRow('moved', _key('connection-action-verify')), findsOneWidget);
    expect(
      inRow('moved', _key('connection-action-retry')),
      findsNothing,
      reason: 'a changed server is re-verified, never silently retried',
    );

    expect(
      inRow('down', _key('connection-status-unavailable')),
      findsOneWidget,
    );
    expect(inRow('down', _key('connection-action-retry')), findsOneWidget);

    // Sign in again opens the connect dialog for THAT server, prefilled.
    await tester.tap(inRow('old', _key('connection-action-signin')));
    await tester.pumpAndSettle();
    expect(find.text('https://old.example'), findsWidgets);
    expect(find.text('sb_publishable_old'), findsOneWidget);
  });

  testWidgets('a server that came back is usable after Try again', (
    tester,
  ) async {
    final row = _row('down');
    final registry = FakeConnectedInstallations()
      ..sources.add(row)
      ..health['https://down.example'] = ConnectionFailure(
        'https://down.example',
        ConnectionFailureReason.unavailable,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectedInstallationsProvider.overrideWith((ref) => registry),
          connectedSourcesProvider.overrideWith((ref) async => [row]),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ConnectionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    registry.health['https://down.example'] = null;
    await tester.tap(_key('connection-action-retry'));
    await tester.pumpAndSettle();
    expect(_key('connection-status-usable'), findsOneWidget);
  });

  test('every outcome has a sentence and exactly one recovery', () {
    for (final reason in ConnectionFailureReason.values) {
      final text = connectionFailureText(null, ConnectionFailure('s', reason));
      expect(text, isNotEmpty, reason: reason.name);
      connectionRecovery(reason); // total: a switch the compiler checks
    }
    expect(
      connectionFailureText(
        null,
        ConnectionFailure(
          's',
          ConnectionFailureReason.unavailable,
          afterSend: true,
        ),
      ),
      contains('may have been applied'),
      reason: 'a dropped response is an unknown outcome, never "failed"',
    );
    expect(
      connectionRecovery(ConnectionFailureReason.changedIdentity),
      ConnectionRecovery.verify,
    );
    expect(
      connectionRecovery(ConnectionFailureReason.unsupported),
      ConnectionRecovery.none,
    );
  });
}
