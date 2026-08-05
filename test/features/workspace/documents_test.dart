// SPDX-License-Identifier: 0BSD
//
// The workspace document library (#500): federated links to any DMS,
// role-gated visibility, admin/owner curation.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/features/workspace/domain/workspace_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Future<(FakeWorkspaceRepository, List<Uri>)> pumpDocuments(
  WidgetTester tester, {
  FakeWorkspaceRepository? workspace,
}) async {
  final repo = workspace ?? FakeWorkspaceRepository.withWorkspace();
  final launched = <Uri>[];
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: repo),
        linkLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push('/documents');
  await tester.pumpAndSettle();
  return (repo, launched);
}

WorkspaceDocument doc(String id, String title,
        {String minRole = 'member',
        String category = 'other',
        String provider = 'link'}) =>
    WorkspaceDocument(
      id: id,
      workspaceId: 'ws-1',
      title: title,
      category: category,
      provider: provider,
      url: 'https://example.org/$id',
      minRole: minRole,
    );

void main() {
  testWidgets(
      'documents group by category, open through the link seam, and '
      'carry the provider branding (#500)', (tester) async {
    final repo = FakeWorkspaceRepository.withWorkspace()
      ..documents.addAll([
        doc('d1', 'Statuts 2026',
            category: 'statutes', provider: 'gdrive'),
        doc('d2', 'Bilan 2025', category: 'finance', provider: 'onedrive'),
      ]);
    final (_, launched) = await pumpDocuments(tester, workspace: repo);

    expect(find.text('Statutes & legal'), findsOneWidget);
    expect(find.text('Financial statements'), findsOneWidget);
    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.text('OneDrive'), findsOneWidget);

    await tester.tap(find.text('Statuts 2026'));
    await tester.pumpAndSettle();
    expect(launched.single.toString(), 'https://example.org/d1');
  });

  testWidgets(
      'a plain member does NOT see admin/owner documents and gets no '
      'curation controls (#500)', (tester) async {
    final repo = FakeWorkspaceRepository.withWorkspace()
      ..documents.addAll([
        doc('d1', 'For everyone'),
        doc('d2', 'Board only', minRole: 'admin'),
        doc('d3', 'Owner secrets', minRole: 'owner'),
      ]);
    repo.myMember =
        repo.myMember.copyWith(isOwner: false, isAdmin: false);
    await pumpDocuments(tester, workspace: repo);

    expect(find.text('For everyone'), findsOneWidget);
    expect(find.text('Board only'), findsNothing);
    expect(find.text('Owner secrets'), findsNothing);
    expect(find.byKey(const ValueKey('documents-add')), findsNothing);
  });

  testWidgets(
      'the owner adds a linked document with provider, category and '
      'role (#500)', (tester) async {
    final (repo, _) = await pumpDocuments(tester);

    await tester.tap(find.byKey(const ValueKey('documents-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('document-title')), 'AG Protokoll');
    await tester.enterText(find.byKey(const ValueKey('document-url')),
        'https://drive.example/x');
    await tester.tap(find.byKey(const ValueKey('document-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admins and owners').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('document-save')));
    await tester.pumpAndSettle();

    final saved = repo.documents.single;
    expect(saved.title, 'AG Protokoll');
    expect(saved.url, 'https://drive.example/x');
    expect(saved.minRole, 'admin');
  });

  test('migration 0099 gates SELECT by role in RLS', () {
    final sql = File('supabase/migrations/0099_workspace_documents.sql')
        .readAsStringSync();
    expect(sql, contains('workspace_documents'));
    expect(sql, contains("min_role = 'member'"));
    expect(sql, contains("min_role = 'admin'"));
    expect(sql, contains("min_role = 'owner' and m.is_owner"));
    expect(sql, contains('enable row level security'));
  });
}
