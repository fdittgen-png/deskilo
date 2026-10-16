// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2589 C1 -- the production provider that hands an operation its settings
// fixes installation, workspace and person before the read awaits.
import 'dart:async';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Source implements SettingsSource {
  final loaded = <String?>[];
  @override
  Future<SettingsSet> load(String? workspaceId) async {
    loaded.add(workspaceId);
    return SettingsSet.defaults(const []);
  }

  @override
  Future<List<SettingVersion>> history(String? workspaceId, String key) async => [];
}

const _ws = Workspace(
  id: 'ws-a',
  name: 'A',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

void main() {
  testWidgets('captures the workspace and person it was asked for, not a later one', (tester) async {
    final source = _Source();
    final gate = Completer<Workspace?>();
    final container = ProviderContainer(overrides: [
      settingsSourceProvider.overrideWithValue(source),
      authStateProvider.overrideWith((ref) => Stream.value('u1')),
      bootedBackendUrlProvider.overrideWithValue('https://one.example'),
      currentWorkspaceProvider.overrideWith((ref) => gate.future),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(currentSettingsCaptureProvider, (_, _) {});
    addTearDown(sub.close);
    final pending = container.read(currentSettingsCaptureProvider.future);
    await tester.pump();
    gate.complete(_ws);
    await tester.pump();
    final capture = await pending;
    expect(source.loaded, ['ws-a']);
    expect(capture!.identity.workspaceId, 'ws-a');
    expect(capture.identity.principal, 'u1');
    expect(capture.identity.installation, 'https://one.example');
  });

  testWidgets('signed out there is nothing to capture and nothing is read', (tester) async {
    final source = _Source();
    final container = ProviderContainer(overrides: [
      settingsSourceProvider.overrideWithValue(source),
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      bootedBackendUrlProvider.overrideWithValue('https://one.example'),
      currentWorkspaceProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(currentSettingsCaptureProvider, (_, _) {});
    addTearDown(sub.close);
    final pending = container.read(currentSettingsCaptureProvider.future);
    await tester.pump();
    expect(await pending, isNull);
    expect(source.loaded, isEmpty);
  });
}
