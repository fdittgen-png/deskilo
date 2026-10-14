// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — what the shell creates for a session is emptied when the active
// workspace switches and when the shell goes away.
import 'package:deskilo/app/shell/shell_session.dart';
import 'package:deskilo/app/shell/workspace_scoped.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Chosen extends ActiveWorkspaceId {
  @override
  Future<String?> build() async => 'ws-a';
}

void main() {
  test('a session is a WorkspaceScoped that forgets on a switch and on dispose',
      () {
    final session = ShellSession();
    expect(session, isA<WorkspaceScoped>());
    session.notifiedNoteIds.add('n1');
    session.onWorkspaceChanged('ws-b');
    expect(session.notifiedNoteIds, isEmpty);
    session.notifiedNoteIds.add('n2');
    session.dispose();
    expect(session.notifiedNoteIds, isEmpty);
  });

  test('switching the active workspace empties what the shell announced',
      () async {
    final container = ProviderContainer(
      overrides: [activeWorkspaceIdProvider.overrideWith(_Chosen.new)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(shellSessionProvider, (_, _) {});
    await container.read(activeWorkspaceIdProvider.future);
    final session = subscription.read()..notifiedNoteIds.add('n1');

    container.read(activeWorkspaceIdProvider.notifier).activate('ws-a');
    expect(session.notifiedNoteIds, {'n1'}, reason: 'the same space is no switch');

    container.read(activeWorkspaceIdProvider.notifier).activate('ws-b');
    expect(session.notifiedNoteIds, isEmpty);
  });

  test('closing the shell disposes the session', () async {
    final container = ProviderContainer(
      overrides: [activeWorkspaceIdProvider.overrideWith(_Chosen.new)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(shellSessionProvider, (_, _) {});
    final session = subscription.read()..notifiedNoteIds.add('n1');
    subscription.close();
    await Future<void>.delayed(Duration.zero);
    expect(session.notifiedNoteIds, isEmpty);
  });
}
