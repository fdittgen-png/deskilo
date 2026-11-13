// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3617 — the reports that are pages are declared once (the decision on
// #3617): for the same person the desk's table and the phone's tabs list
// exactly the reports of `reportPagesFor`, and a report whose feature is
// off or whose right the person lacks is in neither. (The search reads the
// same function: search_palette_test proves it finds them.)
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/report_pages.dart';
import 'package:deskilo/features/workspace/presentation/widgets/workspace_reports.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _admin = Member(
  id: 'm1',
  workspaceId: 'ws-1',
  userId: 'u1',
  isAdmin: true,
  isOwner: true,
  status: MemberStatus.active,
);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required Set<WorkspaceFeature> features,
  required Set<WorkspacePermission> permissions,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        enabledFeaturesSyncProvider.overrideWithValue(features),
        myPermissionsProvider.overrideWithValue(permissions),
        myMemberProvider.overrideWith((ref) async => _admin),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WorkspaceReports(workspaceName: 'Space', documents: []),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The report ids on screen: the desk's rows, or the phone's links in
/// every tab.
Future<Set<String>> _shown(WidgetTester tester, {required bool desk}) async {
  final ids = <String>{};
  for (final id in ['overview', 'register', 'status', 'vat', 'analysis']) {
    if (desk) {
      if (find.byKey(ValueKey('records-row-$id')).evaluate().isNotEmpty) {
        ids.add(id);
      }
      continue;
    }
    for (final tab
        in find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'workspace-section-',
                  ),
            )
            .evaluate()
            .toList()) {
      // The tab bar scrolls on a phone: the tab is brought into view.
      await tester.ensureVisible(find.byWidget(tab.widget));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidget(tab.widget));
      await tester.pumpAndSettle();
      if (find.byKey(ValueKey('reports-$id')).evaluate().isNotEmpty) {
        ids.add(id);
      }
    }
  }
  return ids;
}

void main() {
  final everyFeature = WorkspaceFeature.values.toSet();
  final cases = <String, Set<WorkspacePermission>>{
    'a finance reader': {WorkspacePermission.viewFinances},
    'an issuer': {WorkspacePermission.issueInvoices},
    'every right': WorkspacePermission.values.toSet(),
  };

  for (final MapEntry(key: who, value: rights) in cases.entries) {
    final declared = {
      for (final p in reportPagesFor(
        features: everyFeature,
        permissions: rights,
        isAdmin: true,
        actsAsOwner: true,
      ))
        p.id,
    };

    testWidgets('$who: the desk table lists the declared reports', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(1440, 900),
        features: everyFeature,
        permissions: rights,
      );
      expect(await _shown(tester, desk: true), declared);
    });

    testWidgets('$who: the phone\'s tabs list the same reports', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(390, 844),
        features: everyFeature,
        permissions: rights,
      );
      expect(await _shown(tester, desk: false), declared);
    });
  }

  test('a report whose feature is off is in no list', () {
    final ids = {
      for (final p in reportPagesFor(
        features: WorkspaceFeature.values.toSet()
          ..remove(WorkspaceFeature.workspaceOverview),
        permissions: WorkspacePermission.values.toSet(),
        isAdmin: true,
        actsAsOwner: true,
      ))
        p.id,
    };
    expect(ids, isNot(contains('overview')));
  });
}
