// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1246 — every screen we can pump, in every language, narrowed to a
// phone.
//
// `l10n_completeness_test` proves the five ARB key sets are identical
// and the CI l10n gate proves the aggregates cannot drift, so a MISSING
// translation is already a red build. What was never proved is that the
// UI works in the other four.
//
// `text_expansion_test.dart` walks the seven shell surfaces. This walks
// the screens that have their own pump helper — the settings forms, the
// money faces, the editor — and it walks them at 360 px, because that
// is where a German compound stops fitting beside a trailing control.
//
// The helpers set generous viewports on purpose: they need every row
// BUILT so a finder can reach it. So each screen is pumped the way its
// own test pumps it, and then narrowed. The narrowing is the test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/editor/level_canvas_test.dart' show pumpCanvas;
import '../features/events/events_screen_test.dart' show pumpEvents;
import '../features/events/validation_settings_screen_test.dart'
    show pumpValidationSettings;
import '../features/money/invoices_test.dart' show pumpInvoices;
import '../features/money/money_faces_test.dart' show pumpFaces;
import '../features/plan/accessories_screen_test.dart' show pumpAccessories;
import '../features/reservations/reserve_hub_test.dart' show pumpHub;
import '../features/workspace/features_screen_test.dart' show pumpFeatures;

typedef ScreenPump = Future<void> Function(WidgetTester tester);

/// Adding a screen is a line, the same as in `test/a11y/`.
final Map<String, ScreenPump> _screens = {
  'Reserve hub': (t) => pumpHub(t),
  'Money faces': (t) => pumpFaces(t),
  'Invoices': (t) => pumpInvoices(t),
  'Alerts': (t) => pumpEvents(t),
  'Validation rules': (t) => pumpValidationSettings(t),
  'Features': (t) => pumpFeatures(t),
  // #1327 — the view the screen opens on.
  'Process overview': (t) => pumpFeatures(t, switches: false),
  'Accessories': (t) => pumpAccessories(t),
  'Level canvas': (t) => pumpCanvas(t),
};

/// German first: the longest of the five, and the one a developer
/// reading English is least likely to eyeball correctly.
const _locales = [Locale('de'), Locale('fr'), Locale('es'), Locale('it')];

/// A Pixel-class width, portrait. Narrower than anything mainstream and
/// wide enough to be a real target rather than a synthetic worst case.
const _phone = Size(360, 740);

void main() {
  for (final locale in _locales) {
    for (final entry in _screens.entries) {
      testWidgets('${entry.key} survives ${locale.languageCode} at phone width',
          (tester) async {
        tester.platformDispatcher.localesTestValue = [locale];
        tester.platformDispatcher.localeTestValue = locale;
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);

        await entry.value(tester);
        // Whatever the helper chose, the phone is what a member holds.
        tester.view.physicalSize = _phone;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpAndSettle();

        final e = tester.takeException();
        expect(
          e,
          isNull,
          reason: '"${entry.key}" under ${locale.languageCode} at '
              '${_phone.width.toInt()}px threw: $e — almost always a '
              'RenderFlex overflow from a string longer than the English '
              'this layout was built against. Wrap with Expanded or '
              'Flexible, ellipsize, or let it wrap.',
        );
      });
    }
  }
}
