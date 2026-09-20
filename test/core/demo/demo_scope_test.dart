// SPDX-License-Identifier: 0BSD
//
// #1373 — the isolation the Demo environment claims, proven.
//
// ADR 0028 says an external effect in Demo is impossible rather than
// refused: inside the scope there is no Supabase client to reach. These
// tests hold that claim to three checks a reviewer can read — the scope
// resolves every repository to the fixture, a write in Demo leaves the
// live one untouched, and no repository provider the app declares is
// left out of the list.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/schema_version.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/core/push/push_providers.dart';
import 'package:deskilo/core/share/text_sharer.dart';
import 'package:deskilo/core/theme/theme_controller.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the device remembered before a visitor ever tapped "Explore".
const Map<String, Object> _realDevice = {
  'default_workspace_id': 'ws-real',
  'active_workspace_id': 'ws-real',
  'backend_supabase_url': 'https://real.example.test',
  'backend_supabase_key': 'real-key',
  'locale_override': 'fr',
  'theme_mode_override': 'dark',
  'navigation_style': 'menu',
  'shell_bar_hidden': true,
  'default_level_ws-real': 'level-real',
  'default_period_ws-real': 'day',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the scope resolves the repositories to the session fixture, not to '
      'anything that could reach a server', () {
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);

    expect(container.read(workspaceRepositoryProvider), same(fixture.workspaces));
    expect(container.read(clockProvider).now(), fixture.seededAt,
        reason: 'the demo believes it is the instant its fixture was seeded, '
            'so a booking for today does not expire out of it');
  });

  test('a write in Demo lands in the session and nowhere else', () async {
    final live = FakeWorkspaceRepository.withWorkspace();
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);

    await container
        .read(workspaceRepositoryProvider)
        .setWorkspaceBranding('ws-1', {'seed_color': '#1F3A5F'});

    expect(fixture.workspaces.brandings['ws-1'], {'seed_color': '#1F3A5F'});
    expect(live.brandings, isEmpty,
        reason: 'the live repository never saw it — there is no path from '
            'the demo scope to it');
  });

  test('two sessions do not share a thing', () async {
    final first = DemoFixture.build();
    final second = DemoFixture.build();
    await first.workspaces.setWorkspaceBranding('ws-1', {'seed_color': '#000000'});

    expect(second.workspaces.brandings, isEmpty,
        reason: 'a reset is a new fixture, not a cleanup of the old one');
  });

  test('every repository provider the app declares is overridden in Demo — '
      'a new one cannot quietly stay live', () {
    // Read from the source, so adding `SomethingRepository` to the app
    // fails here until Demo says what it resolves to.
    final declared = <String>{};
    for (final entity
        in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_providers.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in RegExp(
        r'^\s*(?:\w+)\s+(\w+Repository)\((?:Ref|WidgetRef) ref\)',
        multiLine: true,
      ).allMatches(source)) {
        declared.add('${match.group(1)}Provider');
      }
    }
    expect(declared, isNotEmpty, reason: 'the scan found no repositories');

    final missing = declared.difference(demoOverriddenProviders).toList()
      ..sort();
    expect(
      missing,
      isEmpty,
      reason: 'these resolve to a Supabase-backed repository inside a Demo '
          'scope, which is exactly what ADR 0028 forbids. Add them to '
          'demoOverrides and to demoOverriddenProviders, or write down in '
          'the ADR why Demo may reach a server for them.\n'
          '${missing.join(', ')}',
    );
  });

  test('#1377 — every outward edge the app owns is inert in Demo, and a '
      'session can say nothing left it', () async {
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);

    expect(fixture.outward.nothingLeft, isTrue);

    // The four edges, exercised through the providers a screen uses.
    await container.read(fileSaverProvider)(
        bytes: Uint8List(0), fileName: 'statement.pdf');
    await container.read(textSharerProvider)('come and work here');
    await container.read(linkLauncherProvider)(Uri.parse('https://example.org'));

    expect(fixture.outward.savedFiles, ['statement.pdf']);
    expect(fixture.outward.sharedTexts, ['come and work here']);
    expect(fixture.outward.openedLinks.single.host, 'example.org');
    expect(fixture.outward.nothingLeft, isFalse,
        reason: 'the session records what it was ASKED to send, so a '
            'journey can assert it stayed inside the app');
  });

  test('#1377 — the outward edges the app declares are all covered', () {
    // The same shape as the repository check: the app cannot grow a new
    // way out without Demo saying what it resolves to.
    expect(
      outwardEdgeProviders.difference(demoOverriddenProviders),
      isEmpty,
      reason: 'push used to be exempted here, on the stated premise that '
          '"the bootstrap never runs". It does: pushBootstrap gates on '
          'enabledFeatures, which in Demo comes from the fixture with '
          'pushNotifications ON, so an unoverridden connector and '
          'endpoint repository were reached on a configured build '
          '(#1564). Every outward edge is overridden now, and a new one '
          'has to say what it resolves to.',
    );
  });

  test('#1564 — merely entering Demo leaves every device preference it '
      'found exactly where it was', () async {
    SharedPreferences.setMockInitialValues(_realDevice);
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);

    // What a Demo START actually reads. `DefaultWorkspaceId.build` is
    // the destructive one: auth comes from the OVERRIDDEN fixture, so
    // it answers "signed in", reads the fixture's (absent) server
    // default and writes null through — and a null write on a
    // `PrefsStringStore` is `prefs.remove`.
    //
    // The listener matters: the fake's auth stream is `async*`, so the
    // FIRST build still reads "signed out" and only the rebuild after
    // the first emission takes the destructive branch. A test that read
    // the future once and walked away saw the preference intact.
    container.listen(defaultWorkspaceIdProvider, (_, _) {});
    await container.read(defaultWorkspaceIdProvider.future);
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await container.read(activeWorkspaceIdProvider.future);
    await container.read(localeControllerProvider.future);
    await container.read(themeControllerProvider.future);
    await container.read(activeBackendProvider.future);

    final prefs = await SharedPreferences.getInstance();
    for (final entry in _realDevice.entries) {
      expect(
        prefs.get(entry.key),
        entry.value,
        reason: 'entering the demonstration space changed the real app\'s '
            '${entry.key}. Demo owns a copy of every device preference; '
            'nothing it reads or writes may reach the device (#1564)',
      );
    }
  });

  test('#1564 — a preference CHANGED inside Demo stays inside it', () async {
    SharedPreferences.setMockInitialValues(_realDevice);
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);

    // Settings → Server, the worst of them: the real app reads this at
    // start-up, so an endpoint edited in Demo repointed it after a
    // restart.
    await container.read(activeBackendProvider.future);
    await container.read(activeBackendProvider.notifier).setEndpoint(
          const BackendEndpoint('https://demo.example.test', 'demo-key'),
        );
    await container.read(localeControllerProvider.notifier)
        .set(const Locale('es'));
    await container.read(themeControllerProvider.notifier).set(ThemeMode.light);
    await container.read(activeWorkspaceIdProvider.notifier).select('ws-1');

    final prefs = await SharedPreferences.getInstance();
    for (final entry in _realDevice.entries) {
      expect(prefs.get(entry.key), entry.value,
          reason: 'a visitor changed ${entry.key} in the demonstration '
              'space and the real app kept the change (#1564)');
    }
    // And the change DID land — in the session, where a visitor can see
    // it. An isolated demo that also forgets is not a demo.
    expect((await container.read(backendSettingsStoreProvider).read())?.url,
        'https://demo.example.test');
  });

  test('#1564 — the backend services that are not repositories are inert '
      'too: the schema check and the push registration', () async {
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);

    // The router watches this one. Unoverridden it is the Supabase
    // source, and an old configured backend could send an otherwise
    // independent Demo to the server-update screen.
    expect(container.read(schemaVersionSourceProvider),
        isNot(isA<SupabaseSchemaVersionSource>()));
    expect(await container.read(schemaCompatibilityProvider.future),
        SchemaCompatibility.current);

    // The push pair. Reading these unoverridden CONSTRUCTS
    // `SupabasePushEndpointRepository(Supabase.instance.client)`.
    expect(container.read(pushEndpointRepositoryProvider),
        same(fixture.outward.pushEndpoints));
    expect(container.read(pushConnectorProvider), same(fixture.outward.push));
    expect(
      await container.read(pushConnectorProvider).initialize(
            onNewEndpoint: (_) {},
            onUnregistered: () {},
            onMessage: (_) {},
          ),
      isFalse,
      reason: 'a Demo session has no transport, so PushService.start '
          'stops before it can register anything',
    );
    expect(fixture.outward.nothingLeft, isTrue);

    // The file cache is device state as much as a preference is.
    expect(container.read(cacheStoreProvider), same(fixture.prefs.cache));
  });

  test('#1564 — every per-device preference the app declares is '
      'session-owned in Demo', () {
    // Read from the source, the way the repository check does: a NEW
    // preference store cannot quietly write to the device from inside a
    // Demo session.
    final declared = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in RegExp(
        r'^\s*\w+\s+(\w+)\(Ref ref\)\s*=>\s*(?:const\s+)?Prefs\w+\(',
        multiLine: true,
      ).allMatches(source)) {
        declared.add('${match.group(1)}Provider');
      }
    }
    expect(declared, isNotEmpty, reason: 'the scan found no preferences');

    final missing = declared.difference(demoOverriddenProviders).toList()
      ..sort();
    expect(
      missing,
      isEmpty,
      reason: 'these write to SharedPreferences from inside a Demo scope, '
          'so a visitor changes what the real app remembers. Give the '
          'session its own store in DemoDevicePrefs and add the provider '
          'to demoOverrides:\n${missing.join(', ')}',
    );
  });
}
