// SPDX-License-Identifier: AGPL-3.0-or-later
// #1661: source provenance cannot be inferred from a template UUID or name.
import 'package:deskilo/features/workspace/application/template_workbook.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:deskilo/core/demo/data/workbook_origin_repository.dart';
import 'package:deskilo/core/files/xlsx.dart';
import 'package:deskilo/features/workspace/domain/workbook_origin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deskilo/features/workspace/application/template_compare.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import '../../../helpers/mock_providers.dart';

const inspection = TemplateInspection(
  templateId: 'same-id', key: 'same-key', name: 'Same name',
  status: TemplateInspectionStatus.ok, profile: TemplateProfile.partial,
  compatibility: TemplateCompatibility.supported,
  outline: TemplateOutline(compatibility: TemplateCompatibility.supported, groups: []),
);

class GatedWorkspace extends FakeWorkspaceRepository {
  final gate = Completer<TemplateInspection>();
  final reading = Completer<void>();
  @override
  Future<TemplateInspection> inspectWorkspaceTemplate(String id) {
    if (!reading.isCompleted) reading.complete();
    return gate.future;
  }
}

const a = WorkbookOrigin(sourceId: 'source-a', installationId: 'installation-a', accountId: 'private-account-a');
const b = WorkbookOrigin(sourceId: 'source-b', installationId: 'installation-b', accountId: 'private-account-b');

void main() {
  test('actual export provider refuses an old read after sign-out', () async {
    final auth = FakeAuthRepository.signedIn();
    final repo = GatedWorkspace();
    var saves = 0;
    final container = ProviderContainer(overrides: [
      ...standardTestOverrides(auth: auth, workspace: repo),
      fileSaverProvider.overrideWithValue(({required bytes, required fileName}) async {
        saves++; return fileName;
      }),
    ]);
    addTearDown(container.dispose);
    final authListener = container.listen(authStateProvider, (_, _) {}, fireImmediately: true);
    addTearDown(authListener.close);
    await container.read(authStateProvider.future);
    await container.pump();
    final pending = container.read(templateWorkbookExportProvider)
        .export(['same-id'], now: DateTime.utc(2026));
    final refused = expectLater(pending, throwsStateError);
    await repo.reading.future;
    await auth.signOut();
    await container.pump();
    repo.gate.complete(inspection);
    await refused;
    expect(saves, 0);
  });
  test('a workbook without captured source declares provenance unknown', () {
    final sheets = templateWorkbook([inspection], capturedAt: DateTime.utc(2026));
    final templates = sheets.firstWhere((s) => s.name == 'Templates').rows;
    expect(templates.first, contains('installation_id'));
    expect(templates[1][templates.first.indexOf('installation_id')], 'unknown');
  });

  test('equal IDs and names from independent sources have distinct exported references', () {
    for (final origin in [a, b]) {
      final bytes = buildXlsx(templateWorkbook([inspection], capturedAt: DateTime.utc(2026), origin: origin));
      final files = ZipDecoder().decodeBytes(bytes);
      final text = files.files.where((f) => f.name.endsWith('.xml'))
          .map((f) => utf8.decode(f.content)).join('\n');
      expect(text, contains(origin.scopedTemplate('same-id')));
      expect(text, contains(origin.installationId));
      expect(text, isNot(contains(origin.accountId)));
      expect(text, isNot(contains((origin == a ? b : a).installationId)));
    }
    expect(a.scopedTemplate('same-id'), isNot(b.scopedTemplate('same-id')));
  });

  for (final change in ['installation', 'account', 'session', 'provider disposed']) {
    test('late inspection after $change switch cannot save', () async {
      final repo = GatedWorkspace();
      final source = FakeWorkbookOriginRepository()..origin = a;
      var current = true;
      var saves = 0;
      final export = TemplateWorkbookExport(repo, ({required bytes, required fileName}) async {
        saves++; return 'saved';
      }, origin: source, isCurrent: () => current);
      final pending = export.export(['same-id'], now: DateTime.utc(2026));
      final refused = expectLater(pending, throwsStateError);
      await repo.reading.future;
      if (change == 'installation') source.origin = b;
      if (change == 'account') {
        source.origin = const WorkbookOrigin(
          sourceId: 'source-a', installationId: 'installation-a', accountId: 'other-account');
      }
      if (change == 'session') {
        source.origin = const WorkbookOrigin(sourceId: 'source-a',
          installationId: 'installation-a', accountId: 'private-account-a', sessionId: 'new-login');
      }
      if (change == 'provider disposed') current = false;
      repo.gate.complete(inspection);
      await refused;
      expect(saves, 0);
    });
  }

  test('selection is immutable and cancellation at saving notification saves nothing', () async {
    final repo = GatedWorkspace();
    final ids = ['same-id'];
    final cancel = WorkbookCancel();
    var saves = 0;
    final export = TemplateWorkbookExport(repo, ({required bytes, required fileName}) async {
      saves++; return 'saved';
    }, origin: FakeWorkbookOriginRepository());
    final pending = export.export(ids, now: DateTime.utc(2026), cancel: cancel,
      onProgress: (p) { if (p.stage == WorkbookStage.saving) cancel.cancel(); });
    final refused = expectLater(pending, throwsA(isA<WorkbookCancelled>()));
    await repo.reading.future;
    ids.add('injected-selection');
    repo.gate.complete(inspection);
    await refused;
    expect(saves, 0);
  });
}
