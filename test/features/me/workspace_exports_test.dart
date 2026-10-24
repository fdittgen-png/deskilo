// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — My data › Personal information offers each workspace's own
// records as its own export, asked on that workspace's host when the
// person taps Export: one row per workspace, each delivered through the
// truthful delivery or named as not done on its own, with Try again where
// asking again can help. An answer that arrives for another account is
// dropped.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/workspace_export_repository.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/features/me/application/workspace_exports.dart';
import 'package:deskilo/features/me/data/host_workspace_export_repository.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/domain/workspace_export.dart';
import 'package:deskilo/features/me/providers/me_providers.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _instA = '11111111-1111-4111-8111-111111111111';
const _instB = '22222222-2222-4222-8222-222222222222';
const _wsA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _wsB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

const _sourceA = WorkspaceExportSource(
  installationId: _instA,
  workspaceId: _wsA,
  hostedHere: true,
  label: 'Kraftwerk Hall',
);
const _sourceB = WorkspaceExportSource(
  installationId: _instB,
  workspaceId: _wsB,
  label: 'Atelier B',
);

Map<String, Object?> _document(
  WorkspaceExportSource source, {
  Object? exportedAt = '2026-10-24T08:30:00Z',
}) => {
  'exported_at': exportedAt,
  'member': {'id': 'member-${source.workspaceId}'},
  'reservations': [
    {'id': 'r-1'},
    {'id': 'r-2'},
  ],
  'invoices': [
    {'id': 'i-1'},
  ],
};

/// The device saver, scripted: what it answers and what it was handed.
class _Saver {
  SaveOutcome answer = const SavedFile('Download/deskilo-my-data.json');
  final files = <String, Uint8List>{};

  Future<SaveOutcome> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    files[fileName] = bytes;
    return answer;
  }
}

Finder _key(String key) => find.byKey(ValueKey(key));
String _id(WorkspaceExportSource s) => '${s.installationId}:${s.workspaceId}';

Future<void> _open(
  WidgetTester tester, {
  required WorkspaceExportRepository exports,
  _Saver? saver,
  List<WorkspaceExportSource>? sources = const [_sourceA, _sourceB],
  FakeMeRepository? me,
}) async {
  final router = await pumpMeApp(
    tester,
    workspace: FakeWorkspaceRepository(workspaces: []),
    me: me,
    extraOverrides: <Override>[
      personalShellEnabledProvider.overrideWithValue(true),
      fileDeliveryModeProvider.overrideWithValue(FileDeliveryMode.direct),
      typedFileSaverProvider.overrideWithValue((saver ?? _Saver()).save),
      sessionStateProvider.overrideWith((ref) => Stream.value('user-1')),
      workspaceExportRepositoryProvider.overrideWithValue(exports),
      // Null: derived from the personal home's references, as in the app.
      if (sources != null)
        myWorkspaceExportSourcesProvider.overrideWith((ref) async => sources),
    ],
  );
  await goTo(tester, router, '/me/data?view=profile');
  await tester.scrollUntilVisible(
    _key('me-data-workspaces'),
    200,
    scrollable: find
        .descendant(
          of: _key('me-data-profile'),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pumpAndSettle();
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

/// A repository that answers each workspace once its gate opens.
class _Slow implements WorkspaceExportRepository {
  final Map<String, Future<void>> gates = {};

  @override
  Future<WorkspaceExport> export(WorkspaceExportSource source) async {
    await gates[source.workspaceId];
    return WorkspaceExport.decode(source, _document(source));
  }
}

void main() {
  group('the sources and the answer', () {
    test('every workspace my account names with a relationship is one '
        'source; one I left or hold nothing in is not', () {
      PersonalWorkspaceRef ref(
        String inst,
        String ws, {
        bool here = false,
        RefStatus? status,
        String? label,
      }) => PersonalWorkspaceRef(
        networkId: '$inst:$ws',
        hostedHere: here,
        freshness: RefFreshness.local,
        status: status,
        label: label,
      );
      final sources = workspaceExportSourcesOf(
        PersonalWorkspaceRefs(
          homeInstallationId: _instA,
          refs: [
            ref(_instA, _wsA, here: true, status: RefStatus.active, label: 'A'),
            ref(_instA, _wsB, here: true),
            ref(
              _instA,
              'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
              here: true,
              status: RefStatus.exited,
            ),
            ref(_instB, _wsB, label: 'B'),
          ],
        ),
      );
      expect(sources, [
        const WorkspaceExportSource(
          installationId: _instA,
          workspaceId: _wsA,
          hostedHere: true,
          label: 'A',
        ),
        const WorkspaceExportSource(
          installationId: _instB,
          workspaceId: _wsB,
          label: 'B',
        ),
      ]);
    });

    test('the file is the host answer itself, named by the workspace and '
        'the export day', () {
      final export = WorkspaceExport.decode(_sourceA, _document(_sourceA));
      expect(export.count('reservations'), 2);
      expect(export.count('ledger'), 0);
      expect(export.fileName, 'deskilo-my-data-kraftwerk-hall-2026-10-24.json');
      expect(jsonDecode(utf8.decode(export.bytes())), _document(_sourceA));
      final unnamed = WorkspaceExport.decode(
        const WorkspaceExportSource(installationId: _instB, workspaceId: _wsB),
        _document(_sourceB),
      );
      expect(unnamed.fileName, 'deskilo-my-data-$_wsB-2026-10-24.json');
    });

    test('an answer without its time or its member is refused, never an '
        'empty export', () {
      for (final raw in <Object?>[
        null,
        'export',
        _document(_sourceA, exportedAt: 'yesterday'),
        {'exported_at': '2026-10-24T08:30:00Z'},
      ]) {
        expect(
          () => WorkspaceExport.decode(_sourceA, raw),
          throwsA(
            isA<WorkspaceExportRefused>().having(
              (e) => e.failure,
              'failure',
              WorkspaceExportFailure.malformed,
            ),
          ),
          reason: '$raw',
        );
      }
    });

    test('the refusals export_my_data raises on purpose are typed; others '
        'are not', () {
      WorkspaceExportFailure? of(String code, [String message = '']) =>
          workspaceExportRefusalOf(
            PostgrestException(message: message, code: code),
          );
      expect(of('42501'), WorkspaceExportFailure.forbidden);
      expect(
        of('P0001', 'not a member of this workspace'),
        WorkspaceExportFailure.forbidden,
      );
      expect(of('P0001', 'something else'), isNull);
      expect(of('57014'), isNull);
    });
  });

  group('the command', () {
    test('a refusal is typed; anything else is a host that did not '
        'answer', () async {
      final repo = FakeWorkspaceExportRepository(
        document: _document,
        failures: {
          _wsA: const WorkspaceExportRefused(WorkspaceExportFailure.disabled),
          _wsB: Exception('socket closed'),
        },
      );
      final command = WorkspaceExportCommand(repository: repo);
      final a = await command.run(_sourceA, principal: () => 'user-1');
      final b = await command.run(_sourceB, principal: () => 'user-1');
      expect(
        (a as WorkspaceExportNotDone).failure,
        WorkspaceExportFailure.disabled,
      );
      expect(
        (b as WorkspaceExportNotDone).failure,
        WorkspaceExportFailure.failed,
      );
    });

    test('signed out, nothing is asked', () async {
      final repo = FakeWorkspaceExportRepository(document: _document);
      final outcome = await WorkspaceExportCommand(repository: repo)
          .run(_sourceA, principal: () => null);
      expect(outcome, isA<WorkspaceExportNotDone>());
      expect(repo.asked, isEmpty);
    });

    test('an answer that arrives after the account changed is dropped, '
        'never offered as the new account\'s file', () async {
      var principal = 'user-1';
      final repo = FakeWorkspaceExportRepository(
        document: (source) {
          principal = 'user-2';
          return _document(source);
        },
      );
      final outcome = await WorkspaceExportCommand(repository: repo)
          .run(_sourceA, principal: () => principal);
      expect(outcome, isA<WorkspaceExportSuperseded>());
    });
  });

  group('My data › each workspace', () {
    testWidgets('one workspace exports its file while another one\'s host '
        'is unreachable; Try again asks that host anew and its file comes', (
      tester,
    ) async {
      final saver = _Saver();
      final exports = FakeWorkspaceExportRepository(
        document: _document,
        failures: {
          _wsB: const WorkspaceExportRefused(
            WorkspaceExportFailure.hostUnavailable,
          ),
        },
      );
      await _open(tester, exports: exports, saver: saver);
      expect(find.text('Kraftwerk Hall'), findsOneWidget);
      expect(find.text('Atelier B'), findsOneWidget);
      // Nothing is asked until the person taps Export.
      expect(exports.asked, isEmpty);

      await _tap(tester, 'me-data-workspace-export-${_id(_sourceA)}');
      final bytes =
          saver.files['deskilo-my-data-kraftwerk-hall-2026-10-24.json'];
      expect(bytes, isNotNull);
      expect(jsonDecode(utf8.decode(bytes!)), _document(_sourceA));
      expect(
        find.text('Saved to Download/deskilo-my-data.json'),
        findsOneWidget,
      );

      await _tap(tester, 'me-data-workspace-export-${_id(_sourceB)}');
      expect(
        find.text(
          'This workspace\'s server is not reachable from here. '
          'Nothing was exported.',
        ),
        findsOneWidget,
      );
      expect(saver.files, hasLength(1));
      // The first workspace's row says nothing went wrong there.
      expect(_key('me-data-workspace-problem-${_id(_sourceA)}'), findsNothing);

      exports.failures.remove(_wsB);
      await _tap(tester, 'me-data-workspace-retry-${_id(_sourceB)}');
      expect(exports.asked, [_wsA, _wsB, _wsB]);
      expect(
        saver.files.keys,
        contains('deskilo-my-data-atelier-b-2026-10-24.json'),
      );
      expect(_key('me-data-workspace-problem-${_id(_sourceB)}'), findsNothing);
    });

    testWidgets('a workspace that refuses or has the export off says so, '
        'with no pointless retry', (tester) async {
      final exports = FakeWorkspaceExportRepository(
        document: _document,
        failures: {
          _wsA: const WorkspaceExportRefused(WorkspaceExportFailure.forbidden),
          _wsB: const WorkspaceExportRefused(WorkspaceExportFailure.disabled),
        },
      );
      final saver = _Saver();
      await _open(tester, exports: exports, saver: saver);
      await _tap(tester, 'me-data-workspace-export-${_id(_sourceA)}');
      await _tap(tester, 'me-data-workspace-export-${_id(_sourceB)}');
      expect(
        find.text(
          'This workspace refused: you are not an active member there. '
          'Nothing was exported.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('This workspace does not offer the data export.'),
        findsOneWidget,
      );
      expect(_key('me-data-workspace-retry-${_id(_sourceA)}'), findsNothing);
      expect(_key('me-data-workspace-retry-${_id(_sourceB)}'), findsNothing);
      expect(saver.files, isEmpty);
    });

    testWidgets('a private copy is named as kept inside the app, never as '
        'saved to a place', (tester) async {
      final saver = _Saver()
        ..answer = const SavedPrivately('/data/user/0/app/files/x.json');
      await _open(
        tester,
        exports: FakeWorkspaceExportRepository(document: _document),
        saver: saver,
        sources: const [_sourceA],
      );
      await _tap(tester, 'me-data-workspace-export-${_id(_sourceA)}');
      expect(find.textContaining('Kept inside Deskilo'), findsOneWidget);
      expect(find.textContaining('Saved to'), findsNothing);
    });

    testWidgets('a row waits for its own host; the other row stays usable', (
      tester,
    ) async {
      final slow = _Slow();
      final gate = Completer<void>();
      slow.gates[_wsA] = gate.future;
      final saver = _Saver();
      await _open(tester, exports: slow, saver: saver);
      await tester.tap(_key('me-data-workspace-export-${_id(_sourceA)}'));
      await tester.pump();
      expect(_key('me-data-workspace-busy-${_id(_sourceA)}'), findsOneWidget);
      await tester.tap(_key('me-data-workspace-export-${_id(_sourceB)}'));
      // The first row still waits (its bar runs), so no settling here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(saver.files.keys, ['deskilo-my-data-atelier-b-2026-10-24.json']);
      expect(_key('me-data-workspace-busy-${_id(_sourceA)}'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(saver.files, hasLength(2));
    });

    testWidgets('the list that cannot be read says so; Try again reads the '
        'personal home again', (tester) async {
      final me = FakeMeRepository()..refsFailure = Exception('offline');
      await _open(
        tester,
        exports: FakeWorkspaceExportRepository(document: _document),
        sources: null,
        me: me,
      );
      expect(_key('me-data-workspaces-failed'), findsOneWidget);
      expect(_key('me-data-workspace-export-${_id(_sourceA)}'), findsNothing);
      me
        ..refsFailure = null
        ..workspaceRefs = const PersonalWorkspaceRefs(
          homeInstallationId: _instA,
          refs: [
            PersonalWorkspaceRef(
              networkId: '$_instA:$_wsA',
              hostedHere: true,
              freshness: RefFreshness.local,
              status: RefStatus.active,
              label: 'Kraftwerk Hall',
            ),
          ],
        );
      await _tap(tester, 'me-data-workspaces-retry');
      expect(_key('me-data-workspaces-failed'), findsNothing);
      expect(_key('me-data-workspace-export-${_id(_sourceA)}'), findsOneWidget);
    });

    testWidgets('no workspace named: nothing to export, said plainly', (
      tester,
    ) async {
      await _open(
        tester,
        exports: FakeWorkspaceExportRepository(document: _document),
        sources: const [],
      );
      expect(find.text('Your account names no workspace yet.'), findsOneWidget);
    });
  });
}
