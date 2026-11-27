// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The workspace document library (#500): federated links to any DMS,
// role-gated visibility, admin/owner curation.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/features/workspace/domain/workspace_document.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

/// Bounded pumps: the table and its menus settle in a few frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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
  await _settle(tester);
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/documents'));
  await _settle(tester);
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
      'documents name their group and where they are stored, open through '
      'the link seam (#500)', (tester) async {
    final repo = FakeWorkspaceRepository.withWorkspace()
      ..documents.addAll([
        doc('d1', 'Statuts 2026',
            category: 'statutes', provider: 'gdrive'),
        doc('d2', 'Bilan 2025', category: 'finance', provider: 'onedrive'),
      ]);
    final (_, launched) = await pumpDocuments(tester, workspace: repo);

    expect(find.text('Statutes & legal'), findsOneWidget);
    expect(find.text('Financial statements'), findsOneWidget);
    // #4070: the table keeps saying where each document is stored.
    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.text('OneDrive'), findsOneWidget);

    await tester.tap(find.text('Statuts 2026'));
    await _settle(tester);
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
    await _settle(tester);
    await tester.enterText(
        find.byKey(const ValueKey('document-title')), 'AG Protokoll');
    await tester.enterText(find.byKey(const ValueKey('document-url')),
        'https://drive.example/x');
    await tester.tap(find.byKey(const ValueKey('document-role')));
    await _settle(tester);
    await tester.tap(find.text('Admins and owners').last);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('document-save')));
    await _settle(tester);

    final saved = repo.documents.single;
    expect(saved.title, 'AG Protokoll');
    expect(saved.url, 'https://drive.example/x');
    expect(saved.minRole, 'admin');
  });

  test('#4492 a new entry needs a title and an https link', () {
    expect(
      documentLinkProblems(title: ' ', url: 'http://drive.example/x'),
      {DocumentLinkProblem.titleMissing, DocumentLinkProblem.linkNotHttps},
    );
    expect(
      documentLinkProblems(title: 'Rules', url: ' https://drive.example/x'),
      isEmpty,
    );
  });

  testWidgets('#4492 the add form says each problem under its field, keeps '
      'what was typed and files nothing; corrected, it saves', (tester) async {
    final (repo, _) = await pumpDocuments(tester);
    final en = AppLocalizationsEn();

    await tester.tap(find.byKey(const ValueKey('documents-add')));
    await _settle(tester);
    expect(find.byType(AlertDialog), findsNothing, reason: 'a form sheet');
    await tester.enterText(
        find.byKey(const ValueKey('document-url')), 'http://drive.example/x');
    await tester.tap(find.byKey(const ValueKey('document-save')));
    await _settle(tester);

    expect(find.text(en.documentsTitleMissing), findsOneWidget);
    expect(find.text(en.documentsLinkNotHttps), findsOneWidget);
    expect(repo.documents, isEmpty);
    expect(find.text('http://drive.example/x'), findsOneWidget,
        reason: 'the form stays open with what was typed');

    await tester.enterText(
        find.byKey(const ValueKey('document-title')), 'House rules');
    await tester.enterText(find.byKey(const ValueKey('document-url')),
        'https://drive.example/x');
    await tester.tap(find.byKey(const ValueKey('document-save')));
    await _settle(tester);
    expect(repo.documents.single.title, 'House rules');
    expect(find.byKey(const ValueKey('document-save')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  Finder rowMenu(String id) => find.descendant(
        of: find.byKey(ValueKey('records-row-$id')),
        matching: find.byKey(const ValueKey('records-action-more')),
      );

  testWidgets(
      '#4070 Add document is a labelled button in the bar, and every row '
      'says its audience', (tester) async {
    final repo = FakeWorkspaceRepository.withWorkspace()
      ..documents.addAll([
        doc('d1', 'House rules'),
        doc('d2', 'Board only', minRole: 'admin'),
        doc('d3', 'Owner secrets', minRole: 'owner'),
      ]);
    await pumpDocuments(tester, workspace: repo);

    final add = find.byKey(const ValueKey('documents-add'));
    expect(add, findsOneWidget);
    expect(
      find.descendant(of: add, matching: find.text('Add a document')),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('records-row-d1')),
        matching: find.text('Every member'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('records-row-d2')),
        matching: find.text('Admins and owners'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('records-row-d3')),
        matching: find.text('Owners only'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets(
      '#4070 the row menu holds Open, Edit audience and Delete; Delete '
      'still asks', (tester) async {
    final repo = FakeWorkspaceRepository.withWorkspace()
      ..documents.addAll([doc('d1', 'House rules'), doc('d2', 'Fire plan')]);
    final (_, launched) = await pumpDocuments(tester, workspace: repo);

    await tester.tap(rowMenu('d1'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('records-action-open')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('records-action-audience')), findsOneWidget);
    expect(find.byKey(const ValueKey('records-action-delete')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('records-action-open')));
    await _settle(tester);
    expect(launched.single.toString(), 'https://example.org/d1');

    // Delete asks; cancelling keeps the row.
    await tester.tap(rowMenu('d1'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('records-action-delete')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('document-delete-confirm')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('documents-cancel-2')));
    await _settle(tester);
    expect(repo.documents.length, 2);

    await tester.tap(rowMenu('d1'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('records-action-delete')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('document-delete-confirm')));
    await _settle(tester);
    expect(repo.documents.map((d) => d.id), ['d2']);
  });

  testWidgets('#4070 Edit audience changes who sees the document',
      (tester) async {
    final repo = FakeWorkspaceRepository.withWorkspace()
      ..documents.add(doc('d1', 'House rules'));
    await pumpDocuments(tester, workspace: repo);

    await tester.tap(rowMenu('d1'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('records-action-audience')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('document-audience-edit')));
    await _settle(tester);
    await tester.tap(find.text('Owners only').last);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('document-audience-save')));
    await _settle(tester);

    expect(repo.documents.single.minRole, 'owner');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('records-row-d1')),
        matching: find.text('Owners only'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('#4070 a member only opens; the menu has no curation',
      (tester) async {
    final repo = FakeWorkspaceRepository.withWorkspace()
      ..documents.add(doc('d1', 'House rules'));
    repo.myMember = repo.myMember.copyWith(isOwner: false, isAdmin: false);
    await pumpDocuments(tester, workspace: repo);

    await tester.tap(rowMenu('d1'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('records-action-open')), findsOneWidget);
    expect(find.byKey(const ValueKey('records-action-audience')), findsNothing);
    expect(find.byKey(const ValueKey('records-action-delete')), findsNothing);
  });

  testWidgets('#4070 on a phone the row is a card with the same menu',
      (tester) async {
    final repo = FakeWorkspaceRepository.withWorkspace()
      ..documents.add(doc('d1', 'House rules', minRole: 'admin'));
    await pumpDocuments(tester, workspace: repo);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await _settle(tester);

    expect(find.text('Admins and owners'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('document-menu-d1-more')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('document-menu-d1-audience')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('document-menu-d1-delete')),
        findsOneWidget);
  });
}
