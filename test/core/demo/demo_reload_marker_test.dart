// SPDX-License-Identifier: AGPL-3.0-or-later
// #3235 — unavailable storage is never treated as a successful marker.
import 'package:deskilo/core/demo/data/auth_repository.dart';
import 'package:deskilo/core/demo/demo_entry.dart';
import 'package:deskilo/core/demo/demo_reload_marker.dart';
import 'package:deskilo/core/demo/demo_reload_marker_provider.dart';
import 'package:deskilo/core/demo/presentation/demo_entry_sheet.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage implements DemoReloadMarkerStorage {
  String? value;
  bool unavailable = false;
  bool ignoreWrite = false;
  bool ignoreClear = false;

  void _check() {
    if (unavailable) throw StateError('storage unavailable');
  }

  @override
  String? read() {
    _check();
    return value;
  }

  @override
  void write(String value) {
    _check();
    if (!ignoreWrite) this.value = value;
  }

  @override
  void clear() {
    _check();
    if (!ignoreClear) value = null;
  }
}

void main() {
  test('a marker contains only a visit hint and is cleared on leave', () {
    final storage = _Storage();
    final marker = DemoReloadMarker(storage);
    expect(marker.read(), DemoReloadMarkerState.absent);
    expect(marker.arm(), isTrue);
    expect(marker.read(), DemoReloadMarkerState.armed);
    expect(storage.value, 'demo-visit-v1');
    expect(marker.clear(), isTrue);
    expect(marker.read(), DemoReloadMarkerState.absent);
  });

  test('invalid, unavailable and ineffective storage do not claim success', () {
    final storage = _Storage()..value = 'untrusted';
    final marker = DemoReloadMarker(storage);
    expect(marker.read(), DemoReloadMarkerState.invalid);
    storage.ignoreWrite = true;
    expect(marker.arm(), isFalse);
    storage.ignoreWrite = false;
    expect(marker.arm(), isTrue);
    storage.ignoreClear = true;
    expect(marker.clear(), isFalse);
    storage.unavailable = true;
    expect(marker.read(), DemoReloadMarkerState.unavailable);
    expect(marker.arm(), isFalse);
    expect(marker.clear(), isFalse);
  });

  test('cold entry guards stale markers without swallowing explicit links', () {
    for (final state in [
      DemoReloadMarkerState.armed,
      DemoReloadMarkerState.invalid,
    ]) {
      expect(needsDemoReloadEntry(state, Uri.parse('/features')), isTrue);
      expect(
        needsDemoReloadEntry(state, Uri.parse('/features?code=x')),
        isTrue,
      );
      expect(
        needsDemoReloadEntry(state, Uri.parse('/demo?to=/features')),
        isFalse,
      );
      expect(needsDemoReloadEntry(state, Uri.parse('/auth?demo=1')), isFalse);
      expect(needsDemoReloadEntry(state, Uri.parse('/auth?code=x')), isFalse);
      expect(
        needsDemoReloadEntry(state, Uri.parse('deskilo://join?code=x')),
        isFalse,
      );
      // The invitation continuation EntryIntent.join opens keeps its place.
      expect(
        needsDemoReloadEntry(state, Uri.parse('/onboarding?join=1')),
        isFalse,
      );
      expect(needsDemoReloadEntry(state, Uri.parse('/onboarding')), isTrue);
    }
    // No marker, or a tab whose storage cannot be read (where `arm` fails, so
    // no visit can have started): an ordinary start, at the screen asked for.
    for (final state in [
      DemoReloadMarkerState.absent,
      DemoReloadMarkerState.unavailable,
    ]) {
      expect(needsDemoReloadEntry(state, Uri.parse('/features')), isFalse);
    }
  });

  testWidgets('unavailable tab storage refuses the visit after consent', (
    tester,
  ) async {
    final storage = _Storage()..unavailable = true;
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        demoReloadMarkerProvider.overrideWithValue(DemoReloadMarker(storage)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: DemoEntryButton())),
      ),
    );
    await tester.tap(find.byKey(DemoEntryButton.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-entry-start')));
    await tester.pumpAndSettle();
    expect(container.read(demoEntryProvider), isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('normal Demo leave clears the tab marker', (tester) async {
    final storage = _Storage();
    final marker = DemoReloadMarker(storage);
    expect(marker.arm(), isTrue);
    final container = ProviderContainer(
      overrides: [demoReloadMarkerProvider.overrideWithValue(marker)],
    );
    addTearDown(container.dispose);
    container.read(demoEntryProvider.notifier).enter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DemoWorkspace(
          child: MaterialApp(home: DemoControls(child: SizedBox())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DemoControls.leaveKey));
    await tester.pumpAndSettle();
    expect(marker.read(), DemoReloadMarkerState.absent);
    expect(container.read(demoEntryProvider), isFalse);
  });
}
