// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C1 -- the composition root's display frame for the app-switcher
// cover: which inputs make a new frame, which frames are settled (and so
// acknowledged), and that the mounted host really drives the channel --
// a Me route is acknowledged even while no workspace answers.
import 'dart:async';

import 'package:deskilo/app/switcher_cover_host.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/privacy/switcher_cover.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final ws = FakeWorkspaceRepository.withWorkspace().workspaces.single;
  const signedIn = AsyncValue<String?>.data('p-1');
  const space = '/money/settlement';

  DisplayFrame frame({
    AsyncValue<String?> session = signedIn,
    AsyncValue<Workspace?>? workspace,
    String? host,
    String path = space,
  }) => displayFrameOf(
    session: session,
    workspace: workspace ?? AsyncValue.data(ws),
    hostSource: host,
    path: path,
  );

  group('displayFrameOf', () {
    test('an unknown session is the protected, unacknowledged frame', () {
      final f = frame(session: const AsyncValue.loading());
      expect(f, const DisplayFrame.unknown());
      expect(f.protected, isTrue);
      expect(f.settled, isFalse);
    });

    test('signed out is settled and unprotected; a failed session is '
        'settled and protected', () {
      final out = frame(session: const AsyncValue.data(null));
      expect((out.protected, out.settled), (false, true));
      final failed = frame(
        session: AsyncValue.error(StateError('x'), StackTrace.empty),
      );
      expect((failed.protected, failed.settled), (true, true));
    });

    test('a Me route is the personal frame and never waits for a '
        'workspace host', () {
      final f = frame(path: '/me', workspace: const AsyncValue.loading());
      expect(f.role, DisplaySourceRole.personal);
      expect(f.settled, isTrue);
      expect(f.target, isNull);
    });

    test('a space route waits for its workspace; its error is settled', () {
      expect(frame(workspace: const AsyncValue.loading()).settled, isFalse);
      expect(
        frame(
          workspace: AsyncValue<Workspace?>.error(
            StateError('down'),
            StackTrace.empty,
          ),
        ).settled,
        isTrue,
      );
      expect(frame().settled, isTrue);
    });

    test('the same workspace on another host, or another account, is '
        'another frame', () {
      expect(frame(), isNot(frame(host: 'https://two.example')));
      expect(frame(), isNot(frame(session: const AsyncValue.data('p-2'))));
      expect(frame(), frame());
    });
  });

  testWidgets('the mounted host drives the channel: the Me frame is '
      'announced and acknowledged while the workspace never answers', (
    tester,
  ) async {
    const channel = MethodChannel(SwitcherCover.channelName);
    final messenger = tester.binding.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add('${call.method}:${call.arguments}');
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final never = Completer<Workspace?>();
    final router = GoRouter(
      initialLocation: '/me',
      routes: [GoRoute(path: '/me', builder: (_, _) => const SizedBox())],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          switcherCoverProvider.overrideWithValue(SwitcherCover(web: false)),
          sessionStateProvider.overrideWith((ref) => Stream.value('p-1')),
          currentWorkspaceProvider.overrideWith((ref) => never.future),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => SwitcherCoverHost(
            router: router,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      calls,
      contains('setProtectedContext:{protected: true, frameEpoch: 2}'),
    );
    expect(calls.last, 'foregroundReady:{frameEpoch: 2}');
    expect(calls.where((c) => c.startsWith('foregroundReady')), [
      'foregroundReady:{frameEpoch: 2}',
    ], reason: 'the unknown first frame (epoch 1) is never acknowledged');
  });
}
