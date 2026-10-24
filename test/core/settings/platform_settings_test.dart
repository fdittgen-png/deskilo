// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L3 -- the platform settings of a workspace-free personal home: the
// existing registry's platform scope, `my_settings(p_workspace: null)`, read
// on the PERSONAL client by the production capture (currentSettingsCapture
// with no workspace). Selecting a workspace on another host changes
// nothing about it, no workspace is read or created, and signed out there is
// no capture at all. Two real SupabaseClients over recording fake servers.
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/cache/cache_store.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/instance/settings_bundle_asset.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/core/settings/settings_capture.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One installation: answers `my_settings` with [days] as the platform
/// value, records every request.
class _Host {
  _Host(this.origin, this.days);
  final String origin;
  final int days;
  final requests = <({String path, Object? body})>[];

  late final SupabaseClient client = SupabaseClient(
    origin,
    'sb_publishable_test',
    httpClient: MockClient((r) async {
      requests.add((
        path: r.url.path,
        body: r.body.isEmpty ? null : jsonDecode(r.body),
      ));
      if (r.url.path != '/rest/v1/rpc/my_settings') {
        return http.Response('{"message":"not here"}', 404, request: r);
      }
      return http.Response(
        jsonEncode([
          {
            'key': 'dunning.first_after_days',
            'type': 'int',
            'default_value': 14,
            'min': 1,
            'max': 365,
            'unit': 'days',
            'group_key': 'dunning',
            'scopes': ['platform', 'workspace'],
            'value': days,
            'origin': 'platform',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
}

/// Riverpod pauses a provider nobody listens to: listen, then read.
Future<SettingsCapture?> _capture(ProviderContainer c) =>
    c.listen(currentSettingsCaptureProvider.future, (_, _) {}).read();

void main() {
  late _Host p;
  late _Host w;

  ProviderContainer rig({String? signedIn = 'p-user'}) {
    final c = ProviderContainer(
      overrides: [
        sessionStateProvider.overrideWith((ref) => Stream.value(signedIn)),
        authStateProvider.overrideWith((ref) => Stream.value(signedIn)),
        // P is the personal client; the legacy process-wide client is W's, so
        // a read that went anywhere but P would show.
        contextClientsProvider.overrideWithValue(
          ContextClients(p.client, w.client),
        ),
        bootedBackendUrlProvider.overrideWithValue(p.origin),
        currentWorkspaceProvider.overrideWith((ref) async => null),
        cacheStoreProvider.overrideWithValue(InMemoryCacheStore()),
        settingsBundleLoaderProvider.overrideWithValue(
          () async => throw StateError('no bundled copy in this test'),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    p = _Host('https://p.example', 21);
    w = _Host('https://w.example', 99);
  });

  test('a workspace-free personal home reads its platform scope with a null '
      'workspace, on its own client', () async {
    final c = rig();
    final capture = await _capture(c);
    expect(capture, isNotNull);
    expect(capture!.identity.installation, 'https://p.example');
    expect(capture.identity.workspaceId, isNull);
    expect(capture.identity.principal, 'p-user');
    expect(capture.settings.effective['dunning.first_after_days'], 21);
    expect(
      capture.settings.originOf('dunning.first_after_days'),
      SettingOrigin.platform,
    );
    expect(p.requests, hasLength(1));
    expect(p.requests.single.path, '/rest/v1/rpc/my_settings');
    expect(p.requests.single.body, {
      'p_workspace': null,
    }, reason: 'the platform scope, no workspace and no dummy one');
  });

  test('selecting a workspace on another host does not decide them', () async {
    final c = rig();
    c.read(selectedWorkspaceHostProvider.notifier).select('ws-1', w.origin);
    final capture = await _capture(c);
    expect(capture!.identity.installation, 'https://p.example');
    expect(capture.settings.effective['dunning.first_after_days'], 21);
    expect(w.requests, isEmpty, reason: 'the workspace host is never asked');
    expect(
      p.requests.where((r) => r.path.contains('workspace')),
      isEmpty,
      reason: 'no workspace is read at P',
    );
  });

  test('signed out there is no capture and no request', () async {
    final c = rig(signedIn: null);
    expect(await _capture(c), isNull);
    expect(p.requests, isEmpty);
  });
}
