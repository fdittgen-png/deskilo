// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #780 — the device chooses its Supabase instance. The app's own server
// stays the default; a community that runs its own project points the
// app at it from Settings → Server, with paste, a shareable QR and a
// connection test — no rebuild, no --dart-define.
//
// #1651 — three ways in (the default service, an organization's code,
// an operator's own project), a Save that exists only for the candidate
// a probe verified, a probe that finishes into the void once the
// candidate changed, and a saved-but-not-restarted switch shown as
// pending with its undo.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/backend/backend_config.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/backend_uri.dart';
import 'package:deskilo/core/backend/instance_facts.dart';
import 'package:deskilo/core/backend/schema_version.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/core/instance/instance_bundle_asset.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deskilo/features/profile/presentation/widgets/server_facts_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_supabase_management.dart';
import '../../helpers/mock_providers.dart';

const publishable = 'sb_publishable_0123456789abcdefghij';

/// The legacy anon key, with real claims — the classifier reads them.
final anonJwt = () {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg({'role': 'anon', 'iss': 'supabase'})}.s';
}();

const okReport = BackendProbeReport(
  result: BackendProbeResult.ok,
  reachable: ProbeFacet.yes,
  keyAccepted: ProbeFacet.yes,
  schemaRecognised: ProbeFacet.yes,
  compatibility: SchemaCompatibility.current,
);

/// A probe transport the test answers by hand, per candidate URL.
class ScriptedProbes {
  final probed = <String>[];
  final completers = <String, Completer<BackendProbeReport>>{};

  BackendProbeTransport call(BackendEndpoint endpoint) {
    probed.add(endpoint.url);
    return _Transport(this, endpoint.url);
  }

  /// The report [url]'s probe will answer with — completed by the test.
  Completer<BackendProbeReport> pending(String url) =>
      completers.putIfAbsent(url, Completer.new);
}

class _Transport implements BackendProbeTransport {
  _Transport(this.owner, this.url);
  final ScriptedProbes owner;
  final String url;

  /// Answers the way a real server would for the scripted report.
  @override
  Future<void> readOneWorkspace() async {
    final report = await owner.pending(url).future;
    switch (report.result) {
      case BackendProbeResult.ok:
      case BackendProbeResult.ahead:
      case BackendProbeResult.behind:
        return;
      case BackendProbeResult.unreachable:
        throw TimeoutException('12s');
      case BackendProbeResult.badKey:
        throw const PostgrestException(message: 'Invalid API key', code: '401');
      case BackendProbeResult.schemaMissing:
        throw const PostgrestException(
            message: 'relation does not exist', code: '42P01');
      case BackendProbeResult.attention:
        throw const PostgrestException(message: 'odd', code: '500');
    }
  }

  @override
  Future<int?> readVersion() async {
    final report = await owner.pending(url).future;
    return switch (report.result) {
      BackendProbeResult.ahead => requiredSchemaVersion + 1,
      BackendProbeResult.behind => requiredSchemaVersion - 1,
      _ => requiredSchemaVersion,
    };
  }

  @override
  Future<void> dispose() async {}
}

Future<InMemoryBackendSettingsStore> pumpServerScreen(
  WidgetTester tester, {
  BackendEndpoint? stored,
  BackendSwitchRecord? pending,
  String booted = '',
  SchemaVersionSource? schemaVersion,
  ScriptedProbes? probes,
  List<Uri>? launched,
  List<Override> extra = const [],
}) async {
  final store = InMemoryBackendSettingsStore()
    ..value = stored
    ..pending = pending;
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
            backendSettings: store, schemaVersion: schemaVersion),
        bootedBackendUrlProvider.overrideWithValue(booted),
        backendProbeTransportProvider
            .overrideWithValue((probes ?? ScriptedProbes()).call),
        ...extra,
        if (launched != null)
          linkLauncherProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return true;
          }),
      ],
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
  // The scroll stops as soon as the tile EXISTS — it may still sit under
  // the fold; bring it fully in before tapping.
  await tester.ensureVisible(find.byKey(const ValueKey('backend-server-tile')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('backend-server-tile')));
  await tester.pumpAndSettle();
  return store;
}

Future<void> chooseMode(WidgetTester tester, String key) async {
  final chip = find.byKey(ValueKey(key));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> typeCandidate(WidgetTester tester, String url, String key) async {
  await chooseMode(tester, 'backend-mode-operator');
  await tester.enterText(find.byKey(const ValueKey('backend-url-field')), url);
  await tester.enterText(find.byKey(const ValueKey('backend-key-field')), key);
  await tester.pump();
}

Future<void> tapTest(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('backend-test'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

VoidCallback? saveAction(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const ValueKey('backend-save')))
        .onPressed;

void main() {
  group('validation — only a Supabase endpoint is accepted', () {
    test('a good publishable endpoint passes', () {
      expect(
        validateBackendEndpoint('https://abcdefgh.supabase.co', publishable),
        isNull,
      );
    });

    test('the legacy anon JWT still passes — when it carries anon claims',
        () {
      expect(
        validateBackendEndpoint('https://self.hosted.example', anonJwt),
        isNull,
      );
      // #1651 — a bare eyJ shape no longer does.
      expect(
        validateBackendEndpoint('https://self.hosted.example', 'eyJa.b.c'),
        BackendEndpointError.keyNotSupabase,
      );
    });

    test('a self-hosted https host is fine — only the scheme is required',
        () {
      expect(
        validateBackendEndpoint('https://supabase.mycowork.example', publishable),
        isNull,
      );
    });

    test('each refusal names its own cause', () {
      expect(validateBackendEndpoint('', publishable),
          BackendEndpointError.urlEmpty);
      expect(
        validateBackendEndpoint('http://plain.example', publishable),
        BackendEndpointError.urlNotHttps,
      );
      expect(
        validateBackendEndpoint('https://localhost', publishable),
        BackendEndpointError.urlNoHost,
      );
      expect(validateBackendEndpoint('https://a.supabase.co', ''),
          BackendEndpointError.keyEmpty);
      // Not Supabase: a random database URL/key never reaches the store.
      expect(
        validateBackendEndpoint('https://a.supabase.co', 'postgres://secret'),
        BackendEndpointError.keyConnectionString,
      );
    });
  });

  group('the shared server QR', () {
    test('round-trips an endpoint', () {
      const endpoint = BackendEndpoint('https://abcdefgh.supabase.co', publishable);
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
    expect(find.byKey(const ValueKey('backend-pending')), findsNothing);
  });

  testWidgets('the four setup steps are on the screen, not in a manual',
      (tester) async {
    await pumpServerScreen(tester);
    final howto = find.byKey(const ValueKey('backend-howto'));
    await tester.ensureVisible(howto);
    await tester.tap(howto);
    await tester.pumpAndSettle();
    expect(find.textContaining('supabase.com'), findsOneWidget);
    expect(find.textContaining('supabase/migrations'), findsOneWidget);
    expect(find.textContaining('API keys'), findsOneWidget);
  });

  testWidgets('a bad endpoint is refused with its own reason and never saved',
      (tester) async {
    final probes = ScriptedProbes();
    final store = await pumpServerScreen(tester, probes: probes);
    await typeCandidate(tester, 'http://nope.example', publishable);
    await tapTest(tester);
    expect(find.text('The URL must start with https://.'), findsOneWidget);
    expect(probes.probed, isEmpty, reason: 'refused before any request');
    expect(saveAction(tester), isNull, reason: 'nothing verified, no Save');
    expect(store.value, isNull);
  });

  testWidgets('#1651 — a pasted secret is refused, never sent, stored, '
      'drawn or echoed', (tester) async {
    final probes = ScriptedProbes();
    final store = await pumpServerScreen(tester, probes: probes);
    await typeCandidate(tester, 'https://mycowork.supabase.co', 'sb_secret_hunter2');
    await tapTest(tester);
    expect(find.textContaining('secret key'), findsOneWidget);
    expect(find.textContaining('rotate it'), findsOneWidget);
    expect(probes.probed, isEmpty);
    expect(saveAction(tester), isNull);
    expect(store.value, isNull);
    // The value itself sits in its own field, never in a sentence.
    expect(
      find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains('hunter2')),
      findsNothing,
    );
    for (final e in TraceLogger.instance.entries) {
      expect('$e', isNot(contains('hunter2')));
    }
  });

  testWidgets('a good endpoint is saved only after its probe said usable, '
      'and resetting returns to the app\'s server', (tester) async {
    final probes = ScriptedProbes();
    final store = await pumpServerScreen(tester, probes: probes);
    await typeCandidate(tester, 'https://mycowork.supabase.co', publishable);
    expect(saveAction(tester), isNull);
    expect(find.byKey(const ValueKey('backend-save-hint')), findsOneWidget);
    probes.pending('https://mycowork.supabase.co').complete(okReport);
    await tapTest(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backend-test-result')), findsOneWidget);
    expect(find.byKey(const ValueKey('backend-test-facets')), findsOneWidget);
    expect(find.textContaining('Reached: yes'), findsOneWidget);
    expect(saveAction(tester), isNotNull);
    final save = find.byKey(const ValueKey('backend-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(store.value?.url, 'https://mycowork.supabase.co');
    expect(store.value?.host, 'mycowork.supabase.co');
    expect(store.pending?.previous, isNull, reason: 'replaced the default');
  });

  testWidgets('#1651 — a probe whose candidate changed underneath it '
      'finishes into the void', (tester) async {
    final probes = ScriptedProbes();
    final store = await pumpServerScreen(tester, probes: probes);
    await typeCandidate(tester, 'https://slow-a.supabase.co', publishable);
    await tapTest(tester);
    expect(probes.probed, ['https://slow-a.supabase.co']);
    // While A is still answering, the person types B.
    await tester.enterText(
        find.byKey(const ValueKey('backend-url-field')), 'https://b.supabase.co');
    await tester.pump();
    expect(find.text('Testing…'), findsNothing, reason: 'the edit cancels');
    // Now A answers, green.
    probes.pending('https://slow-a.supabase.co').complete(okReport);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backend-test-result')), findsNothing);
    expect(find.byKey(const ValueKey('backend-last-ok')), findsNothing);
    expect(saveAction(tester), isNull, reason: 'A\'s answer says nothing about B');
    expect(store.value, isNull);
  });

  testWidgets('#1651 — a candidate the server could not vouch for cannot '
      'be saved', (tester) async {
    final probes = ScriptedProbes();
    final store = await pumpServerScreen(tester, probes: probes);
    await typeCandidate(tester, 'https://odd.supabase.co', publishable);
    probes.pending('https://odd.supabase.co').complete(const BackendProbeReport(
      result: BackendProbeResult.attention,
      reachable: ProbeFacet.yes,
      keyAccepted: ProbeFacet.unknown,
      schemaRecognised: ProbeFacet.unknown,
      compatibility: null,
    ));
    await tapTest(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be classified'), findsOneWidget);
    expect(saveAction(tester), isNull);
    expect(store.value, isNull);
  });

  testWidgets('#1651 — a member connects with the organization\'s code and '
      'no key field', (tester) async {
    final probes = ScriptedProbes();
    final store = await pumpServerScreen(tester, probes: probes);
    // The connect mode is the default for an untouched install.
    expect(find.byKey(const ValueKey('backend-descriptor-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('backend-key-field')), findsNothing);
    const endpoint = BackendEndpoint('https://org.supabase.co', publishable);
    await tester.enterText(
      find.byKey(const ValueKey('backend-descriptor-field')),
      BackendUriCodec.encode(endpoint, label: 'Our coworking'),
    );
    await tester.pump();
    expect(find.text('Destination: org.supabase.co'), findsOneWidget);
    expect(find.textContaining('Named "Our coworking"'), findsOneWidget);
    expect(find.textContaining('not verified'), findsOneWidget);
    expect(saveAction(tester), isNull);
    probes.pending('https://org.supabase.co').complete(okReport);
    await tapTest(tester);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('backend-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(store.value?.url, 'https://org.supabase.co');
  });

  testWidgets('#1651 — a code that is not a server code is said so, and '
      'leaves the form as it was', (tester) async {
    final probes = ScriptedProbes();
    final store = await pumpServerScreen(tester, probes: probes);
    await tester.enterText(
      find.byKey(const ValueKey('backend-descriptor-field')),
      'deskilo://server?url=https://org.supabase.co&key=sb_secret_x',
    );
    await tester.pump();
    expect(find.text('That is not a valid DesKilo server code.'), findsOneWidget);
    expect(find.byKey(const ValueKey('backend-destination')), findsNothing);
    expect(find.byKey(const ValueKey('backend-save')), findsNothing);
    expect(probes.probed, isEmpty);
    expect(store.value, isNull);
  });

  testWidgets('a device already on its own server can go back to the default',
      (tester) async {
    final store = await pumpServerScreen(
      tester,
      stored: const BackendEndpoint('https://mycowork.supabase.co', publishable),
    );
    final reset = find.byKey(const ValueKey('backend-reset'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(store.value, isNull);
  });

  testWidgets('#1651 — a switch saved but not restarted is pending, and '
      'undo puts the running server back', (tester) async {
    const old = BackendEndpoint('https://old.supabase.co', publishable);
    const next = BackendEndpoint('https://next.supabase.co', publishable);
    final store = await pumpServerScreen(
      tester,
      stored: next,
      pending: const BackendSwitchRecord(previous: old),
      booted: old.url,
    );
    expect(find.byKey(const ValueKey('backend-pending')), findsOneWidget);
    expect(find.text('Saved for the next start'), findsOneWidget);
    expect(find.textContaining('still runs on old.supabase.co'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('backend-pending-undo')));
    await tester.pumpAndSettle();
    expect(store.value, old);
    expect(store.pending, isNull);
    expect(find.byKey(const ValueKey('backend-pending')), findsNothing);
  });

  testWidgets('#1651 — the running server and the saved one agree: no '
      'pending card', (tester) async {
    const same = BackendEndpoint('https://same.supabase.co', publishable);
    await pumpServerScreen(tester, stored: same, booted: same.url);
    expect(find.byKey(const ValueKey('backend-pending')), findsNothing);
  });

  group('#1309 — which instance, who owns it, is it current', () {
    const custom = BackendEndpoint('https://abc123.supabase.co', publishable);

    test('the project ref and the dashboard come from the host alone', () {
      expect(supabaseProjectRef('abc123.supabase.co'), 'abc123');
      expect(supabaseProjectRef('ABC123.supabase.co'), 'abc123');
      expect(supabaseProjectRef('db.example.org'), isNull);
      expect(supabaseDashboardUri('abc123').toString(),
          'https://supabase.com/dashboard/project/abc123');
    });

    testWidgets('a custom project names its ref, its owner and opens its '
        'dashboard', (tester) async {
      final launched = <Uri>[];
      await pumpServerScreen(tester, stored: custom, launched: launched);

      expect(find.text('Your Supabase project abc123'), findsOneWidget);
      expect(find.textContaining('DesKilo keeps no access'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('backend-open-dashboard')));
      await tester.pumpAndSettle();
      expect(launched.single.toString(),
          'https://supabase.com/dashboard/project/abc123');
      final hint = find.byKey(const ValueKey('backend-reset-hint'));
      await tester.ensureVisible(hint);
      expect(hint, findsOneWidget);
    });

    testWidgets('the default server shows no dashboard link and no owner',
        (tester) async {
      await pumpServerScreen(tester);
      expect(find.byKey(const ValueKey('backend-open-dashboard')), findsNothing);
      expect(find.byKey(const ValueKey('backend-ownership')), findsNothing);
      expect(find.text('Up to date (schema $requiredSchemaVersion)'),
          findsOneWidget);
    });

    testWidgets('a server one schema behind says it needs an update and how',
        (tester) async {
      // The app refuses to start on an older schema, so the card is read on
      // its own here — the same card the gate's Server link opens.
      await tester.pumpWidget(ProviderScope(
        overrides: standardTestOverrides(
            schemaVersion:
                const FixedSchemaVersionSource(requiredSchemaVersion - 1)),
        child: const MaterialApp(
          home: Scaffold(
            body: ServerFactsCard(endpoint: custom, isDefault: false),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Needs an update: this app needs schema $requiredSchemaVersion'),
          findsOneWidget);
      expect(find.textContaining('applies only what is missing'),
          findsOneWidget);
    });

    testWidgets('S2 — a full check runs the doctor with a pasted token that '
        'is never stored', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tokens = <String>[];
      final checked = <String>[];
      await pumpServerScreen(tester, stored: custom, extra: [
        supabaseManagementFactoryProvider.overrideWithValue((token) {
          tokens.add(token);
          return FakeSupabaseManagement();
        }),
        instanceDoctorRunnerProvider.overrideWithValue((api, ref) async {
          checked.add(ref);
          return const [
            DoctorFinding(DoctorLevel.ok, 'Site URL', 'matches InstanceAuthConfig'),
          ];
        }),
      ]);

      final expand = find.byKey(const ValueKey('backend-full-check'));
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('backend-full-check-token')), 'sbp_check_secret');
      final use = find.byKey(const ValueKey('backend-full-check-use-token'));
      await tester.ensureVisible(use);
      await tester.tap(use);
      await tester.pumpAndSettle();
      final run = find.byKey(const ValueKey('instance-doctor-run'));
      await tester.ensureVisible(run);
      await tester.tap(run);
      await tester.pumpAndSettle();

      expect(tokens, ['sbp_check_secret']);
      expect(checked, ['abc123'], reason: 'the device project, by its ref');
      expect(find.byKey(const ValueKey('instance-doctor-protected')), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        expect('${prefs.get(key)}', isNot(contains('sbp_check_secret')));
      }
      for (final e in TraceLogger.instance.entries) {
        expect('$e', isNot(contains('sbp_check_secret')));
      }
    });

    testWidgets('S2 — the app\'s own server offers no full check',
        (tester) async {
      await pumpServerScreen(tester);
      expect(find.byKey(const ValueKey('backend-full-check')), findsNothing);
    });
  });
}
