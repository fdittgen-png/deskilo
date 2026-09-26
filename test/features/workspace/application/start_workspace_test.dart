// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — a creation is ONE request however many times it is sent, and
// a refusal is a refusal rather than a button that appears not to have
// been pressed. Both rules lived on a wizard's State, where nothing
// could state them.
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/workspace/application/start_workspace.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({StartOutcome outcome, String? workspaceId})> _create(
  FakeWorkspaceRepository repo, {
  String name = 'Le Bocal',
  String currencyCode = 'eur',
  String timezone = ' Europe/Paris ',
  String requestId = 'req-1',
  String? templateId,
  TemplateOutline? outline,
}) =>
    WorkspaceStart(repo).create(
      name: name,
      countryCode: 'FR',
      currencyCode: currencyCode,
      timezone: timezone,
      requestId: requestId,
      templateId: templateId,
      outline: outline,
    );

void main() {
  group('a creation is one request', () {
    test('the same request id twice makes ONE workspace', () async {
      final repo = FakeWorkspaceRepository();
      final before = repo.workspaces.length;
      final first = await _create(repo);
      final second = await _create(repo);
      expect(second.workspaceId, first.workspaceId,
          reason: 'the second call must replay onto the first workspace');
      expect(repo.workspaces.length, before + 1);
    });

    test('a retry after a FAILURE still leaves one workspace', () async {
      final repo = FakeWorkspaceRepository()
        ..createFailure = StateError('the response never came back');
      final before = repo.workspaces.length;
      await expectLater(_create(repo), throwsStateError);
      final retry = await _create(repo);
      expect(retry.outcome, StartOutcome.created);
      expect(repo.workspaces.length, before + 1,
          reason: 'a second workspace is a second dev/prod pair');
    });

    test('and the rule above is not a default: two DIFFERENT ids make two',
        () async {
      final repo = FakeWorkspaceRepository();
      final before = repo.workspaces.length;
      await _create(repo, requestId: 'req-1');
      await _create(repo, requestId: 'req-2');
      expect(repo.workspaces.length, before + 2,
          reason: 'minting a fresh id per attempt is the bug the shared '
              'id prevents');
    });

    test('the id reaches the repository unchanged', () async {
      final repo = FakeWorkspaceRepository();
      await _create(repo, requestId: 'req-9');
      expect(repo.createRequests.single.requestId, 'req-9');
    });
  });

  group('what a creation needs before it is one', () {
    test('a nameless workspace is refused and NOTHING is written', () async {
      final repo = FakeWorkspaceRepository();
      final before = repo.workspaces.length;
      expect((await _create(repo, name: '   ')).outcome, StartOutcome.unnamed);
      expect(repo.workspaces.length, before);
      expect(repo.createRequests, isEmpty);
    });

    test('a currency that is not three letters is refused', () async {
      final repo = FakeWorkspaceRepository();
      expect((await _create(repo, currencyCode: 'EU')).outcome,
          StartOutcome.unplaced);
      expect(repo.createRequests, isEmpty);
    });

    test('no timezone is refused', () async {
      final repo = FakeWorkspaceRepository();
      expect(
          (await _create(repo, timezone: ' ')).outcome, StartOutcome.unplaced);
      expect(repo.createRequests, isEmpty);
    });

    test('the currency is written upper case and the rest trimmed', () async {
      final repo = FakeWorkspaceRepository();
      final created = await _create(repo);
      final made =
          repo.workspaces.firstWhere((w) => w.id == created.workspaceId);
      expect(made.currencyCode, 'EUR');
      expect(made.timezone, 'Europe/Paris');
      expect(made.name, 'Le Bocal');
    });
  });

  group('a template the server refused', () {
    test('is not sent — the creation would carry it in the same transaction',
        () async {
      final repo = FakeWorkspaceRepository();
      final outcome = await _create(
        repo,
        templateId: 'tpl-1',
        outline: const TemplateOutline(
          compatibility: TemplateCompatibility.notSupported,
          groups: [],
        ),
      );
      expect(outcome.outcome, StartOutcome.templateRefused);
      expect(repo.createRequests, isEmpty,
          reason: 'no workspace, rather than one that failed to decorate '
              'itself');
    });

    test('the outline comes from the inspection, which can refuse (#1655)', () async {
      final repo = FakeWorkspaceRepository.withWorkspace();
      final tiny = repo.templates.first;
      final ok = await WorkspaceStart(repo).outlineOf(tiny.id);
      expect(ok.refused, isFalse);
      expect(ok.groups, [TemplateGroup.space]);
      repo.templateInspections[tiny.id] = TemplateInspection(
        templateId: tiny.id,
        key: tiny.key,
        name: tiny.name,
        status: TemplateInspectionStatus.rejected,
        profile: TemplateProfile.rejected,
        compatibility: TemplateCompatibility.supported,
        outline: const TemplateOutline(
            compatibility: TemplateCompatibility.supported, groups: [TemplateGroup.space]),
        problems: const [TemplateProblem(path: 'workspace.nonsense', problem: 'unknown_field')],
      );
      final refused = await WorkspaceStart(repo).outlineOf(tiny.id);
      expect(refused.refused, isTrue, reason: 'a rejected inspection refuses before Create');
      expect(refused.reason, 'unknown_field: workspace.nonsense');
      final r = await _create(repo, templateId: tiny.id, outline: refused);
      expect(r.outcome, StartOutcome.templateRefused);
      expect(r.workspaceId, isNull);
    });

    test('an outline not yet known does not refuse', () async {
      final repo = FakeWorkspaceRepository();
      expect((await _create(repo, templateId: 'tpl-1')).outcome,
          StartOutcome.created);
      expect(repo.createRequests.single.templateId, 'tpl-1');
    });
  });

  group('joining', () {
    test('a WHOLE pasted invitation still joins', () async {
      final repo = FakeWorkspaceRepository();
      final before = repo.workspaces.length;
      expect(
        await WorkspaceStart(repo).join(
          'Salut ! Rejoins Le Bocal sur DesKilo.\n'
          'Voici ton code :\n'
          '```GOODCODE22```\n'
          'A bientot !',
        ),
        (outcome: JoinOutcome.joined, workspaceId: 'ws-joined-1'),
      );
      expect(repo.workspaces.length, before + 1);
    });

    test('nothing that looks like a code is REFUSED, not ignored', () async {
      final repo = FakeWorkspaceRepository();
      final before = repo.workspaces.length;
      expect(await WorkspaceStart(repo).join('   '),
          (outcome: JoinOutcome.noCode, workspaceId: null));
      expect(repo.workspaces.length, before);
    });
  });
}
