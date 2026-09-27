// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1659 — a capability search asks the server for candidates first: a
// template the server dropped (it switches a required feature off) is
// never inspected, and without a feature requirement nothing is asked.
import 'package:deskilo/core/demo/data/template_search_repository.dart';
import 'package:deskilo/features/workspace/application/template_search.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mock_providers.dart';

class _CountingWorkspace extends FakeWorkspaceRepository {
  final inspected = <String>[];
  @override
  Future<TemplateInspection> inspectWorkspaceTemplate(String templateId) {
    inspected.add(templateId);
    return super.inspectWorkspaceTemplate(templateId);
  }
}

const _a = WorkspaceTemplate(id: 'a', key: 'a', name: 'A');
const _b = WorkspaceTemplate(id: 'b', key: 'b', name: 'B');

void main() {
  test('only the server candidates are inspected', () async {
    final workspace = _CountingWorkspace()..templates.addAll([_a, _b]);
    final server = FakeTemplateSearchRepository(templates: [_a]);
    await TemplateSearch(workspace, server).run(
      capabilities: ['feature.kioskMode'],
      freeWords: const [],
      templates: const [_a, _b],
    );
    expect(server.calls.single.required, ['kioskMode']);
    expect(workspace.inspected, ['a']);
  });

  test('pages are followed to the end', () async {
    final workspace = _CountingWorkspace()..templates.addAll([_a, _b]);
    final server = FakeTemplateSearchRepository(
      templates: [_a, _b],
      pageSize: 1,
    );
    await TemplateSearch(workspace, server).run(
      capabilities: ['feature.kioskMode'],
      freeWords: const [],
      templates: const [_a, _b],
    );
    expect(server.calls.map((c) => c.cursor), [null, '1']);
    expect(workspace.inspected, ['a', 'b']);
  });

  test('no feature requirement: the server is not asked', () async {
    final workspace = _CountingWorkspace()..templates.addAll([_a, _b]);
    final server = FakeTemplateSearchRepository(templates: const []);
    await TemplateSearch(workspace, server).run(
      capabilities: ['policy.twoApprovals'],
      freeWords: const [],
      templates: const [_a, _b],
    );
    expect(server.calls, isEmpty);
    expect(workspace.inspected, ['a', 'b']);
  });
}
