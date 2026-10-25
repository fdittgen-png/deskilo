// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 XPRIV-01 — a masked private value is in no text, tooltip or
// semantics node; a screen reader hears "Hidden" and a reveal action; the
// device and account choice decide whether it starts masked.
import 'package:deskilo/core/privacy/private_values.dart';
import 'package:deskilo/core/ui/private_value.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _sentinel = 'SENTINEL-4711';
const _reveal = ValueKey('reveal');

class _MemoryStore implements PrivateValuesStore {
  _MemoryStore([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async => this.value = value;
}

Future<void> _pump(
  WidgetTester tester, {
  PrivateValuesPolicy? policy,
  String? device,
}) async {
  await pumpApp(
    tester,
    const Scaffold(
      body: Center(
        child: SelectionArea(
          child: PrivateValue(
            revealKey: _reveal,
            maskedText: 'EUR ••••',
            child: Text(_sentinel),
          ),
        ),
      ),
    ),
    overrides: [
      privateValuesStoreProvider.overrideWithValue(_MemoryStore(device)),
      if (policy != null) privateValuesPolicyProvider.overrideWithValue(policy),
    ],
  );
  await tester.pumpAndSettle();
}

/// Every semantics node that says [needle] in a label, value, hint,
/// tooltip or action hint.
SemanticsFinder _saying(String needle) => find.semantics.byPredicate((node) {
  final d = node.getSemanticsData();
  return [
    d.label,
    d.value,
    d.hint,
    d.tooltip,
    node.hintOverrides?.onTapHint ?? '',
  ].any((s) => s.contains(needle));
});

List<String> _tooltips(WidgetTester tester) => [
  for (final t in tester.widgetList<Tooltip>(find.byType(Tooltip)))
    t.message ?? '',
];

void main() {
  testWidgets('masked: the value is in no text, tooltip or semantics node, '
      'and a screen reader hears Hidden with a reveal action', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    expect(find.text('EUR ••••'), findsOneWidget);
    expect(find.textContaining('4711'), findsNothing);
    expect(_tooltips(tester), ['Show']);
    expect(_saying('4711'), findsNothing);
    final node = tester.getSemantics(find.byKey(_reveal));
    expect(node.label, contains('Hidden'));
    expect(node.label, isNot(contains('EUR')));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.hintOverrides?.onTapHint, 'Show');
    semantics.dispose();
  });

  testWidgets('the reveal action shows this value, and hides it again', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    await tester.tap(find.byKey(_reveal));
    await tester.pumpAndSettle();
    expect(find.text(_sentinel), findsOneWidget);
    expect(_tooltips(tester), ['Hide']);
    await tester.tap(find.byKey(_reveal));
    await tester.pumpAndSettle();
    expect(find.textContaining('4711'), findsNothing);
    expect(_saying('4711'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the semantics tap reveals as a tap does', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    tester.semantics.tap(find.semantics.byLabel('Hidden'));
    await tester.pumpAndSettle();
    expect(find.text(_sentinel), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('without the wiring, a device choice to show changes nothing', (
    tester,
  ) async {
    await _pump(tester, device: PrivateValuesChoice.shown);
    expect(find.textContaining('4711'), findsNothing);
  });

  testWidgets('offered, no choice anywhere: masked (the new default)', (
    tester,
  ) async {
    await _pump(tester, policy: const PrivateValuesPolicy(enabled: true));
    expect(find.textContaining('4711'), findsNothing);
  });

  testWidgets('the account chose to show: shown plainly, no reveal button', (
    tester,
  ) async {
    await _pump(
      tester,
      policy: const PrivateValuesPolicy(
        enabled: true,
        account: PrivateValuesChoice.shown,
      ),
    );
    expect(find.text(_sentinel), findsOneWidget);
    expect(find.byKey(_reveal), findsNothing);
  });

  testWidgets('no account choice: the device choice holds', (tester) async {
    await _pump(
      tester,
      policy: const PrivateValuesPolicy(enabled: true),
      device: PrivateValuesChoice.shown,
    );
    expect(find.text(_sentinel), findsOneWidget);
  });

  testWidgets('the account is canonical over the device', (tester) async {
    await _pump(
      tester,
      policy: const PrivateValuesPolicy(
        enabled: true,
        account: PrivateValuesChoice.masked,
      ),
      device: PrivateValuesChoice.shown,
    );
    expect(find.textContaining('4711'), findsNothing);
  });

  testWidgets('an unknown account value falls back, never shows by accident', (
    tester,
  ) async {
    await _pump(
      tester,
      policy: const PrivateValuesPolicy(enabled: true, account: 'bogus'),
    );
    expect(find.textContaining('4711'), findsNothing);
  });

  testWidgets('masking turned back on hides what was revealed before', (
    tester,
  ) async {
    await _pump(
      tester,
      policy: const PrivateValuesPolicy(enabled: true),
      device: PrivateValuesChoice.masked,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PrivateValue)),
    );
    await tester.tap(find.byKey(_reveal));
    await tester.pumpAndSettle();
    expect(find.text(_sentinel), findsOneWidget);
    await container
        .read(privateValuesDeviceProvider.notifier)
        .set(PrivateValuesChoice.shown);
    await tester.pumpAndSettle();
    expect(find.byKey(_reveal), findsNothing);
    await container
        .read(privateValuesDeviceProvider.notifier)
        .set(PrivateValuesChoice.masked);
    await tester.pumpAndSettle();
    expect(find.textContaining('4711'), findsNothing);
    expect(find.text('EUR ••••'), findsOneWidget);
  });

  test('the device refuses a value that is not a choice', () async {
    final container = ProviderContainer(
      overrides: [privateValuesStoreProvider.overrideWithValue(_MemoryStore())],
    );
    addTearDown(container.dispose);
    await container.read(privateValuesDeviceProvider.future);
    expect(
      () => container.read(privateValuesDeviceProvider.notifier).set('bogus'),
      throwsArgumentError,
    );
    expect(container.read(privateValuesDeviceProvider).value, isNull);
  });

  test('a stored value that is not a choice reads as none', () async {
    final container = ProviderContainer(
      overrides: [
        privateValuesStoreProvider.overrideWithValue(_MemoryStore('bogus')),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(privateValuesDeviceProvider.future), isNull);
  });
}
