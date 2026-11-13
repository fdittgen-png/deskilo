// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3604 (desk F3) — a page is drawn in the measure its route declares. The
// three measures keep their named limits; /invoices declares work and leaves
// the wide frame; a phone and a medium window draw it exactly as before; the
// routes still on today's frame only fall.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/ui/adaptive/page_measure.dart';
import 'package:deskilo/core/ui/app_frame.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

/// #3619 — the routes still on today's frame, per class; none is a
/// workspace route. The account's own pages keep the frame they are read
/// in, the operator's and the public entry pages theirs. A count only falls.
const _framedByClass = {
  RouteClass.publicEntry: _framedPublicEntry,
  RouteClass.nativeAccount: _framedNativeAccount,
  RouteClass.operator: _framedOperator,
  RouteClass.workspace: 0,
};
const _framedPublicEntry = 12;
const _framedNativeAccount = 38;
const _framedOperator = 2;

Future<Rect> _invoicesAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final features = WorkspaceFeature.values.toSet();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {for (final f in features) f.name: true},
          ),
        ),
        enabledFeaturesSyncProvider.overrideWithValue(features),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
      .read(routerProvider)
      .go('/invoices');
  await tester.pumpAndSettle();
  return tester.getRect(find.byKey(const ValueKey('invoicing-home')));
}

Future<double> _width(WidgetTester tester, Widget measure, double room) async {
  tester.view.physicalSize = Size(room, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(room, 900)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: room, height: 900, child: measure),
        ),
      ),
    ),
  );
  return tester.getSize(find.byKey(const ValueKey('measured'))).width;
}

void main() {
  const measured = SizedBox.expand(key: ValueKey('measured'));

  testWidgets('each measure keeps its named limit at 1920', (tester) async {
    expect(
      await _width(tester, const FormColumn(child: measured), 1920),
      kFormColumnWidth,
    );
    expect(
      await _width(tester, const ReadingColumn(child: measured), 1920),
      kReadingColumnWidth,
    );
    expect(
      await _width(tester, const WorkArea(child: measured), 1920),
      kWorkAreaMaxWidth,
    );
    // A work area with gutters: the room less a large window's gutters.
    expect(
      await _width(tester, const WorkArea(child: measured), 1647),
      1647 - 2 * kWorkAreaGutterLarge,
    );
  });

  testWidgets('below the expanded class a work area adds no gutter', (
    tester,
  ) async {
    for (final room in [390.0, 800.0]) {
      expect(await _width(tester, const WorkArea(child: measured), room), room);
    }
  });

  test('the route table declares /invoices work, and no route is both on '
      'the wide frame and on its own measure', () {
    expect(measureOf('/invoices'), PageMeasure.work);
    for (final prefix in kWideRoutePrefixes) {
      expect(measureOf(prefix), PageMeasure.framed, reason: prefix);
    }
    for (final r in routeRules) {
      if (r.measure == PageMeasure.framed) continue;
      expect(
        kWideRoutePrefixes.any(
          (p) => r.pattern == p || r.pattern.startsWith('$p/'),
        ),
        isFalse,
        reason: r.pattern,
      );
    }
  });

  test('no workspace route is on today\'s frame; the others only fall', () {
    for (final MapEntry(key: kind, value: pinned) in _framedByClass.entries) {
      final framed = [
        for (final r in routeRules)
          if (r.kind == kind && r.measure == PageMeasure.framed) r.pattern,
      ];
      expect(
        framed.length,
        lessThanOrEqualTo(pinned),
        reason: '${kind.name}: a route given its own measure is not given '
            'back the frame: $framed',
      );
      if (framed.length < pinned) {
        fail('lower the framed ${kind.name} routes to ${framed.length}');
      }
    }
  });

  testWidgets('at 1920 /invoices gives its content more than 1500 px', (
    tester,
  ) async {
    final page = await _invoicesAt(tester, const Size(1920, 1080));
    expect(page.width, greaterThan(1500));
  });

  for (final size in [const Size(390, 844), const Size(800, 900)]) {
    testWidgets('at ${size.width.toInt()} /invoices is drawn as before: the '
        'whole window wide', (tester) async {
      final page = await _invoicesAt(tester, size);
      expect(page.left, 0);
      expect(page.width, size.width);
    });
  }
}
