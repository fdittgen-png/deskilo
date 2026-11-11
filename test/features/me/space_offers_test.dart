// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — a published space page says what I can do there: a member
// enters; anyone else requests a membership; a published e-mail can be
// copied.
import 'dart:async';

import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/public_workspace_view.dart';
import 'package:deskilo/features/directory/presentation/space_offers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import 'me_app.dart';

/// The fake linked-installation registry's own origin.
const _here = 'https://demo.invalid';

PublicWorkspace _page(String id, {String source = _here, String email = ''}) =>
    PublicWorkspace(id, source, 'key', {
      'name': 'Public $id',
      'host_type': 'company',
      'email': email,
    });

Future<GoRouter> _open(
  WidgetTester tester,
  PublicWorkspace page, {
  FakeDirectoryRepository? directory,
  List<Override> extraOverrides = const [],
}) async {
  // #1847 — the page acts only while the card is still published.
  final router = await pumpMeApp(tester,
      workspace: twoSpaces(serverDefault: null),
      extraOverrides: extraOverrides,
      directory: (directory ?? FakeDirectoryRepository())..cards.add(page));
  await tester.pumpAndSettle();
  Navigator.of(tester.element(find.byType(Scaffold).first)).push(MaterialPageRoute<void>(
      builder: (_) => PublicWorkspaceView(workspace: page)));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('a member enters the space from its public page',
      (tester) async {
    final router = await _open(tester, _page('ws-2'));
    expect(find.byKey(const ValueKey('portal-request-membership')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('portal-enter')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/reserve');
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(find.text('DesKilo · Second Space'), findsWidgets);
  });

  testWidgets('anyone else requests a membership', (tester) async {
    await _open(tester, _page('ws-elsewhere'));
    expect(find.byKey(const ValueKey('portal-enter')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('portal-request-membership')));
    await tester.pumpAndSettle();
    expect(find.text('Request sent. The workspace will review your profile.'),
        findsOneWidget);
  });

  testWidgets('a space on another server is never entered from here',
      (tester) async {
    await _open(tester, _page('ws-2', source: 'https://elsewhere.example'));
    expect(find.byKey(const ValueKey('portal-enter')), findsNothing);
    expect(find.byKey(const ValueKey('portal-request-membership')), findsOneWidget);
  });

  testWidgets('a published e-mail is copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await _open(tester, _page('ws-elsewhere', email: 'hello@space.example'));
    await tester.tap(find.byKey(const ValueKey('portal-copy-email')));
    await tester.pumpAndSettle();
    expect(copied, 'hello@space.example');
    expect(find.text('E-mail copied'), findsOneWidget);
  });

  testWidgets('no e-mail published, nothing to copy', (tester) async {
    await _open(tester, _page('ws-elsewhere'));
    expect(find.byKey(const ValueKey('portal-copy-email')), findsNothing);
  });

  testWidgets('Ask to join is sent once and the page shows the request is '
      'pending (#3683)', (tester) async {
    final directory = FakeDirectoryRepository();
    await _open(tester, _page('ws-elsewhere'), directory: directory);
    final ask = find.byKey(const ValueKey('portal-request-membership'));
    await tester.tap(ask);
    await tester.pumpAndSettle();
    expect(directory.requests, ['ws-elsewhere']);
    expect(find.text('Request pending'), findsOneWidget);
    expect(tester.widget<FilledButton>(ask).onPressed, isNull,
        reason: 'no second request');
    await tester.tap(ask, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(directory.requests, hasLength(1));
  });

  testWidgets('no request is offered while my own businesses are not read '
      'yet (#3683)', (tester) async {
    final never = Completer<List<Workspace>>();
    await pumpApp(
      tester,
      Scaffold(
        body: SpaceOffers(
          workspace: _page('ws-2'),
          onRequest: () async => true,
        ),
      ),
      overrides: [
        ...standardTestOverrides(workspace: twoSpaces(serverDefault: null)),
        myWorkspacesProvider.overrideWith((ref) => never.future),
      ],
    );
    await tester.pump();
    final ask = find.byKey(const ValueKey('portal-request-membership'));
    expect(ask, findsOneWidget);
    expect(tester.widget<FilledButton>(ask).onPressed, isNull,
        reason: 'a member could be asking to join their own business');
  });

  testWidgets('a failed read of my businesses says so instead of offering '
      '"Ask to join" (#3683)', (tester) async {
    await _open(tester, _page('ws-2'), extraOverrides: [
      myWorkspacesProvider.overrideWith((ref) async => throw StateError('x')),
    ]);
    expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
    expect(find.byKey(const ValueKey('portal-request-membership')),
        findsNothing);
  });
}
