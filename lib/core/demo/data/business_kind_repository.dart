// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3550 — the Demo's kinds of business: the five rows 0703 seeds, with the
// profiles 0709 gives them. The kind is kept in the Demo's settings, as the
// server keeps it in the registry.
import '../../../features/workspace/domain/business_kind.dart';
import '../../../features/workspace/domain/business_profile.dart';
import '../../settings/settings.dart';

const _noPlaces = {
  'placeBooking': false,
  'moneyTab': true,
  'services': true,
  'invoicing': true,
  'onlinePayments': true,
  'messagesHub': true,
  'publicListings': true,
};

class DemoBusinessKindRepository implements BusinessKindRepository {
  const DemoBusinessKindRepository(this._settings);

  final SettingsStore _settings;

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
  }) async {
    await _settings.setValue(
      workspaceId: workspaceId,
      key: businessKindKey,
      value: kind,
    );
    await _settings.setValue(
      workspaceId: workspaceId,
      key: businessMoreKindsKey,
      value: [
        for (final k in moreKinds)
          if (k != kind) k,
      ].join(','),
    );
  }
}
