// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1659 — the gallery search reads what templates are SET UP to do. The
// words "credit packs" keep the template whose inspected configuration
// has carnets on and an active product, and drop the one that merely
// exists; the capability understood is said on screen; inspections that
// cannot be read are an explicit "could not check", never an empty
// success; an unknown word offers a suggestion that is applied only by
// a tap; an answer to an older query is discarded.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/template_capabilities.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:deskilo/features/workspace/presentation/widgets/template_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

class GatedRepository extends FakeWorkspaceRepository {
  GatedRepository() : super.withWorkspace(featureFlags: {'workspaceLibrary': true});
  Object? failure;
  Completer<void>? gate;
  final asked = <String>[];

  @override
  Future<TemplateInspection> inspectWorkspaceTemplate(String templateId) async {
    asked.add(templateId);
    await gate?.future;
    if (failure != null) throw failure!;
    return super.inspectWorkspaceTemplate(templateId);
  }
}

TemplateInspection seeded(WorkspaceTemplate t, List<TemplateFieldRecord> fields) =>
    TemplateInspection(
      templateId: t.id,
      key: t.key,
      name: t.name,
      status: TemplateInspectionStatus.ok,
      profile: TemplateProfile.full,
      compatibility: TemplateCompatibility.supported,
      outline: const TemplateOutline(compatibility: TemplateCompatibility.supported, groups: []),
      fields: fields,
    );

TemplateFieldRecord present(String path, String id, Object? v) => TemplateFieldRecord(
    path: path, id: id, disposition: TemplateFieldDisposition.present, value: v);

Future<GatedRepository> pumpLibrary(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = GatedRepository();
  repo.templates.add(const WorkspaceTemplate(
    id: 'tpl-studio',
    key: 'studio',
    name: 'Studio',
    visibility: TemplateVisibility.shared,
    ownerWorkspaceId: 'ws-other',
    floorPlan: <Object?>[<String, Object?>{'name': 'L', 'offices': <Object?>[]}],
  ));
  final tiny = repo.templates.firstWhere((t) => t.key == 'tiny');
  final studio = repo.templates.firstWhere((t) => t.key == 'studio');
  repo.templateInspections[tiny.id] = seeded(tiny, [
    present(featureFieldId(WorkspaceFeature.carnets), featureFieldId(WorkspaceFeature.carnets), true),
    present('tables.credit_products[Ten].active', 'tables.credit_products[].active', true),
  ]);
  repo.templateInspections[studio.id] = seeded(studio, [
    present(featureFieldId(WorkspaceFeature.carnets), featureFieldId(WorkspaceFeature.carnets), false),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(workspace: repo),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/library'));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const ValueKey('template-search')), query);
  await tester.pump(TemplateGallery.debounce);
  await tester.pumpAndSettle();
}

const tinyCard = ValueKey('library-template-tiny');
const studioCard = ValueKey('library-template-studio');

void main() {
  testWidgets('"credit packs" keeps the template set up for them', (tester) async {
    await pumpLibrary(tester);
    expect(find.byKey(studioCard), findsOneWidget);
    await search(tester, 'credit packs');
    expect(find.byKey(tinyCard), findsOneWidget);
    expect(find.byKey(studioCard), findsNothing,
        reason: 'carnets off: the configuration says no');
    expect(find.text('Templates set up for: Credit packs'), findsOneWidget);
  });

  testWidgets('#1660 why a template matches: hidden until asked, then its '
      'state for each capability', (tester) async {
    await pumpLibrary(tester);
    expect(find.byKey(const ValueKey('template-why-tiny')), findsNothing,
        reason: 'browsing without a capability search explains nothing');
    await search(tester, 'credit packs');
    final why = find.byKey(const ValueKey('template-why-tiny'));
    expect(why, findsOneWidget);
    expect(find.textContaining('Credit packs · On'), findsNothing);
    await tester.tap(why);
    await tester.pumpAndSettle();
    expect(find.textContaining('Credit packs · On'), findsOneWidget);
    expect(find.text('Hide why'), findsOneWidget);
  });

  testWidgets('#1660 a requirement is chosen by a tap and holds until '
      'removed, whatever is typed next', (tester) async {
    await pumpLibrary(tester);
    await search(tester, 'credit packs');
    const offer = ValueKey('template-require-model.credit_packs');
    const chip = ValueKey('template-required-model.credit_packs');
    expect(find.byKey(offer), findsOneWidget);
    expect(find.byKey(chip), findsNothing, reason: 'typing only offers it');
    await tester.tap(find.byKey(offer));
    await tester.pumpAndSettle();
    expect(find.byKey(chip), findsOneWidget);
    expect(find.byKey(offer), findsNothing);

    await search(tester, '');
    expect(find.byKey(chip), findsOneWidget);
    expect(find.byKey(tinyCard), findsOneWidget);
    expect(find.byKey(studioCard), findsNothing,
        reason: 'the requirement still filters with no words typed');

    await tester.tap(find.byKey(const ValueKey('template-requirements-reset')));
    await tester.pumpAndSettle();
    expect(find.byKey(chip), findsNothing);
    expect(find.byKey(studioCard), findsOneWidget);
  });

  testWidgets('#1660 a preferred capability ranks first and hides nothing',
      (tester) async {
    final repo = await pumpLibrary(tester);
    // Flip the fixture: the shared studio has carnets, the builtin tiny
    // (listed first by default) does not.
    final tiny = repo.templates.firstWhere((t) => t.key == 'tiny');
    final studio = repo.templates.firstWhere((t) => t.key == 'studio');
    repo.templateInspections[tiny.id] = seeded(tiny, [
      present(featureFieldId(WorkspaceFeature.carnets), featureFieldId(WorkspaceFeature.carnets), false),
    ]);
    repo.templateInspections[studio.id] = seeded(studio, [
      present(featureFieldId(WorkspaceFeature.carnets), featureFieldId(WorkspaceFeature.carnets), true),
    ]);
    expect(tester.getTopLeft(find.byKey(tinyCard)).dy,
        lessThan(tester.getTopLeft(find.byKey(studioCard)).dy),
        reason: 'the builtin is listed first by default');
    await search(tester, 'Carnets');
    await tester.tap(find.byKey(const ValueKey('template-prefer-feature.carnets')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('template-preferred-feature.carnets')),
        findsOneWidget);
    await search(tester, '');
    expect(find.byKey(tinyCard), findsOneWidget,
        reason: 'preferring never hides a template');
    expect(find.byKey(studioCard), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(studioCard)).dy,
        lessThan(tester.getTopLeft(find.byKey(tinyCard)).dy),
        reason: 'the template set up for it now comes first');
  });

  testWidgets('#1660 a capability found by browsing its process becomes a '
      'requirement, and only that', (tester) async {
    await pumpLibrary(tester);
    await tester.tap(find.byKey(const ValueKey('template-browse-capabilities')));
    await tester.pumpAndSettle();
    final process = find.byKey(const ValueKey('capability-process-membershipCommerce'));
    await tester.tap(process);
    await tester.pumpAndSettle();
    final require = find.byKey(const ValueKey('capability-require-carnets'));
    await tester.ensureVisible(require);
    await tester.tap(require);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capability-browser')), findsNothing);
    expect(find.byKey(const ValueKey('template-required-feature.carnets')),
        findsOneWidget);
    expect(find.byKey(tinyCard), findsOneWidget);
    expect(find.byKey(studioCard), findsNothing,
        reason: 'carnets off in the studio template');
  });

  testWidgets('#1660 with reduced motion the browser opens and closes at '
      'once, and chooses the same', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpLibrary(tester);
    await tester.tap(find.byKey(const ValueKey('template-browse-capabilities')));
    await tester.pump();
    final browser = find.byKey(const ValueKey('capability-browser'));
    expect(browser, findsOneWidget);
    final firstFrame = tester.getRect(browser);
    await tester.pumpAndSettle();
    expect(tester.getRect(browser), firstFrame,
        reason: 'no slide-in when the platform asks for reduced motion: '
            'the first frame is already the final position');
    await tester.tap(
        find.byKey(const ValueKey('capability-process-membershipCommerce')));
    await tester.pumpAndSettle();
    final require = find.byKey(const ValueKey('capability-require-carnets'));
    await tester.ensureVisible(require);
    await tester.tap(require);
    await tester.pump();
    expect(find.byKey(const ValueKey('capability-browser')), findsNothing,
        reason: 'and no slide-out either');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('template-required-feature.carnets')),
        findsOneWidget, reason: 'the choice is the same as with motion');
  });

  testWidgets('#1660 closing the browser chooses nothing', (tester) async {
    await pumpLibrary(tester);
    await tester.tap(find.byKey(const ValueKey('template-browse-capabilities')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
    expect(find.byKey(studioCard), findsOneWidget);
  });

  testWidgets('the same capability in French finds the same template', (tester) async {
    await pumpLibrary(tester);
    await search(tester, 'Carnets');
    expect(find.byKey(tinyCard), findsOneWidget);
    expect(find.byKey(studioCard), findsNothing);
  });

  testWidgets('inspections that cannot be read say so, and show no match',
      (tester) async {
    final repo = await pumpLibrary(tester);
    repo.failure = Exception('offline');
    await search(tester, 'credit packs');
    expect(find.byKey(const ValueKey('template-search-unavailable')), findsOneWidget);
    expect(find.byKey(tinyCard), findsNothing);
    expect(find.byKey(studioCard), findsNothing);
  });

  testWidgets('an unknown word offers a suggestion, applied only by a tap',
      (tester) async {
    await pumpLibrary(tester);
    await search(tester, 'subscripton');
    final suggestion = find.byKey(const ValueKey('template-search-suggestion'));
    expect(suggestion, findsOneWidget);
    expect(find.text('Did you mean “subscription”?'), findsOneWidget);
    expect(find.byKey(const ValueKey('template-search-capabilities')), findsNothing,
        reason: 'nothing was substituted');
    await tester.tap(suggestion);
    await tester.pump(TemplateGallery.debounce);
    await tester.pumpAndSettle();
    expect(find.text('Templates set up for: Subscription plans'), findsOneWidget);
  });

  testWidgets('an answer to an older query is discarded', (tester) async {
    final repo = await pumpLibrary(tester);
    repo.gate = Completer<void>();
    await tester.enterText(find.byKey(const ValueKey('template-search')), 'credit packs');
    await tester.pump(TemplateGallery.debounce);
    await tester.enterText(find.byKey(const ValueKey('template-search')), 'studio');
    await tester.pump(TemplateGallery.debounce);
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('template-search-capabilities')), findsNothing);
    expect(find.byKey(studioCard), findsOneWidget, reason: 'plain words: the name matches');
    expect(find.byKey(tinyCard), findsNothing);
  });
}
