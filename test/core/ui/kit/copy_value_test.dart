// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3611 -- text on the desk can be selected, and a value people copy has a
// visible copy button while a mouse is the pointer. The button lives in the
// same subtree as the value: a masked value offers no copy and holds no raw
// value; revealed it copies exactly what is shown; hidden again, the copy
// path is gone.
import 'package:deskilo/core/privacy/private_values.dart';
import 'package:deskilo/core/ui/app_scroll_behavior.dart';
import 'package:deskilo/core/ui/kit/copy_value.dart';
import 'package:deskilo/core/ui/private_value.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mouse.dart';

const _secret = 'SENTINEL 1 234,56 EUR';
const _button = ValueKey('copy-value-button');
const _reveal = ValueKey('reveal');

class _MemoryStore implements PrivateValuesStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async => this.value = value;
}

List<Override> _overrides({required bool masked}) => [
  privateValuesStoreProvider.overrideWithValue(_MemoryStore()),
  if (masked)
    privateValuesPolicyProvider.overrideWithValue(
      const PrivateValuesPolicy(enabled: true),
    ),
];

Widget _host(Widget body, {bool masked = false}) => ProviderScope(
  overrides: _overrides(masked: masked),
  child: MaterialApp(
    scrollBehavior: const AppScrollBehavior(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: body)),
  ),
);

/// What the clipboard holds, read through the platform channel mock.
String? _clipboard;

void _mockClipboard(WidgetTester tester) {
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        _clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  testWidgets('no mouse, no button: a phone keeps its layout', (tester) async {
    await tester.pumpWidget(
      _host(const CopyValue(value: 'INV-7', child: Text('INV-7'))),
    );
    expect(find.byKey(_button), findsNothing);
    expect(find.text('INV-7'), findsOneWidget);
  });

  testWidgets('with a mouse the button copies exactly the value', (
    tester,
  ) async {
    _mockClipboard(tester);
    await tester.pumpWidget(
      _host(const CopyValue(value: 'INV-7', child: Text('INV-7'))),
    );
    await connectMouse(tester);
    expect(find.byKey(_button), findsOneWidget);
    await click(tester, find.byKey(_button));
    expect(_clipboard, 'INV-7');
    expect(find.text('Copied'), findsOneWidget);
    // Named for a screen reader with the value it copies.
    expect(find.bySemanticsLabel('Copy INV-7'), findsOneWidget);
  });

  testWidgets('masked: no copy button, no raw value; revealed copies; hidden '
      'again the copy path is gone', (tester) async {
    _mockClipboard(tester);
    await tester.pumpWidget(
      _host(
        const PrivateValue(
          revealKey: _reveal,
          child: CopyValue(value: _secret, child: Text(_secret)),
        ),
        masked: true,
      ),
    );
    await connectMouse(tester);
    // Masked.
    expect(find.byKey(_button), findsNothing);
    expect(find.textContaining('SENTINEL'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('SENTINEL')), findsNothing);
    // Revealed.
    await click(tester, find.byKey(_reveal));
    expect(find.text(_secret), findsOneWidget);
    await click(tester, find.byKey(_button));
    expect(_clipboard, _secret);
    // Hidden again.
    await click(tester, find.byKey(_reveal));
    expect(find.byKey(_button), findsNothing);
    expect(find.textContaining('SENTINEL'), findsNothing);
  });

  testWidgets('a drag across text selects it and the page does not scroll', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        SelectionArea(
          child: ListView(
            controller: controller,
            children: [
              const Text('Invoice FA-2026-0042', key: ValueKey('number')),
              for (var i = 0; i < 60; i++)
                SizedBox(height: 40, child: Text('Line $i')),
            ],
          ),
        ),
      ),
    );
    final mouse = await connectMouse(tester);
    final rect = tester.getRect(find.byKey(const ValueKey('number')));
    await mouse.down(rect.centerLeft + const Offset(2, 0));
    await tester.pump();
    await mouse.moveTo(rect.centerLeft + const Offset(150, 0));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    expect(controller.offset, 0, reason: 'a mouse drag never pans a page');
    final registrar = SelectionContainer.maybeOf(
      tester.element(find.byKey(const ValueKey('number'))),
    );
    expect(registrar, isNotNull);
    expect(find.byType(SelectableRegion), findsOneWidget);
  });

  testWidgets('a tap on a button inside a selection area still taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SelectionArea(
          child: TextButton(onPressed: () => taps++, child: const Text('Open')),
        ),
      ),
    );
    await connectMouse(tester);
    await tester.tap(find.text('Open'), kind: PointerDeviceKind.mouse);
    expect(taps, 1);
  });
}
