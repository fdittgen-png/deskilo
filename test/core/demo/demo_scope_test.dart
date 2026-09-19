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

import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
