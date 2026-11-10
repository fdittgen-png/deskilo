// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3549/#3550 — the kind chooser: the proposal is shown per kind, Cancel
// writes nothing, Save writes the kind and the confirmed features through
// the feature-write path, and a feature that is not yet stable is written
// only when ticked.
import 'package:deskilo/features/workspace/domain/business_kind.dart';
import 'package:deskilo/features/workspace/domain/business_profile.dart';
import 'package:deskilo/features/workspace/domain/feature_operation.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/business_kind_sheet.dart';
import 'package:deskilo/features/workspace/providers/business_kind_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

/// Records the kind written instead of storing it.
class _Kinds implements BusinessKindRepository {
  final writes = <(String, List<String>)>[];

  @override
  Future<List<BusinessKind>> kinds() async => const [
    BusinessKind(code: 'coworking', sortOrder: 10),
    BusinessKind(code: 'studio', sortOrder: 20, profile: _noPlaces),
    BusinessKind(code: 'practice', sortOrder: 30, profile: _noPlaces),
    BusinessKind(code: 'salon', sortOrder: 40, profile: _noPlaces),
    BusinessKind(code: 'service', sortOrder: 50, profile: _noPlaces),
  ];

  @override
  Future<void> setKind(
    String workspaceId, {
    required String kind,
    required List<String> moreKinds,
  }) async => writes.add((kind, moreKinds));
}

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
}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final kinds = _Kinds();
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  await pumpApp(
    tester,
    const Scaffold(body: BusinessKindTile()),
    overrides: [
      ...standardTestOverrides(workspace: workspace),
      businessKindRepositoryProvider.overrideWithValue(kinds),
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
}
