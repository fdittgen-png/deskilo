// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2484 -- the generic settings editor and the proof setting. The editor
// shows each setting with its unit, bounds, origin and floor, refuses an
// out-of-range value before sending it, saves a new version and shows the
// history; a guardrail is read-only with its reason. The proof: the dunning
// delay comes from the registry, so changing the setting changes the next
// reminder, and the stored rules no longer decide it.
import 'package:deskilo/core/demo/data/settings_repository.dart';
import 'package:deskilo/core/instance/settings_bundle_asset.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/workspace/presentation/widgets/settings_editor.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _days = SettingDefinition(
  key: 'dunning.first_after_days',
  type: SettingType.integer,
  defaultValue: 14,
  min: 1,
  max: 365,
  unit: 'days',
  group: 'dunning',
  scopes: {SettingScope.platform, SettingScope.workspace},
  editPermission: 'workspaceSettings',
);

const _guardrail = SettingDefinition(
  key: 'security.max_pin_length',
  type: SettingType.integer,
  defaultValue: 8,
  unit: 'digits',
  group: 'security',
  scopes: {SettingScope.workspace},
  editPermission: 'workspaceSettings',
  editable: false,
  note: 'The badge reader accepts at most eight digits.',
);

Future<FakeSettingsRepository> _pump(
  WidgetTester tester, {
  bool canEdit = true,
  List<SettingDefinition> defs = const [_days],
  Object? failWith,
}) async {
  final store = FakeSettingsRepository(defs)..failWith = failWith;
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value('u1')),
      settingsRepositoryProvider.overrideWithValue(store),
      settingsBundleLoaderProvider.overrideWithValue(() async => defs),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SettingsEditor(
            scope: SettingScope.workspace,
            workspaceId: 'ws-1',
            canEdit: canEdit,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('a setting shows its unit, its bounds, its origin and its value', (tester) async {
    await _pump(tester);
    expect(find.text('Days before a first reminder'), findsOneWidget);
    expect(find.textContaining('Between 1 and 365 days'), findsOneWidget);
    expect(find.textContaining('Built-in default'), findsOneWidget);
    expect(find.text('Now: 14 days'), findsOneWidget);
  });

  testWidgets('an out-of-range value is refused before anything is sent; a valid one is saved',
      (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('setting-edit-dunning.first_after_days')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('setting-value')), '0');
    await tester.tap(find.byKey(const ValueKey('setting-save')));
    await tester.pumpAndSettle();
    expect(find.text('Below the minimum'), findsOneWidget);
    expect(store.writes, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('setting-value')), '30');
    await tester.tap(find.byKey(const ValueKey('setting-save')));
    await tester.pumpAndSettle();
    expect(store.writes.single.value, 30);
    expect(store.writes.single.workspaceId, 'ws-1');
    expect(find.text('Now: 30 days'), findsOneWidget);
    expect(find.textContaining('Set for this workspace'), findsOneWidget);
  });

  testWidgets('the history lists the versions, the closed one included', (tester) async {
    await _pump(tester);
    for (final v in ['21', '30']) {
      await tester.tap(find.byKey(const ValueKey('setting-edit-dunning.first_after_days')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('setting-value')), v);
      await tester.tap(find.byKey(const ValueKey('setting-save')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('setting-history-dunning.first_after_days')));
    await tester.pumpAndSettle();
    expect(find.textContaining('30 days'), findsWidgets);
    expect(find.textContaining('21 days'), findsOneWidget);
    expect(find.textContaining('until'), findsOneWidget);
  });

  testWidgets('a guardrail is shown with its reason and cannot be edited', (tester) async {
    await _pump(tester, defs: const [_days, _guardrail]);
    expect(find.textContaining('The badge reader accepts at most eight digits.'), findsOneWidget);
    expect(find.byKey(const ValueKey('setting-edit-security.max_pin_length')), findsNothing);
    expect(find.byKey(const ValueKey('setting-edit-dunning.first_after_days')), findsOneWidget);
  });

  testWidgets('someone without the permission sees the values and no edit button', (tester) async {
    await _pump(tester, canEdit: false);
    expect(find.text('Now: 14 days'), findsOneWidget);
    expect(find.byKey(const ValueKey('setting-edit-dunning.first_after_days')), findsNothing);
  });

  testWidgets('with the server away the bundled defaults show and nothing can be changed',
      (tester) async {
    await _pump(tester, failWith: Exception('offline'));
    expect(find.textContaining('built-in defaults'), findsOneWidget);
    expect(find.byKey(const ValueKey('setting-edit-dunning.first_after_days')), findsNothing);
  });

  test('the proof: the dunning delay is the registry\'s, and changing it moves the next reminder',
      () async {
    final store = FakeSettingsRepository([_days]);
    DunningRules rules(SettingsSet s) => DunningRules.fromJson(
          const {'levels': 3, 'first_after_days': 99},
          settings: s,
        );
    final issued = DateTime(2026, 9);
    int? level(DunningRules r, DateTime now) => dueReminderLevel(
        issuedAt: issued, reminderCount: 0, lastReminderAt: null, rules: r, now: now);

    final before = rules(await store.load('ws-1'));
    expect(before.firstAfterDays, 14, reason: 'the stored 99 no longer decides it');
    expect(level(before, DateTime(2026, 9, 10)), isNull);

    await store.setValue(workspaceId: 'ws-1', key: 'dunning.first_after_days', value: 7);
    final after = rules(await store.load('ws-1'));
    expect(after.firstAfterDays, 7);
    expect(level(after, DateTime(2026, 9, 10)), 1, reason: 'the next reminder follows the setting');

    expect(DunningRules.fromJson(const {}), DunningRules.defaults);
  });
}
