// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2343 — "Connect a server" joins a server where the person has an
// account, fills the reference server or a pasted server code instead of
// a typed key, and offers the two other ways: use the server on this
// device to sign up there, or create a new one with the instance wizard.
import 'package:deskilo/core/backend/backend_config.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/backend_uri.dart';
import 'package:deskilo/core/backend/connected_installation_providers.dart';
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/features/directory/presentation/connection_dialog.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _pump(WidgetTester tester, {required bool wizard}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const ConnectionDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        routes: [
          GoRoute(
            path: 'server',
            builder: (context, state) => Text(
              'server ${(state.extra as BackendDescriptor?)?.endpoint.host}',
            ),
            routes: [
              GoRoute(
                path: 'new-instance',
                builder: (context, state) => const Text('wizard'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectedInstallationsProvider.overrideWith(
          (ref) => FakeConnectedInstallations(),
        ),
        enabledFeaturesSyncProvider.overrideWithValue({
          if (wizard) WorkspaceFeature.instanceWizard,
        }),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.tap(_key('open'));
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, String label) => tester
    .widget<TextField>(find.widgetWithText(TextField, label))
    .controller!
    .text;

void main() {
  testWidgets('the reference server fills both fields', (tester) async {
    await _pump(tester, wizard: true);
    await tester.tap(_key('connection-dialog-reference'));
    await tester.pump();
    expect(_field(tester, 'Project URL'), BackendConfig.referenceUrl);
    expect(_field(tester, 'Publishable key'), BackendConfig.referenceKey);
  });

  testWidgets('a pasted server code fills the fields; anything else is said '
      'and changes nothing', (tester) async {
    String? clipboard = 'not a code';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': clipboard} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester, wizard: true);
    await tester.tap(_key('connection-dialog-paste-code'));
    await tester.pumpAndSettle();
    expect(find.text('The clipboard holds no server code.'), findsOneWidget);
    expect(_field(tester, 'Project URL'), isEmpty);

    clipboard = BackendUriCodec.encode(
      const BackendEndpoint(
        'https://mycowork.supabase.co',
        'sb_publishable_0123456789abcdefghij',
      ),
    );
    await tester.tap(_key('connection-dialog-paste-code'));
    await tester.pumpAndSettle();
    expect(_field(tester, 'Project URL'), 'https://mycowork.supabase.co');
  });

  testWidgets('without an account there, the server is used on this device '
      'to sign up — once the fields name a server', (tester) async {
    await _pump(tester, wizard: true);
    final useHere = _key('connection-dialog-use-here');
    await tester.ensureVisible(useHere);
    expect(tester.widget<TextButton>(useHere).onPressed, isNull);
    await tester.tap(_key('connection-dialog-reference'));
    await tester.pump();
    await tester.ensureVisible(useHere);
    await tester.tap(useHere);
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionDialog), findsNothing);
    expect(find.text('server ${referenceEndpoint.host}'), findsOneWidget);
  });

  testWidgets('a new server is created by the wizard, when the wizard is on', (
    tester,
  ) async {
    await _pump(tester, wizard: true);
    final create = _key('connection-dialog-new-instance');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('wizard'), findsOneWidget);
  });

  testWidgets('no wizard, no create button', (tester) async {
    await _pump(tester, wizard: false);
    expect(_key('connection-dialog-new-instance'), findsNothing);
    expect(_key('connection-dialog-use-here'), findsOneWidget);
  });
}
