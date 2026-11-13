// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2563 C1 — the personal account names workspaces by qualified reference
// and acts inside a workspace only through that workspace's host.
//
// * `my_personal_workspace_refs_v1` decodes strictly: a malformed
//   reference is refused, never an empty list; a status or freshness this
//   build does not know is read as the safe one and traced (#3884).
// * Me › Home lists the references this server does not show as a space,
//   says "not verified" for another installation's workspace, works with
//   zero workspaces here, and says when the references cannot be read.
// * Leaving a space goes to the workspace-access repository, never to the
//   personal one, and a host that cannot be verified leaves nothing.
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/features/me/application/me_actions.dart';
import 'package:deskilo/features/me/data/host_workspace_access_repository.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _home = '0ea54888-a3d7-441f-a025-ee4576cf2fa9';
const _away = '00000000-0000-4000-8000-0000025630ff';
const _ws = '00000000-0000-4000-8000-00002563c001';

Map<String, Object?> _ref(
  String installation, {
  String freshness = 'unavailable',
  String? status,
  String? label,
  bool favorite = false,
  bool isDefault = false,
}) => {
  'network_id': '$installation:$_ws',
  'installation_id': installation,
  'workspace_id': _ws,
  'hosted_here': installation == _home,
  'label': label,
  'status': status,
  'freshness': freshness,
  'is_default': isDefault,
  'is_favorite': favorite,
  'audience_fields': <String>[],
};

PersonalWorkspaceRefs _refs(List<Map<String, Object?>> refs) =>
    PersonalWorkspaceRefs.fromJson({
      'home': {
        'installation_id': _home,
        'roles': ['personal_home'],
      },
      'refs': refs,
    });

class _UnverifiedHosts implements WorkspaceHostResolver {
  final asked = <String>[];

  @override
  Future<ResolvedWorkspaceHost> resolve(String workspaceId) async {
    asked.add(workspaceId);
    throw const UnverifiedInstallation('w-b');
  }
}

void main() {
  group('decoding', () {
    test('the same local UUID on two installations is two references', () {
      final refs = _refs([
        _ref(_home, freshness: 'local', status: 'active', label: 'One'),
        _ref(_away, favorite: true, isDefault: true),
      ]);
      expect(refs.homeInstallationId, _home);
      expect(refs.refs.map((r) => r.networkId).toSet(), hasLength(2));
      expect(refs.refs.first.workspaceId, refs.refs.last.workspaceId);
      final away = refs.refs.last;
      expect(away.installationId, _away);
      expect(away.status, isNull);
      expect(away.freshness, RefFreshness.unavailable);
      expect(away.label, isNull);
      expect(refs.refs.first.status, RefStatus.active);
    });

    test('a malformed reference or answer is refused', () {
      expect(
        () => _refs([
          {..._ref(_away), 'network_id': _ws},
        ]),
        throwsA(isA<JsonShapeException>()),
      );
      expect(
        () => PersonalWorkspaceRefs.fromJson({'refs': 'none'}),
        throwsA(isA<JsonShapeException>()),
      );
    });

    test('#3884: a future status reads as none and a future freshness as '
        'unavailable, both traced; the other references stay', () {
      resetTracedRefKinds();
      final before = TraceLogger.instance.entries.length;
      final refs = _refs([
        _ref(_home, freshness: 'local', status: 'active', label: 'One'),
        {..._ref(_away), 'status': 'future_status', 'freshness': 'future_word'},
      ]);
      expect(refs.refs, hasLength(2));
      expect(refs.refs.last.status, isNull);
      expect(refs.refs.last.statusUnknown, isTrue,
          reason: 'unknown is kept apart from "no relationship"');
      expect(refs.refs.first.statusUnknown, isFalse);
      expect(refs.refs.last.freshness, RefFreshness.unavailable);
      expect(refs.refs.first.status, RefStatus.active);
      expect(TraceLogger.instance.entries.length - before, 2);
      // The same kinds decoded again (every refresh) are not traced again.
      _refs([
        {..._ref(_away), 'status': 'future_status', 'freshness': 'future_word'},
      ]);
      expect(TraceLogger.instance.entries.length - before, 2,
          reason: 'one entry per kind, not per row on every decode');
    });

    test('C2: a verified or stale fact elsewhere keeps its status', () {
      final refs = _refs([
        _ref(_away, freshness: 'verified', status: 'paused'),
        {
          ..._ref(_away, freshness: 'stale', status: 'active'),
          'network_id': '$_away:00000000-0000-4000-8000-00002563c002',
        },
      ]);
      expect(refs.refs.map((r) => r.freshness), [
        RefFreshness.verified,
        RefFreshness.stale,
      ]);
      expect(refs.refs.first.status, RefStatus.paused);
      expect(refs.beyondLocalSpaces, hasLength(2));
    });

    test('beyond the local spaces: elsewhere, or saved without membership', () {
      final refs = _refs([
        _ref(_home, freshness: 'local', status: 'active', label: 'One'),
        {
          ..._ref(_home, freshness: 'local', label: 'Listed'),
          'network_id': '$_home:00000000-0000-4000-8000-00002563c003',
        },
        _ref(_away),
      ]);
      expect(refs.beyondLocalSpaces.map((r) => r.label), ['Listed', null]);
    });
  });

  group('Me › Home', () {
    testWidgets('zero workspaces here: the references elsewhere are listed, '
        'unverified, with no empty state', (tester) async {
      final me = FakeMeRepository()
        ..workspaceRefs = _refs([_ref(_away, favorite: true, isDefault: true)]);
      final router = await pumpMeApp(
        tester,
        workspace: FakeWorkspaceRepository(workspaces: []),
        me: me,
      );
      await goTo(tester, router, '/me');
      expect(find.byKey(const ValueKey('me-home-empty')), findsNothing);
      expect(find.byKey(const ValueKey('me-refs')), findsOneWidget);
      expect(find.text('Places elsewhere'), findsOneWidget);
      expect(find.text('A place on another server'), findsOneWidget);
      expect(
        find.text('Membership not verified yet · Default'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('C2: a verified space elsewhere shows its status, a lapsed '
        'one says it is not confirmed', (tester) async {
      final me = FakeMeRepository()
        ..workspaceRefs = _refs([
          _ref(_away, freshness: 'verified', status: 'active'),
          {
            ..._ref(_away, freshness: 'stale', status: 'active'),
            'network_id': '$_away:00000000-0000-4000-8000-00002563c002',
          },
        ]);
      final router = await pumpMeApp(
        tester,
        workspace: FakeWorkspaceRepository(workspaces: []),
        me: me,
      );
      await goTo(tester, router, '/me');
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Membership not confirmed recently'), findsOneWidget);
      expect(find.text('Membership not verified yet'), findsNothing);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('a space of this server is not listed twice', (tester) async {
      final me = FakeMeRepository()
        ..workspaceRefs = _refs([
          _ref(_home, freshness: 'local', status: 'paused', label: 'Here'),
        ]);
      final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
      await goTo(tester, router, '/me');
      expect(find.byKey(const ValueKey('me-refs')), findsNothing);
    });

    testWidgets('references that cannot be read say so', (tester) async {
      final me = FakeMeRepository()..refsFailure = Exception('refused');
      final router = await pumpMeApp(tester, workspace: twoSpaces(), me: me);
      await goTo(tester, router, '/me');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('me-refs-unavailable')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('me-home-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.text('Your places elsewhere could not be read.'),
        findsOneWidget,
      );
    });
  });

  group('leaving a space', () {
    test(
      'goes to the workspace host, never to the personal repository',
      () async {
        final personal = FakeMeRepository();
        final host = FakeMeRepository();
        await MeActions(
          personal,
          FakeLinkedMeRepository(),
          host,
        ).leave('ws-2', isOwner: false);
        expect(host.left, ['ws-2']);
        expect(personal.left, isEmpty);
      },
    );

    test('an unverified host leaves nothing and says why', () async {
      final hosts = _UnverifiedHosts();
      await expectLater(
        HostWorkspaceAccessRepository(hosts).leaveSpace('ws-2'),
        throwsA(isA<UnverifiedInstallation>()),
      );
      expect(hosts.asked, ['ws-2']);
    });
  });
}
