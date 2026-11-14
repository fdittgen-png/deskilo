// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3970 — the toolbar of a selected line of the report editor: its six
// buttons (move up, move down, fields, move to another band, delete, done)
// are targets of the kit's minimum size ON SCREEN, whether the page is drawn
// at its own size or shrunk to fit beside the preview, and the row stays
// within the page's width. The page's lines themselves are the document drawn
// at scale and keep its size: they are reached by the keyboard as table rows
// are — Tab to a line, Enter selects it, Tab reaches its toolbar.
import 'package:deskilo/core/ui/kit/kit_metrics.dart';
import 'package:deskilo/features/money/presentation/widgets/report_page_style.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';
import '../../ux/experience_guards.dart';

const _band = 'visual-header';
const _buttons = ['up', 'down', 'fields', 'moveto', 'delete', 'done'];

Future<void> _open(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  final features = WorkspaceFeature.values.toSet();
  await pumpRoute(
    tester,
    '/report-editor',
    size: size,
    overrides: [
      ...standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: {for (final f in features) f.name: true},
        ),
      ),
      enabledFeaturesSyncProvider.overrideWithValue(features),
    ],
  );
  // The default layout (an empty page takes it without asking).
  await tester.ensureVisible(
    find.byKey(const ValueKey('invoice-template-reset')),
  );
  await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
  await tester.pumpAndSettle();
}

/// The scale the page is drawn at.
double _scale(WidgetTester tester) =>
    tester.widget<ReportPageScale>(find.byType(ReportPageScale).first).scale;

/// Whether the keyboard is on (or inside) the widget keyed [key].
bool _focusedIn(String key) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null || !context.mounted) return false;
  var inside = false;
  context.visitAncestorElements((e) {
    inside = e.widget.key == ValueKey(key);
    return !inside;
  });
  return inside;
}

Future<bool> _tabTo(WidgetTester tester, String key, {int limit = 400}) async {
  for (var i = 0; i < limit; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (_focusedIn(key)) return true;
  }
  return false;
}

void main() {
  final scales = <double>[];

  for (final size in const [
    Size(1920, 1080),
    Size(1440, 900),
    Size(1024, 768),
  ]) {
    testWidgets('at ${size.width.toInt()} a selected line\'s buttons are '
        '48 dp on screen and stay within the page', (tester) async {
      await _open(tester, size);
      await tester.ensureVisible(find.byKey(const ValueKey('$_band-line-0')));
      await tester.tap(find.byKey(const ValueKey('$_band-line-0')));
      await tester.pumpAndSettle();
      scales.add(_scale(tester));
      final page = tester.getRect(find.byType(ReportPageScale).first);
      for (final name in _buttons) {
        final button = find.byKey(ValueKey('$_band-$name-0'));
        if (button.evaluate().isEmpty) continue; // fields: a line with text
        final rect = tester.getRect(button);
        expect(
          rect.width,
          greaterThanOrEqualTo(KitMetrics.minTarget - .01),
          reason: '$name wide on screen',
        );
        expect(
          rect.height,
          greaterThanOrEqualTo(KitMetrics.minTarget - .01),
          reason: '$name high on screen',
        );
        expect(
          rect.right,
          lessThanOrEqualTo(page.right + .01),
          reason: '$name within the page',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('the sizes above drew the page both at its own size and shrunk', () {
    expect(scales, contains(1.0));
    expect(scales.any((s) => s < 1), isTrue, reason: '$scales');
  });

  testWidgets('by the keyboard alone: Tab to a line, Enter selects it, Tab '
      'reaches its toolbar', (tester) async {
    await _open(tester, const Size(1440, 900));
    expect(await _tabTo(tester, '$_band-line-0'), isTrue, reason: 'a line');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('$_band-up-0')), findsOneWidget);
    expect(
      await _tabTo(tester, '$_band-up-0', limit: 20),
      isTrue,
      reason: 'its toolbar',
    );
  });
}
