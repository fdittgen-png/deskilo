// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3549/#3550 — the kind chooser: the proposal is shown per kind, Cancel
// writes nothing, Save writes the kind and the confirmed features through
// the feature-write path, and a feature that is not yet stable is written
// only when ticked.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/demo/data/settings_repository.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/workspace/domain/business_kind.dart';
import 'package:deskilo/features/workspace/domain/business_profile.dart';
import 'package:deskilo/features/workspace/domain/feature_operation.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/business_kind_sheet.dart';
import 'package:deskilo/features/workspace/providers/business_kind_providers.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

/// Records the kind written instead of storing it.
class _Kinds implements BusinessKindRepository {
  final writes = <(String, List<String>)>[];

  /// #4168 — set to move the freelancer's profile after the owner opened the sheet.
  int freelancerVersion = 1;

  /// #3730 — kinds a newer server offers beside the known ones.
  final extra = <BusinessKind>[];

  @override
  Future<List<BusinessKind>> kinds() async => [
    const BusinessKind(code: 'coworking', sortOrder: 10),
    const BusinessKind(code: 'studio', sortOrder: 20, profile: _noPlaces),
    const BusinessKind(code: 'practice', sortOrder: 30, profile: _noPlaces),
    const BusinessKind(code: 'salon', sortOrder: 40, profile: _noPlaces),
    BusinessKind(
      code: 'freelancer',
      sortOrder: 45,
      profile: _freelancer,
      profileVersion: freelancerVersion,
      profileDigest: 'v$freelancerVersion',
    ),
    const BusinessKind(code: 'shop', sortOrder: 47, profile: _shop),
    const BusinessKind(code: 'service', sortOrder: 50, profile: _noPlaces),
    ...extra,
  ];

  @override
  Future<void> setKind(
    String workspaceId, {
    required String kind,
    required List<String> moreKinds,
  }) async => writes.add((kind, moreKinds));

  @override
  Future<BusinessKindApplied> applyKind(
    String workspaceId, {
    required String requestId,
    required ReviewedKind reviewed,
    required Map<String, bool> flags,
    required Map<String, bool> expected,
  }) => throw const BusinessKindApplyUnsupported();
}

/// The profile 0834 seeds for the freelancer: no provider, no messages.
const _freelancer = {
  'placeBooking': false,
  'moneyTab': true,
  'services': true,
  'invoicing': true,
  'billingCustomers': true,
  'customerQuotes': true,
  'purchases': true,
};

/// The profile 0890 seeds for the shop: the stock, the catalogue and the purchases, no places.
const _shop = {
  'placeBooking': false,
  'moneyTab': true,
  'services': true,
  'invoicing': true,
  'purchases': true,
  'purchaseOrders': true,
  'stockManagement': true,
  'stockReceiving': true,
  'stockTakeOut': true,
  'stockLots': true,
  'stockReorder': true,
  'stockItemGroups': true,
  'stockScanning': true,
};

/// The profile 0709 seeds for the kinds without places.
const _noPlaces = {
  'placeBooking': false,
  'moneyTab': true,
  'services': true,
  'invoicing': true,
  'onlinePayments': true,
  'messagesHub': true,
  'publicListings': true,
};

Future<(_Kinds, FakeWorkspaceRepository)> _open(
  WidgetTester tester, {
  Map<String, dynamic> flags = const {},
  FakeSettingsRepository? settings,
  List<BusinessKind> extra = const [],
}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final kinds = _Kinds()..extra.addAll(extra);
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  await pumpApp(
    tester,
    const Scaffold(body: BusinessKindTile()),
    overrides: [
      ...standardTestOverrides(workspace: workspace),
      businessKindRepositoryProvider.overrideWithValue(kinds),
      settingsRepositoryProvider.overrideWithValue(settings ?? FakeSettingsRepository(const [])),
      businessProfileProvider.overrideWith(
        (ref) async => const BusinessProfile(kind: 'coworking'),
      ),
      myPermissionsProvider.overrideWithValue(const {
        WorkspacePermission.manageConfiguration,
      }),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('business-kind-tile')));
  await tester.pumpAndSettle();
  return (kinds, workspace);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// The features a kind without places switches on that ask for consent.
final _consent = [
  for (final key in const ['invoicing', 'onlinePayments', 'services'])
    if (featureNeedsOptIn(WorkspaceFeature.values.byName(key)))
      WorkspaceFeature.values.byName(key),
];

void main() {
  testWidgets('the current kind proposes nothing; another kind says what '
      'switches on and off', (tester) async {
    await _open(tester);
    expect(
      find.byKey(const ValueKey('business-kind-no-change')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('business-kind-no-booking-yet')),
      findsNothing,
    );

    await _tap(tester, 'business-kind-practice');
    expect(find.byKey(const ValueKey('business-kind-no-change')), findsNothing);
    expect(find.byKey(const ValueKey('business-kind-off')), findsOneWidget);
    expect(find.textContaining('everything about places'), findsOneWidget);
    // A kind without places says what this version does not do yet.
    expect(
      find.byKey(const ValueKey('business-kind-no-booking-yet')),
      findsOneWidget,
    );
  });

  testWidgets('Cancel writes nothing', (tester) async {
    final (kinds, workspace) = await _open(tester);
    final before = workspace.flagWrites.length;
    await _tap(tester, 'business-kind-salon');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(kinds.writes, isEmpty);
    expect(workspace.flagWrites.length, before);
  });

  testWidgets('Save writes the kind and switches the places off; a feature '
      'that asks for consent is left out unless ticked', (tester) async {
    final (kinds, workspace) = await _open(
      tester,
      flags: const {'invoicing': false, 'onlinePayments': false},
    );
    await _tap(tester, 'business-kind-practice');
    await _tap(tester, 'business-kind-more-studio');
    await _tap(tester, 'business-kind-save');

    expect(kinds.writes.single.$1, 'practice');
    expect(kinds.writes.single.$2, ['studio']);
    expect(find.byKey(const ValueKey('form-sheet-error')), findsNothing);
    final written = workspace.flagWrites.last;
    expect(written['placeBooking'], isFalse);
    expect(
      _consent,
      isNotEmpty,
      reason: 'the proposal names a feature in beta',
    );
    for (final f in _consent) {
      expect(
        written.containsKey(f.dbKey),
        isFalse,
        reason: '${f.name} unticked',
      );
    }
  });

  testWidgets('a feature that asks for consent is written only when '
      'ticked', (tester) async {
    // A space without invoicing yet: the kind proposes it.
    final (_, workspace) = await _open(
      tester,
      flags: const {'invoicing': false, 'onlinePayments': false},
    );
    await _tap(tester, 'business-kind-practice');
    final boxes = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'business-kind-consent-',
          ),
    );
    expect(boxes, findsWidgets, reason: 'the proposal names a feature in beta');
    final key = (tester.widget(boxes.first).key! as ValueKey<String>).value;
    final feature = key.substring('business-kind-consent-'.length);
    await _tap(tester, key);
    await _tap(tester, 'business-kind-save');
    expect(workspace.flagWrites.last[feature], isTrue);
  });

  testWidgets('Freelancer is offered between Salon and Service; it switches '
      'the places off and saves as its own kind', (tester) async {
    final (kinds, workspace) = await _open(tester);
    expect(find.byKey(const ValueKey('business-kind-freelancer')), findsOneWidget);
    await _tap(tester, 'business-kind-freelancer');
    expect(find.byKey(const ValueKey('business-kind-off')), findsOneWidget);
    expect(find.byKey(const ValueKey('business-kind-no-booking-yet')), findsOneWidget);
    await _tap(tester, 'business-kind-save');
    expect(kinds.writes.single.$1, 'freelancer');
    expect(workspace.flagWrites.last['placeBooking'], isFalse);
    expect(workspace.flagWrites.last.containsKey('onlinePayments'), isFalse);
  });

  testWidgets('Shop is offered between Freelancer and Service; it proposes the stock, asks the type and writes it', (tester) async {
    final registry = (jsonDecode(File('assets/instance/settings_registry.json').readAsStringSync()) as List)
        .map((row) => SettingDefinition.fromJson(row as Map<String, Object?>));
    final settings = FakeSettingsRepository(registry);
    final (kinds, workspace) = await _open(tester, settings: settings);
    expect(find.byKey(const ValueKey('business-kind-shop')), findsOneWidget);
    expect(find.byKey(const ValueKey('business-kind-shop-type')), findsNothing, reason: 'no type until the business is a shop');
    await _tap(tester, 'business-kind-shop');
    expect(find.byKey(const ValueKey('business-kind-shop-type')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('business-kind-shop-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bakery').last);
    await tester.pumpAndSettle();
    // the stock asks for consent: the owner ticks it, and it is written
    await _tap(tester, 'business-kind-consent-stockManagement');
    await _tap(tester, 'business-kind-save');
    expect(kinds.writes.single.$1, 'shop');
    expect(workspace.flagWrites.last['stockManagement'], isTrue, reason: 'the shop proposes the stock');
    expect(workspace.flagWrites.last['placeBooking'], isFalse);
    expect((settings.writes.single.key, settings.writes.single.value), ('business.shop_type', 'bakery'));
  });

  testWidgets('a profile that changed after the owner opened the sheet is '
      'refused, nothing is written, and the owner is asked to review again',
      (tester) async {
    final (kinds, workspace) = await _open(tester);
    await _tap(tester, 'business-kind-freelancer');
    final before = workspace.flagWrites.length;
    kinds.freelancerVersion = 2;
    await _tap(tester, 'business-kind-save');
    expect(kinds.writes, isEmpty);
    expect(workspace.flagWrites.length, before);
    expect(find.byKey(const ValueKey('form-sheet-error')), findsOneWidget);
    expect(find.textContaining('updated while you were choosing'), findsOneWidget);
  });

  testWidgets('#3730 — a kind whose profile names a feature this app does '
      'not know is explained and refused before anything is written', (
    tester,
  ) async {
    final (kinds, workspace) = await _open(
      tester,
      extra: const [
        BusinessKind(
          code: 'future_kind',
          sortOrder: 60,
          profile: {'futureFeature': true, 'invoicing': true},
        ),
      ],
    );
    final before = workspace.flagWrites.length;
    await _tap(tester, 'business-kind-future_kind');
    expect(
      find.byKey(const ValueKey('business-kind-unknown-features')),
      findsOneWidget,
    );
    await _tap(tester, 'business-kind-save');

    expect(tester.takeException(), isNull);
    expect(kinds.writes, isEmpty);
    expect(workspace.flagWrites.length, before);
    expect(find.byKey(const ValueKey('form-sheet-error')), findsOneWidget);
    expect(find.textContaining('Update the app'), findsWidgets);
  });
}
