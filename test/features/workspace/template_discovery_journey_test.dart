// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1660 — the discovery journey at scale, through the real library: 155
// templates, a capability that appears in no template's name, required
// by an explicit tap; why each match matches; four shortlisted and a
// fifth refused with an instruction; the comparison of those four; back
// with the shortlist kept; and a template's detail. Assertions read
// values and states, not only labels.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/template_capabilities.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:deskilo/features/workspace/presentation/screens/template_compare_screen.dart';
import 'package:deskilo/features/workspace/presentation/screens/template_detail_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/template_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

WorkspaceTemplate _t(int i) => WorkspaceTemplate(
  id: 'tpl-$i',
  key: 'room_$i',
  name: 'Room ${i.toString().padLeft(3, '0')}',
  visibility: TemplateVisibility.public,
  ownerWorkspaceId: 'ws-other',
);

TemplateInspection _carnets(WorkspaceTemplate t, bool on) => TemplateInspection(
  templateId: t.id,
  key: t.key,
  name: t.name,
  status: TemplateInspectionStatus.ok,
  profile: TemplateProfile.partial,
  compatibility: TemplateCompatibility.supported,
  outline: const TemplateOutline(
    compatibility: TemplateCompatibility.supported,
    groups: [],
  ),
  fields: [
    TemplateFieldRecord(
      path: featureFieldId(WorkspaceFeature.carnets),
      id: featureFieldId(WorkspaceFeature.carnets),
      disposition: TemplateFieldDisposition.present,
      value: on,
    ),
  ],
);

void main() {
  testWidgets('155 templates: require, understand, shortlist, compare, '
      'come back, inspect', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = FakeWorkspaceRepository.withWorkspace(
      featureFlags: {'workspaceLibrary': true},
    );
    final withCarnets = {3, 40, 77, 101, 150};
    for (var i = 0; i < 155; i++) {
      final t = _t(i);
      repo.templates.add(t);
      repo.templateInspections[t.id] = _carnets(t, withCarnets.contains(i));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: repo),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/library'),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(TemplateCard).evaluate().length,
      lessThan(40),
      reason: 'the list stays lazy at 155 templates',
    );

    // A capability in no template's name, offered by the words, required
    // only by a tap.
    await tester.enterText(
      find.byKey(const ValueKey('template-search')),
      'Carnets',
    );
    await tester.pump(TemplateGallery.debounce);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('template-require-feature.carnets')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('template-search')), '');
    await tester.pump(TemplateGallery.debounce);
    await tester.pumpAndSettle();
    final shown = find.byType(TemplateCard);
    expect(
      shown,
      findsNWidgets(withCarnets.length),
      reason: 'exactly the five templates with carnets ON',
    );

    // Why the first matches: its state for the capability, in words.
    await tester.tap(find.byKey(const ValueKey('template-why-room_3')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('template-why-room_3-feature.carnets')),
      findsOneWidget,
    );
    expect(find.textContaining('· On'), findsOneWidget);

    // Shortlist four; the fifth is refused with an instruction.
    for (final i in [3, 40, 77, 101]) {
      final add = find.byKey(ValueKey('template-shortlist-room_$i'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
    }
    final fifth = find.byKey(const ValueKey('template-shortlist-room_150'));
    await tester.ensureVisible(fifth);
    await tester.tap(fifth);
    await tester.pump();
    expect(find.textContaining('Remove one first'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Compare the four, then come back with the shortlist kept.
    final compare = find.byKey(const ValueKey('template-compare'));
    await tester.ensureVisible(compare);
    await tester.tap(compare);
    await tester.pumpAndSettle();
    final screen = tester.widget<TemplateCompareScreen>(
      find.byType(TemplateCompareScreen),
    );
    expect(screen.templates.map((t) => t.key), [
      'room_3',
      'room_40',
      'room_77',
      'room_101',
    ]);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.text('Compare (4)'),
      findsOneWidget,
      reason: 'the shortlist survives the round trip',
    );
    expect(
      find.byKey(const ValueKey('template-required-feature.carnets')),
      findsOneWidget,
      reason: 'and so does the requirement',
    );

    // A template's detail: its carnets feature, in words.
    final details = find.byKey(const ValueKey('template-details-room_40'));
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.byType(TemplateDetailScreen), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('template-detail-section-workspace.feature_flags'),
      ),
      findsOneWidget,
    );
    expect(find.text('Yes'), findsOneWidget);
    expect(repo.flagWrites, isEmpty, reason: 'browsing writes nothing');
  });
}
