// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in backend_settings_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/schema_version.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../mock_providers.dart';
import '../settings_sections.dart';

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
          backendSettings: store,
          schemaVersion: schemaVersion,
        ),
        bootedBackendUrlProvider.overrideWithValue(booted),
        backendProbeTransportProvider.overrideWithValue(
          (probes ?? ScriptedProbes()).call,
        ),
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
  await openSettingsSection(tester, 'advanced');
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
          message: 'relation does not exist',
          code: '42P01',
        );
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
