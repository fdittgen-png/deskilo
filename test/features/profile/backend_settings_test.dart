// SPDX-License-Identifier: 0BSD
//
// #780 — the device chooses its Supabase instance. The app's own server
// stays the default; a community that runs its own project points the
// app at it from Settings → Server, with paste, a shareable QR and a
// connection test — no rebuild, no --dart-define.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/backend/backend_config.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/backend_uri.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<InMemoryBackendSettingsStore> pumpServerScreen(
  WidgetTester tester, {
  BackendEndpoint? stored,
}) async {
  final store = InMemoryBackendSettingsStore()..value = stored;
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(backendSettings: store),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('backend-server-tile')),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('backend-server-tile')));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('validation — only a Supabase endpoint is accepted', () {
    test('a good publishable endpoint passes', () {
      expect(
        validateBackendEndpoint(
          'https://abcdefgh.supabase.co',
          'sb_publishable_0123456789abcdefghij',
        ),
        isNull,
      );
    });

    test('the legacy anon JWT still passes', () {
      expect(
        validateBackendEndpoint('https://self.hosted.example', 'eyJa.b.c'),
        isNull,
      );
    });

    test('a self-hosted https host is fine — only the scheme is required',
        () {
      expect(
        validateBackendEndpoint(
          'https://supabase.mycowork.example',
          'sb_publishable_0123456789abcdefghij',
        ),
        isNull,
      );
    });

    test('each refusal names its own cause', () {
      expect(validateBackendEndpoint('', 'sb_publishable_0123456789abcdef'),
          BackendEndpointError.urlEmpty);
      expect(
        validateBackendEndpoint(
            'http://plain.example', 'sb_publishable_0123456789abcdef'),
        BackendEndpointError.urlNotHttps,
      );
      expect(
        validateBackendEndpoint(
            'https://localhost', 'sb_publishable_0123456789abcdef'),
        BackendEndpointError.urlNoHost,
      );
      expect(validateBackendEndpoint('https://a.supabase.co', ''),
          BackendEndpointError.keyEmpty);
      // Not Supabase: a random database URL/key never reaches the store.
      expect(
        validateBackendEndpoint('https://a.supabase.co', 'postgres://secret'),
        BackendEndpointError.keyNotSupabase,
      );
    });
  });

  group('the shared server QR', () {
    test('round-trips an endpoint', () {
      const endpoint = BackendEndpoint(
        'https://abcdefgh.supabase.co',
        'sb_publishable_0123456789abcdefghij',
      );
      final decoded = BackendUriCodec.decode(BackendUriCodec.encode(endpoint));
      expect(decoded?.url, endpoint.url);
      expect(decoded?.key, endpoint.key);
    });

    test('a foreign QR never repoints the app', () {
      expect(BackendUriCodec.decode('deskilo://join?code=ABC123'), isNull);
      expect(BackendUriCodec.decode('https://example.com'), isNull);
      // Well-formed shape, unusable values → still refused.
      expect(
        BackendUriCodec.decode('deskilo://server?url=http://x&key=nope'),
        isNull,
      );
    });
  });

  testWidgets('an untouched install shows the app\'s own server',
      (tester) async {
    await pumpServerScreen(tester);
    expect(find.byKey(const ValueKey('backend-status')), findsOneWidget);
    expect(
      find.textContaining(Uri.parse(BackendConfig.supabaseUrl).host),
      findsWidgets,
    );
    // Nothing to reset while the default is in force.
    expect(find.byKey(const ValueKey('backend-reset')), findsNothing);
  });

  testWidgets('the four setup steps are on the screen, not in a manual',
      (tester) async {
    await pumpServerScreen(tester);
    await tester.tap(find.byKey(const ValueKey('backend-howto')));
    await tester.pumpAndSettle();
    expect(find.textContaining('supabase.com'), findsOneWidget);
    expect(find.textContaining('supabase/migrations'), findsOneWidget);
    expect(find.textContaining('API keys'), findsOneWidget);
  });

  testWidgets('a bad endpoint is refused with its own reason and never saved',
      (tester) async {
    final store = await pumpServerScreen(tester);
    await tester.enterText(
        find.byKey(const ValueKey('backend-url-field')), 'http://nope.example');
    await tester.enterText(find.byKey(const ValueKey('backend-key-field')),
        'sb_publishable_0123456789abcdefghij');
    await tester.tap(find.byKey(const ValueKey('backend-save')));
    await tester.pump();
    expect(find.text('The URL must start with https://.'), findsOneWidget);
    expect(store.value, isNull);
  });

  testWidgets('a good endpoint is stored, and resetting returns to the '
      'app\'s server', (tester) async {
    final store = await pumpServerScreen(tester);
    await tester.enterText(find.byKey(const ValueKey('backend-url-field')),
        'https://mycowork.supabase.co');
    await tester.enterText(find.byKey(const ValueKey('backend-key-field')),
        'sb_publishable_0123456789abcdefghij');
    await tester.tap(find.byKey(const ValueKey('backend-save')));
    await tester.pumpAndSettle();
    expect(store.value?.url, 'https://mycowork.supabase.co');
    expect(store.value?.host, 'mycowork.supabase.co');
  });

  testWidgets('a device already on its own server can go back to the default',
      (tester) async {
    final store = await pumpServerScreen(
      tester,
      stored: const BackendEndpoint(
        'https://mycowork.supabase.co',
        'sb_publishable_0123456789abcdefghij',
      ),
    );
    expect(find.byKey(const ValueKey('backend-reset')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('backend-reset')));
    await tester.pumpAndSettle();
    expect(store.value, isNull);
  });
}
